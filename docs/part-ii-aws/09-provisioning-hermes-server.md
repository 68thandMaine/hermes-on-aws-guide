---
sidebar_position: 9
description: "Provision hermes-controlplane-01 — the trusted foundation for Kubernetes and Hermes."
---

# Chapter 9: Provisioning the Hermes Server

> How do we provision a server that we can trust to become the foundation of the Hermes platform?

---

### The Big Idea

By the end of this chapter, you should **not** think:

> "I launched an EC2 instance."

You **should** think:

> "I provisioned **`hermes-controlplane-01`**—the machine that will eventually host Kubernetes, Hermes, llama.cpp, PostgreSQL, Redis, and every future service."

That machine has an identity. For the rest of this book, we refer to **`hermes-controlplane-01`**, not "the EC2."

---

The network exists ([Chapter 8](08-creating-network-for-hermes.md)). The account is secured ([Chapter 7](07-provisioning-aws-account.md)). Now you provision **the machine**—not "an EC2 instance" in the abstract, but **`hermes-controlplane-01`**: the server that will eventually host Kubernetes, Hermes, llama.cpp, PostgreSQL, Redis, and every future service you add to the platform.

By the end of this chapter, you should think:

> "I provisioned the foundation of the Hermes platform—and verified it is healthy before installing anything."

Not: "I clicked Launch Instance."

This chapter follows **Concept → Design → Implementation**. The AWS console appears only after you understand every decision.

:::note[Why this matters for Hermes]

A compromised or misconfigured server undermines everything built on top of it. Wrong instance sizing starves llama.cpp. A single undersized disk fills with GGUF models and crashes PostgreSQL. Password-based SSH invites brute force. This chapter establishes **trust in the machine itself**—correct AMI, evidence-based sizing, separated storage, automated bootstrap, SSH-only access from your IP—before Docker or k3s touch the host.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why EC2 fits the Hermes platform better than Lambda, ECS, or EKS *at this stage*
- [ ] Describe how an EC2 instance maps to a physical server through virtualization
- [ ] Explain what an AMI is and why Ubuntu Server 24.04 LTS is the starting state
- [ ] Size an instance type from workload RAM requirements—not from a random dropdown
- [ ] Explain why gp3 beats gp2 for root and data volumes
- [ ] Describe why SSH keys beat passwords and how cloud-init bootstraps the host
- [ ] Provision `hermes-controlplane-01` via CLI with three EBS volumes and user-data
- [ ] Verify the server is healthy before proceeding to [Chapter 10](10-establishing-trust.md)

---

## Prerequisites

- [Chapter 8: Creating the Network for Hermes](08-creating-network-for-hermes.md) — `hermes-vpc`, `hermes-public-usw2a`, resource IDs in `~/hermes-platform/notes/network-resources.env`
- AWS CLI profile `hermes` working
- SSH client on your laptop

Source network IDs before starting:

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-west-2
source ~/hermes-platform/notes/network-resources.env
```

---

## Estimated Time

**120 minutes** — 60 minutes concept and design, 60 minutes implementation and verification (includes waiting for instance status checks and cloud-init).

---

## Background

### Concept — The Problem

Imagine someone hands you a brand-new rack server.

Before installing Kubernetes…  
Before installing Docker…  
Before installing Hermes…

What do you do?

The answer is not "install software." The answer is:

> **Make sure the machine itself is trustworthy.**

That means confirming:

- The OS matches what you expect (Ubuntu LTS, patched baseline)
- CPU and RAM match your workload plan
- Disks are sized and separated for OS vs models
- The host configures itself reproducibly (not manual drift)
- Only you can administer it remotely (SSH keys, firewall philosophy)

That is exactly what this chapter accomplishes. Software stacks come in Chapters 12–16 and beyond. **Trust the hardware first.**

### Why Not Lambda, ECS, or EKS Today?

| Option | Why not *yet* for Hermes |
|--------|--------------------------|
| **Lambda** | No persistent local inference, no k3s, no GGUF on disk—wrong shape for a self-hosted agent platform |
| **ECS/Fargate** | Hides the node; you learn less about the machine Hermes runs on |
| **EKS** | Managed control plane before you understand k3s on one node ([Chapter 6 design](../part-i-foundations/06-designing-the-hermes-platform.md)) |

**EC2** gives you a virtual computer in `hermes-public-usw2a`. You own the full stack from kernel upward—matching the book's learning path and the single-node Hermes design.

---

## Theory

### Compute — From Laptop to EC2

AWS is not abstract "cloud." It is **virtual computers** in a data center:

```text
Your laptop
    │  (physical machine, one tenant: you)
    ▼
