---
sidebar_position: 11
description: "Treat data as more valuable than compute—EBS tiers, snapshots, S3, and tested recovery."
---

# Chapter 11: Persistent Storage for Models and Data

> EC2 instances are disposable. Your data is not.

---

Everything you built so far can be recreated from code and AMIs:

- VPC, subnets, routes
- `hermes-controlplane-01`
- Security groups, UFW rules, sshd config

**Your data cannot be recreated** if you lose it without backups—250 GB of GGUF downloads, three months of PostgreSQL history, Hermes configuration tuned over weeks.

This chapter teaches the central lesson of platform engineering:

> **Treat data as more valuable than compute.**

Persistence is a **design decision**, not an afterthought.

### The Big Idea

A mature platform assumes servers fail, disks fill, instances terminate, and operators make mistakes. The goal is not preventing every failure—it is ensuring failures do not cause **permanent data loss**.

:::note[Why this matters for Hermes]

llama.cpp reads multi-gigabyte model files from disk on every cold start. PostgreSQL holds agent state Hermes cannot infer from thin air. Losing `/models` means re-downloading; losing `/data` means losing conversations and tool history. Separating storage tiers and proving restore **before** you deploy Hermes is what separates a demo from a platform.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Distinguish ephemeral from persistent storage on AWS
- [ ] Explain the lifecycle of an EBS volume and what a snapshot captures
- [ ] Describe why models and databases have different backup requirements
- [ ] Design the Hermes storage layout with three independent volumes
- [ ] Create EBS snapshots and **restore one to verify recovery**
- [ ] Use S3 as durable off-instance storage—not a POSIX filesystem
- [ ] Apply the 3-2-1 backup framework to this platform

Creating an S3 bucket is a step—not the objective. Understanding **why** storage is organized this way is.

---

## Prerequisites

- [Chapter 10: Establishing Trust](10-establishing-trust.md) — SSH access verified
- `hermes-controlplane-01` running with three EBS volumes (updated [Chapter 9](09-provisioning-hermes-server.md)): `hermes-root`, `hermes-models`, `hermes-data`
- `~/hermes-platform/notes/controlplane.env` sourced

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-west-2
source ~/hermes-platform/notes/controlplane.env
KEY=~/.ssh/${HERMES_KEY_NAME}.pem
```

**Legacy two-volume installs:** If you launched before the three-volume standard (`/opt/models` only), see [Migrating to three volumes](#migrating-to-three-volumes) before the main walkthrough.

---

## Estimated Time

**120 minutes** — 50 minutes concept and design, 70 minutes implementation including **restore exercise**.

---

## Background

### Concept — The Problem

Imagine this sequence:

1. You downloaded **250 GB** of GGUF models to `/models`.
2. Hermes ran for **three months**.
3. PostgreSQL under `/data/postgres` holds conversations, prompts, and configuration.
4. An incorrect command **terminates** the EC2 instance—or `terraform destroy` removes it.

Ask yourself:

> **What survives?**

If the answer is "nothing," the platform is not ready for production—even for a personal lab you intend to keep.

Compute is cattle. **Data is pets**—except pets you also snapshot and store offsite.

---

## Theory

### Storage Classes — What Persists?

```text
                Persistent?

CPU                 ❌
RAM                 ❌
Container FS        ❌
EC2 Instance        ❌
Pod (Kubernetes)    ❌

