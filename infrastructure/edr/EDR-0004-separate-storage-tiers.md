# EDR-0004: Separate operating system, models, and application data

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 11 — Persistent Storage for Models and Data |
| **Date** | 2026-06-27 |

## Context

Hermes stores three categories of bytes with different growth rates and recovery needs:

- **Operating system stack** — Ubuntu, Docker, k3s, logs (replaceable from AMI + config)
- **Models** — large GGUF files, embeddings, Hugging Face cache (expensive to re-download)
- **Application data** — PostgreSQL, Redis persistence, vector indexes (irreplaceable if lost)

Combining all three on one volume means a full disk from models prevents PostgreSQL from writing, and a corrupted filesystem recovery requires restoring everything together.

## Decision

Use **three dedicated EBS gp3 volumes** on `hermes-controlplane-01`:

| Volume | Name | Size | Mount |
|--------|------|------|-------|
| Root | `hermes-root` | 100 GB | `/` |
| Models | `hermes-models` | 300 GB | `/models` |
| Data | `hermes-data` | 100 GB | `/data` |

Backup policy:

- **EBS snapshots** per volume on a schedule (manual in this chapter; automated later)
- **S3 bucket** `hermes-platform-backups-ACCOUNT_ID` for exports, manifests, and off-instance copies
- Apply **3-2-1 thinking**: live EBS + snapshots + S3 exports

## Consequences

**Positive:**

- Expand, snapshot, and restore each tier independently
- Model downloads do not fill the root filesystem
- Database recovery does not require re-fetching 250 GB of GGUF files
- Natural boundaries for Kubernetes PersistentVolumes in later chapters

**Negative:**

- Three volumes cost more than one (modest vs instance compute)
- More mount points and fstab entries to manage
- Operators must know which path belongs on which volume

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Single 500 GB root volume | No separation; snapshot/restore is all-or-nothing |
| Two volumes (root + models) | Database I/O competes with models; harder PostgreSQL ops |
| S3 as primary model store | Latency and cost for inference; EBS for hot models, S3 for archive |

## References

- [Chapter 11: Persistent Storage for Models and Data](../../docs/part-ii-aws/11-persistent-storage.md)
- [AWS EBS snapshots](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html)