Physical server in AWS data center
    │  (hypervisor splits hardware)
    ▼
Virtual machine — EC2 instance
    │  (hermes-controlplane-01)
    ▼
Ubuntu → Docker → k3s → Hermes / llama.cpp / PostgreSQL / Redis
```

EC2 is the layer where you choose vCPUs, RAM, disks, and network attachment. Everything Hermes needs eventually runs **on this one instance** (iteration 1).

### AMIs — Choosing the Starting State

An **AMI (Amazon Machine Image)** is a snapshot of a machine:

- Operating system and kernel
- Root filesystem layout
- Default packages and configuration
- Boot loader behavior

Choosing an AMI is choosing **the starting state of your server**—not just "pick Ubuntu" from a dropdown.

This book standardizes on **Ubuntu Server 24.04 LTS (Noble Numbat)**:

- Same OS as local labs ([Chapter 3](../part-i-foundations/03-linux.md))
- Long support window, predictable packages
- Well supported by k3s, Docker, and Hermes tooling

We resolve the latest AMI ID at launch time via AWS SSM—never hard-code an AMI that goes stale.

### Instance Type — Evidence-Based Sizing

Do not memorize instance families. **Add up what Hermes needs:**

| Workload | RAM (planning estimate) | Notes |
|----------|-------------------------|-------|
| Ubuntu + system services | 1–2 GiB | Baseline OS |
| k3s control plane + kube-system | 2–4 GiB | Single-node k3s |
| Hermes API | 1–2 GiB | Orchestration, not inference |
| **llama.cpp** (7B–13B GGUF Q4) | 8–14 GiB | Largest consumer |
| PostgreSQL | 1–2 GiB | Agent state |
| Redis | 0.5–1 GiB | Queues, cache |
| Headroom (spikes, OS page cache) | 4–6 GiB | Avoid OOM kills |

**Total:** roughly **24–32 GiB** for a comfortable single-node dev platform.

| Instance | vCPU | RAM | Verdict |
|----------|------|-----|---------|
| `m7i.xlarge` | 4 | 16 GiB | Too tight—llama.cpp + k3s will swap |
| **`m7i.2xlarge`** | **8** | **32 GiB** | **Book standard** — matches [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md) |
| `m7i.4xlarge` | 16 | 64 GiB | Room for 30B+ models later |

**Design decision:** `m7i.2xlarge` for `hermes-controlplane-01`. Downsize only after metrics prove headroom; upsize when model weights grow.

### Storage — Two Volumes from Day One

Most tutorials give you one disk and dump everything on it. That makes upgrades, snapshots, and disaster recovery messy.

**Design:**

```text
Root volume (100 GB gp3)
    └── Ubuntu, Docker, k3s, logs

Models volume (300 GB gp3 — `hermes-models`)
    └── /models — GGUFs, embeddings, Hugging Face cache

Data volume (100 GB gp3 — `hermes-data`)
    └── /data — PostgreSQL, Redis persistence, vector indexes

Future backups
    └── S3 (Chapter 11)
```

Application databases (PostgreSQL data) may use additional paths under `/opt/data` on the root volume initially; [Chapter 11](11-persistent-storage.md) covers snapshots and S3 backups. **Separating models early** keeps a 40 GB GGUF download off your root disk and makes volume snapshots targeted.

**gp3 vs gp2:** gp3 offers baseline 3,000 IOPS independent of volume size, lower cost than gp2 at most sizes, and predictable performance for model loads. Use gp3 unless you have a specific reason not to.

### Bootstrap — cloud-init from Day One

Servers should **configure themselves** on first boot—not accumulate manual changes you cannot reproduce.

**cloud-init** runs user-data scripts when the instance first starts. Even a minimal script teaches the right habit:

- Set hostname to `hermes-controlplane-01`
- Install baseline packages (`curl`, `git`, `htop`, …)
- Format and mount **`hermes-models`** at `/models` and **`hermes-data`** at `/data`

Later chapters extend this script or replace it with Ansible/Terraform + cloud-init. The pattern starts here.

The canonical bootstrap script lives in the repo:

```text
code/infrastructure/aws/cloud-init/hermes-controlplane-bootstrap.sh
```

### Security — Philosophy Before Implementation

Do not create security groups yet. Understand the rules first:

```text
SSH (22)         →  Your IP only
HTTPS (443)      →  Later (Chapter 10, when Traefik is ready)
Everything else  →  Closed
```

PostgreSQL (5432), Redis (6379), and llama.cpp inference ports stay **localhost/cluster-only**—never exposed to the internet.

SSH **keys** beat passwords: no brute-force surface, auditable key pairs, easy rotation.

You will apply a **temporary** security group during [Implementation](#walkthrough) below—SSH from your current IP only. [Chapter 10](10-establishing-trust.md) hardens further (`ufw`, HTTPS rules, host-level firewall).

---

## Architecture

### Design — hermes-controlplane-01

```text
Internet
    │