EBS Volume          ✅
EBS Snapshot        ✅
S3 Object           ✅
```

Memorize this table. It applies after you add Docker, k3s, and Hermes—containers and pods remain ephemeral; **EBS and S3 hold what must survive**.

### Three-Volume Design

| Volume | AWS name | Size | Holds | Growth pattern |
|--------|----------|------|-------|----------------|
| Root | `hermes-root` | 100 GB | Ubuntu, Docker, k3s, logs | Slow |
| Models | `hermes-models` | 300 GB | GGUF, embeddings, HF cache | Large bursts |
| Data | `hermes-data` | 100 GB | PostgreSQL, Redis, vectors | Steady |

**Why separate volumes—not one big disk?**

| Benefit | Explanation |
|---------|-------------|
| **Isolation** | A full `/models` does not prevent PostgreSQL from writing to `/data` |
| **Targeted recovery** | Corrupt database? Restore `hermes-data` without touching models |
| **Right-sized snapshots** | Snapshot models weekly; snapshot data daily |
| **Independent resize** | Add 200 GB to models without resizing root |
| **Teaches production shape** | Same separation you will use with Kubernetes PVs |

### Platform Directory Layout

```text
/
├── opt/
│   ├── hermes/          # configs, env templates (root volume)
│   ├── config/
│   └── scripts/
├── models/              # hermes-models volume
│   ├── qwen/
│   ├── mistral/
│   └── llama/
├── data/                # hermes-data volume
│   ├── postgres/
│   ├── redis/
│   └── vector/
└── backups/             # staging before S3 upload (root)
```

Applications, models, and databases are **separate concerns with different lifecycles**.

### Snapshots vs Backups

Readers often equate snapshot with backup. They are related—not identical.

| | EBS Snapshot | Backup strategy |
|---|--------------|-----------------|
| **What** | Point-in-time block copy of one volume | Policy covering what, when, retention, restore, **testing** |
| **Scope** | Single volume | Often multiple volumes + logical exports |
| **Question answered** | "What did this disk look like at 02:00?" | "Can I recover Hermes after disaster?" |

A backup strategy defines:

1. **What** is backed up (which volumes, PostgreSQL dumps, configs)
2. **How often** (models: weekly; data: daily)
3. **Retention** (7 daily, 4 weekly—example)
4. **Restore procedure** (documented steps)
5. **Restore testing** (you prove it works—this chapter)

> **A backup you haven't restored is an assumption.**

### S3 — Durable Archive

**S3** is object storage—11 nines durability designed for off-instance retention. Use it for:

- Nightly PostgreSQL dumps (future)
- Snapshot manifests and backup logs
- Terraform state ([Chapter 30](../part-v-infrastructure/30-terraform.md))
- Exported Hermes configuration
- Log archives and AI artifacts

S3 is **not** a replacement for EBS when llama.cpp needs low-latency local reads. Hot models live on `hermes-models`; S3 holds **copies** and cold archives.

### 3-2-1 Rule

| Rule | Hermes platform (iteration 1) |
|------|----------------------------------|
| **3** copies of data | Live EBS + snapshot + S3 export |
| **2** media types | EBS (block) + S3 (object) |
| **1** offsite | S3 in AWS (different failure domain than one EC2 instance) |

Full enterprise 3-2-1 may add offline tape or another region later. The **framework** matters now.

---

## Architecture

### Design — Persistence Layer

```text
hermes-controlplane-01
    │
    ├── hermes-root (100 GB gp3)     → /
    ├── hermes-models (300 GB gp3)   → /models
    └── hermes-data (100 GB gp3)     → /data

Backup path:
    EBS snapshots (per volume)
         │
         └── S3 bucket hermes-platform-backups-ACCOUNT_ID
                 ├── manifests/
                 ├── exports/        (future PostgreSQL dumps)
                 └── logs/
```

### Recovery Flow (What You Will Practice)

```text
1. Create marker files on /models and /data
2. Snapshot hermes-models
3. Launch new volume from snapshot
4. Attach temporarily → mount at /mnt/restore-test
5. Verify marker files exist
6. Detach and delete test volume (keep snapshot)
```

---

## Walkthrough

### Implementation — Persistence and Proven Recovery

Concepts first—you already have three volumes from Chapter 9. This chapter **tags, organizes, backs up, and restores**.

#### Step 1 — Verify Mounts and Layout on the Server

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
set -e
lsblk -o NAME,SIZE,MOUNTPOINT,FSTYPE
df -h / /models /data
mount | grep -E ' /models | /data '
test -d /models/qwen /data/postgres /backups
EOF
```

If `/models` or `/data` is missing, see [Migrating to three volumes](#migrating-to-three-volumes).

Create **restore test markers**:

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
date | sudo tee /models/.hermes-restore-marker
date | sudo tee /data/.hermes-restore-marker
sudo chown ubuntu:ubuntu /models/.hermes-restore-marker /data/.hermes-restore-marker
EOF
```

#### Step 2 — Tag Volumes (If Not Already Tagged)

From your laptop:

```bash
aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].[Ebs.VolumeId,DeviceName]' \
  --output table

# Tag by device (example — use your volume IDs)
# /dev/sda1 or /dev/nvme0n1 → hermes-root
# /dev/sdf or /dev/nvme1n1   → hermes-models (300 GB)
# /dev/sdg or /dev/nvme2n1   → hermes-data (100 GB)

MODELS_VOL=$(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[?contains(DeviceName, `sdf`) || contains(DeviceName, `nvme1`)].Ebs.VolumeId' \
  --output text)

DATA_VOL=$(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[?contains(DeviceName, `sdg`) || contains(DeviceName, `nvme2`)].Ebs.VolumeId' \
  --output text)

ROOT_VOL=$(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[?contains(DeviceName, `sda1`) || contains(DeviceName, `nvme0n1`)].Ebs.VolumeId' \
  --output text)

aws ec2 create-tags --resources "$ROOT_VOL" --tags Key=Name,Value=hermes-root Key=Tier,Value=os
aws ec2 create-tags --resources "$MODELS_VOL" --tags Key=Name,Value=hermes-models Key=Tier,Value=models
aws ec2 create-tags --resources "$DATA_VOL" --tags Key=Name,Value=hermes-data Key=Tier,Value=data

echo "ROOT=$ROOT_VOL MODELS=$MODELS_VOL DATA=$DATA_VOL" | tee -a ~/hermes-platform/notes/storage.env
```

Adjust device queries if your mapping differs—use `lsblk` on the instance to confirm.

#### Step 3 — Create S3 Backup Bucket

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="hermes-platform-backups-${ACCOUNT_ID}"

if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=hermes},{Key=Purpose,Value=backups}]'

mkdir -p /tmp/hermes-backup-test
echo "hermes s3 baseline $(date -Is)" > /tmp/hermes-backup-test/manifest.txt
aws s3 cp /tmp/hermes-backup-test/manifest.txt "s3://${BUCKET}/manifests/ch11-baseline.txt"

echo "export HERMES_BACKUP_BUCKET=$BUCKET" >> ~/hermes-platform/notes/storage.env
echo "S3 bucket: s3://$BUCKET"
```

Or run: `bash infrastructure/aws/cli/ch11-storage-backup-baseline.sh` after review.

#### Step 4 — Create Initial Snapshots

```bash
SNAP_MODELS=$(aws ec2 create-snapshot \
  --volume-id "$MODELS_VOL" \
  --description "hermes-models initial $(date +%F)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=hermes-models-initial},{Key=Project,Value=hermes}]' \
  --query SnapshotId --output text)

SNAP_DATA=$(aws ec2 create-snapshot \
  --volume-id "$DATA_VOL" \
  --description "hermes-data initial $(date +%F)" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=hermes-data-initial},{Key=Project,Value=hermes}]' \
  --query SnapshotId --output text)

aws ec2 wait snapshot-completed --snapshot-ids "$SNAP_MODELS" "$SNAP_DATA"
echo "SNAP_MODELS=$SNAP_MODELS SNAP_DATA=$SNAP_DATA" >> ~/hermes-platform/notes/storage.env
```

#### Step 5 — Restore Exercise (Mandatory)

Prove recovery works—restore **models** snapshot to a temporary volume:

```bash
AZ=$(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)

RESTORE_VOL=$(aws ec2 create-volume \
  --snapshot-id "$SNAP_MODELS" \
  --availability-zone "$AZ" \
  --volume-type gp3 \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=hermes-models-restore-test}]' \
  --query VolumeId --output text)

aws ec2 wait volume-available --volume-ids "$RESTORE_VOL"

aws ec2 attach-volume \
  --volume-id "$RESTORE_VOL" \
  --instance-id "$HERMES_INSTANCE_ID" \
  --device /dev/sdh

sleep 10

ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
sudo mkdir -p /mnt/restore-test
DEV=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -E 'sdh|nvme' | tail -1)
sudo mount "$DEV" /mnt/restore-test
cat /mnt/restore-test/.hermes-restore-marker
sudo umount /mnt/restore-test
EOF

aws ec2 detach-volume --volume-id "$RESTORE_VOL"
aws ec2 wait volume-available --volume-ids "$RESTORE_VOL"
aws ec2 delete-volume --volume-id "$RESTORE_VOL"

echo "Restore test PASSED — snapshot $SNAP_MODELS is verified"
```

#### Step 6 — Reboot Test (Mounts Survive)

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} 'sudo reboot' || true
sleep 45
ssh -i "$KEY" -o ConnectTimeout=30 ubuntu@${HERMES_PUBLIC_IP} 'mount | grep -E " /models | /data "'
```

### Migrating to Three Volumes {#migrating-to-three-volumes}

If Chapter 9 created only two volumes (`/opt/models`):

1. Create `hermes-data` — 100 GB gp3 in the same AZ
2. Attach as `/dev/sdg`
3. On server: `sudo mkfs.xfs /dev/sdg`, mount at `/data`, add fstab UUID entry
4. Optionally migrate `/opt/models` → `/models` on the models volume and update fstab
5. Re-run cloud-init layout dirs or create manually under `/data`

Document changes in `~/hermes-platform/notes/storage-migration.md`.

---

## Hands-on Lab

### Lab 11: Persistence, Snapshots, and Proven Restore

**Estimated Time:** 70 minutes

**Goal:** Tagged three-volume layout, S3 backup bucket, snapshots, and **successful restore test**.

**Steps:**

1. Verify `/models` and `/data` mounts and directory layout
2. Write restore marker files
3. Tag volumes `hermes-root`, `hermes-models`, `hermes-data`
4. Create S3 bucket and upload manifest
5. Snapshot models and data volumes; wait for completion
6. Complete restore exercise (Step 5 above)
7. Reboot and verify mounts
8. Read [EDR-0004](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0004-separate-storage-tiers.md)

---

## Verification

- [ ] `lsblk` shows three data volumes with `/`, `/models`, `/data` mounted
- [ ] Layout exists: `/models/{qwen,mistral,llama}`, `/data/{postgres,redis,vector}`, `/backups`
- [ ] `/etc/fstab` entries use UUID + `nofail`; mounts survive reboot
- [ ] S3 bucket accessible; test manifest uploaded
- [ ] Snapshots `hermes-models-initial` and `hermes-data-initial` completed
- [ ] Restore test read `.hermes-restore-marker` from snapshot volume
- [ ] `storage.env` documents volume IDs, snapshot IDs, bucket name

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| S3 `BucketAlreadyExists` | Name taken globally | Use `hermes-platform-backups-${ACCOUNT_ID}` |
| Snapshot stuck `pending` | Large volume first snapshot | Wait; check EC2 → Snapshots |
| Restore mount empty | Wrong snapshot or incomplete | Confirm snapshot completed; check device |
| `/data` missing | Two-volume legacy install | [Migrate](#migrating-to-three-volumes) |
| Reboot drops mounts | fstab missing UUID | Fix `/etc/fstab`; use `sudo mount -a` |

---

## Review Questions

1. Why is EC2 disposable but EBS data is not?
2. What survives if you terminate `hermes-controlplane-01` without snapshots?
3. Why three volumes instead of one?
4. What is the difference between a snapshot and a backup strategy?
5. Where do GGUF files live vs PostgreSQL data?
6. How does S3 fit the 3-2-1 rule?
7. Why must you perform a restore test?
8. Why should llama.cpp not read models directly from S3 at inference time?

---

## Key Takeaways

- **Data > compute** — design persistence before deploying applications
- **Three tiers:** `hermes-root`, `hermes-models`, `hermes-data` with separate lifecycles
- **Snapshots** are point-in-time; **backups** require policy and tested restore
- **S3** for durable off-instance copies—not primary inference storage
- **3-2-1** framework guides evolution toward real disaster recovery
- **Restore exercise** turns assumption into confidence

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **EBS snapshot** | Incremental point-in-time copy of an EBS volume stored in S3 (AWS-managed). |
| **Durability** | Probability data remains intact over time (S3 vs ephemeral instance store). |
| **3-2-1 rule** | Three copies, two media types, one offsite copy. |
| **Restore test** | Proving a backup can be recovered—not just created. |
| **Storage tier** | Separate volume class for OS, models, or application data. |

---

## Further Reading

- [AWS EBS snapshots](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html)
- [Amazon S3 durability](https://docs.aws.amazon.com/AmazonS3/latest/userguide/DataDurability.html)
- [Backup and recovery on AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/backup-recovery/welcome.html)

---

## Engineering Decision Record

**[EDR-0004: Separate operating system, models, and application data](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0004-separate-storage-tiers.md)**

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account            ✓
Network                ✓
EC2                    ✓
Trust                  ✓

Persistent Storage     ✓
Snapshots              ✓
S3                     ✓

Docker                 ✗
k3s                    ✗
Hermes                 ✗
llama.cpp              ✗

Overall Progress

█████████░░░░░░░░░░░░ 45%
───────────────────────────────────────────────
```

Persistence is designed, backed up, and **restore-tested**. Software stacks come next.

---

## What's Next

[Chapter 12: Building the Application Platform](12-building-the-application-platform.md) — install Docker; transform the host into an application platform before Kubernetes.

Your data survives reboots and proven snapshot restore. Now the host can run containers.

---

[← Chapter 10: Establishing Trust](10-establishing-trust.md) | [Next: Chapter 12 — Building the Application Platform →](12-building-the-application-platform.md)