Elastic IP (hermes-controlplane-eip)
    │
Security Group (hermes-controlplane-sg)
    │  inbound: TCP 22 from YOUR_IP/32
    │
hermes-controlplane-01  (m7i.2xlarge)
    ├── hermes-vpc / hermes-public-usw2a
    ├── Volume 1: 100 GB gp3 root (`hermes-root`)
    ├── Volume 2: 300 GB gp3 → `/models` (`hermes-models`)
    ├── Volume 3: 100 GB gp3 → `/data` (`hermes-data`)
    └── cloud-init → hostname, packages, mounts
```

| Resource | Name |
|----------|------|
| EC2 instance | `hermes-controlplane-01` |
| Key pair | `hermes-controlplane-key` |
| Security group | `hermes-controlplane-sg` |
| Elastic IP | `hermes-controlplane-eip` |
| Root volume | `hermes-root` — 100 GB gp3 |
| Models volume | `hermes-models` — 300 GB gp3 → `/models` |
| Data volume | `hermes-data` — 100 GB gp3 → `/data` |

### Infrastructure Artifacts (Start IaC Early)

Every implementation chapter adds to the repo tree—even before Terraform:

```text
code/infrastructure/
└── aws/
    ├── cloud-init/
    │   └── hermes-controlplane-bootstrap.sh
    ├── cli/
    │   ├── ch09-provision-controlplane.sh
    │   └── README.md
    └── terraform/
        └── README.md          ← filled in Part V
```

After this chapter you have:

- A reusable **cloud-init** bootstrap
- **CLI** commands (and script) you executed
- A **terraform/** directory reserved for codification in [Chapter 30](../part-v-infrastructure/30-terraform.md)

Nothing stays hand-built forever.

---

## Walkthrough {#walkthrough}

### Implementation — CLI (Canonical Path)

You understand **why** each decision exists. Now provision **`hermes-controlplane-01`**.

The AWS console can launch the same resources (EC2 → Launch instance → Ubuntu 24.04, advanced details → user-data, two gp3 volumes)—but the **CLI is canonical** because it is reproducible and matches what Terraform will express in Part V. Console steps are reference-only; do not screenshot your way through the book.

Set environment:

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-west-2
source ~/hermes-platform/notes/network-resources.env
```

#### Step 1 — Resolve the Ubuntu 24.04 AMI

```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")

echo "AMI_ID=$AMI_ID"
```

SSM always returns a current Noble AMI—no manual lookup table.

#### Step 2 — Create an SSH Key Pair

```bash
KEY_NAME=hermes-controlplane-key

aws ec2 create-key-pair \
  --key-name "$KEY_NAME" \
  --query 'KeyMaterial' \
  --output text \
  --region "$AWS_REGION" > ~/.ssh/${KEY_NAME}.pem

chmod 600 ~/.ssh/${KEY_NAME}.pem
echo "Private key: ~/.ssh/${KEY_NAME}.pem"
```

If you already have a key, import your public key instead:

```bash
aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material fileb://~/.ssh/id_ed25519.pub
```

**Never commit `.pem` files to Git.**

#### Step 3 — Create Security Group (Implementation — SSH from Your IP Only)

Philosophy was in [Theory](#security--philosophy-before-implementation). Now apply the minimum rule set:

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')
echo "Your IP: $MY_IP"

SG_ID=$(aws ec2 create-security-group \
  --group-name hermes-controlplane-sg \
  --description "Hermes control plane — SSH from operator IP" \
  --vpc-id "$HERMES_VPC_ID" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION")

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "${MY_IP}/32" \
  --region "$AWS_REGION"
```

#### Step 4 — Launch hermes-controlplane-01

From the repository root, user-data references the bootstrap script:

```bash
USER_DATA_FILE=code/infrastructure/aws/cloud-init/hermes-controlplane-bootstrap.sh

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type m7i.2xlarge \
  --key-name "$KEY_NAME" \
  --subnet-id "$HERMES_PUBLIC_SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --user-data "file://${USER_DATA_FILE}" \
  --block-device-mappings \
    '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3","DeleteOnTermination":true}},{"DeviceName":"/dev/sdf","Ebs":{"VolumeSize":300,"VolumeType":"gp3","DeleteOnTermination":false}},{"DeviceName":"/dev/sdg","Ebs":{"VolumeSize":100,"VolumeType":"gp3","DeleteOnTermination":false}}]' \
  --tag-specifications \
    'ResourceType=instance,Tags=[{Key=Name,Value=hermes-controlplane-01},{Key=Project,Value=hermes},{Key=Role,Value=controlplane}]' \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$AWS_REGION")

echo "INSTANCE_ID=$INSTANCE_ID"
```

Or run the consolidated script (review it first):

```bash
bash code/infrastructure/aws/cli/ch09-provision-controlplane.sh
```

#### Step 5 — Wait for Running + Status Checks

```bash
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
```

Status checks confirm AWS hypervisor and instance reachability—not that cloud-init finished. You verify bootstrap separately.

#### Step 6 — Allocate Elastic IP

A stable IP survives instance stop/start and becomes your Hermes HTTPS endpoint:

```bash
EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=hermes-controlplane-eip}]' \
  --query AllocationId \
  --output text \
  --region "$AWS_REGION")

aws ec2 associate-address \
  --instance-id "$INSTANCE_ID" \
  --allocation-id "$EIP_ALLOC" \
  --region "$AWS_REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region "$AWS_REGION")

echo "PUBLIC_IP=$PUBLIC_IP"
```

#### Step 7 — Save Control Plane Notes

```bash
mkdir -p ~/hermes-platform/notes
cat > ~/hermes-platform/notes/controlplane.env <<EOF
export HERMES_INSTANCE_ID=$INSTANCE_ID
export HERMES_PUBLIC_IP=$PUBLIC_IP
export HERMES_SG_ID=$SG_ID
export HERMES_KEY_NAME=$KEY_NAME
export HERMES_AMI_ID=$AMI_ID
EOF
```

#### Step 8 — SSH and Wait for cloud-init

Give cloud-init 2–3 minutes on first boot:

```bash
ssh -i ~/.ssh/${KEY_NAME}.pem -o StrictHostKeyChecking=accept-new ubuntu@${PUBLIC_IP} \
  'cloud-init status --wait || true; test -f /var/lib/hermes-bootstrap-complete && echo BOOTSTRAP_OK'
```

### AWS Console (Reference Only)

See walkthrough introduction—use CLI or `code/infrastructure/aws/cli/ch09-provision-controlplane.sh` as source of truth.

---

## Hands-on Lab

### Lab 9: Provision hermes-controlplane-01

**Estimated Time:** 60 minutes

**Goal:** Launch a verified, bootstrapped control plane server with three EBS volumes and documented artifacts in `code/infrastructure/aws/`.

**Prerequisites:** Chapter 8 network resources sourced

**Steps:**

1. Complete Walkthrough Steps 1–8
2. Run the full [Verification](#verification) checklist on the instance
3. Confirm `code/infrastructure/aws/cloud-init/hermes-controlplane-bootstrap.sh` exists in your clone
4. Record `HERMES_PUBLIC_IP` in `~/hermes-platform/notes/controlplane.env`
5. Update Chapter 6 worksheet — mark EC2 row complete

**Verification:** All items in [Verification](#verification) pass.

**Cleanup:** Do **not** terminate the instance—you need it for the rest of the book. To save cost during a long break, `aws ec2 stop-instances` (EBS still bills).

---

## Verification

The chapter does not end until **`hermes-controlplane-01` is proven healthy.**

### AWS — Instance and Volumes

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,IP:PublicIpAddress,Name:Tags[?Key==`Name`].Value|[0],AZ:Placement.AvailabilityZone}' \
  --output table
```

Expected: `running`, `m7i.2xlarge`, `hermes-controlplane-01`.

```bash
aws ec2 describe-volumes \
  --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
  --query 'Volumes[*].{Size:Size,Type:VolumeType,Device:Attachments[0].Device,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

Expected: **100 GB** root + **300 GB** models + **100 GB** data.

### SSH — Host Identity and Bootstrap

```bash
ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${PUBLIC_IP} <<'EOF'
set -e
hostname                    # hermes-controlplane-01
cloud-init status
test -f /var/lib/hermes-bootstrap-complete && echo "bootstrap: complete"
for pkg in curl git htop jq tree; do dpkg -l "$pkg" | grep -q ^ii && echo "pkg $pkg: ok"; done
lsblk -o NAME,SIZE,MOUNTPOINT
df -h / /models /data
mount | grep -E '/models|/data'
EOF
```

Expected:

- Hostname `hermes-controlplane-01`
- cloud-init `done` or `completed`
- Packages installed
- Models volume mounted at `/models`; data volume at `/data`

### Checklist

- [ ] Instance state `running`; system status checks passed
- [ ] SSH login as `ubuntu` succeeds with key (no password)
- [ ] cloud-init completed; `/var/lib/hermes-bootstrap-complete` exists
- [ ] `curl`, `git`, `htop`, `jq`, `tree` installed
- [ ] Three EBS volumes attached (100 + 300 + 100 GB gp3)
- [ ] `/models` and `/data` mounted on dedicated volumes
- [ ] Elastic IP associated; IP saved to `controlplane.env`
- [ ] Docker **not** installed yet ([Chapter 12](12-building-the-application-platform.md))

Only then proceed to [Chapter 10](10-establishing-trust.md).

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `InsufficientInstanceCapacity` | AZ out of `m7i.2xlarge` | Retry later, try another AZ (update subnet), or temporarily use `m7i.xlarge` knowing RAM limits |
| SSH timeout | SG wrong IP or no public IP | Verify `MY_IP/32` on port 22; confirm Elastic IP associated |
| Permission denied (publickey) | Wrong key or permissions | Use `~/.ssh/hermes-controlplane-key.pem`, mode `600`, user `ubuntu` |
| `/models` or `/data` not mounted | cloud-init still running or missing third volume | Check `/var/log/hermes-bootstrap.log`; see [Chapter 11](11-persistent-storage.md) to add `hermes-data` |
| Status checks fail | Instance still initializing | Wait 5 minutes; check EC2 console → Status checks |
| Duplicate security group | Re-running create | Use `describe-security-groups` to reuse existing `hermes-controlplane-sg` |

---

## Review Questions

1. Why do we provision `hermes-controlplane-01` instead of "launching EC2"?
2. What is an AMI, and why use SSM to resolve the AMI ID?
3. Walk through the RAM table—why `m7i.2xlarge` and not `m7i.xlarge`?
4. Why separate root, models, and data volumes?
5. Why gp3 over gp2?
6. What does cloud-init accomplish on first boot?
7. Why SSH keys instead of passwords?
8. Why allocate an Elastic IP now?
9. What three artifacts does this chapter add under `code/infrastructure/aws/`?

---

## Key Takeaways

- **Trust the machine first** — verify health before installing Docker or k3s
- **`hermes-controlplane-01`** is the platform foundation—not a disposable lab VM
- **Evidence-based sizing:** ~32 GiB RAM for llama.cpp + k3s + Hermes stack → `m7i.2xlarge`
- **Three gp3 volumes:** OS (`hermes-root`), models (`hermes-models` → `/models`), data (`hermes-data` → `/data`)
- **cloud-init** from day one—servers configure themselves; script lives in `code/infrastructure/aws/cloud-init/`
- **CLI over console** — reproducible, Terraform-ready; script in `code/infrastructure/aws/cli/`
- **Security philosophy:** SSH from your IP only; everything else closed until later chapters

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **AMI** | Amazon Machine Image—template defining OS, disk, and boot configuration. |
| **Instance type** | vCPU + RAM bundle (e.g., `m7i.2xlarge` = 8 vCPU, 32 GiB). |
| **EBS gp3** | General-purpose SSD with baseline IOPS independent of size. |
| **cloud-init** | First-boot service that runs user-data to configure instances. |
| **User-data** | Script or cloud-config passed at launch—bootstrap automation. |
| **Elastic IP** | Static public IPv4 address you allocate and associate to instances. |
| **Key pair** | SSH public key in AWS + private key on your laptop for authentication. |

---

## Further Reading

- [EC2 instance types](https://aws.amazon.com/ec2/instance-types/)
- [Ubuntu on AWS](https://ubuntu.com/aws)
- [cloud-init documentation](https://cloudinit.readthedocs.io/)
- [EBS volume types](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html)
- Repo: [`code/infrastructure/README.md`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/README.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account            ✓
Billing Alerts         ✓
MFA                    ✓
IAM Administrator      ✓

VPC                    ✓
Subnet                 ✓
Internet Gateway       ✓
Route Table            ✓

EC2                    ✓
Ubuntu                 ✓
Cloud-init             ✓

Docker                 ✗
k3s                    ✗
Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

█████░░░░░░░░░░░░░░░░ 28%
───────────────────────────────────────────────
```

`hermes-controlplane-01` is running and verified. The platform has a home.

---

## What's Next

The server exists—but trust boundaries are not defined yet.

[Chapter 10: Establishing Trust](10-establishing-trust.md) answers who may interact with the platform—SSH identity, Security Groups, UFW, and host hardening before any software stack.

---

[← Chapter 8: Creating the Network for Hermes](08-creating-network-for-hermes.md) | [Next: Chapter 10 — Establishing Trust →](10-establishing-trust.md)
