---
sidebar_position: 4
description: "Monthly AWS cost estimates — development, staging, and production."
---

# Appendix: AWS Cost Estimates

Order-of-magnitude monthly costs for the Hermes platform. **Verify with [AWS Pricing Calculator](https://calculator.aws/)** for your region and commitment level—these numbers are planning guides from [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md) and operational chapters.

:::warning[Not a quote]

On-demand US West (Oregon) `us-west-2` estimates as of book writing. Reserved Instances, Savings Plans, and Spot change these materially. **Stop EC2 when not learning** to avoid continuous compute charges.

:::

---

## Development — single-node k3s lab

What you run through Chapters 9–43 on one `hermes-controlplane-01` instance.

| Item | Specification | Rough monthly (USD) |
|------|---------------|-------------------|
| EC2 compute | `m7i.2xlarge` on-demand (8 vCPU, 32 GiB) | $250–290 |
| EBS root | 100 GB gp3 | ~$8 |
| EBS models | 300 GB gp3 (`/models`) | ~$24 |
| EBS data | 100 GB gp3 (`/data`) | ~$8 |
| Elastic IP | Attached to running instance | $0 |
| S3 backups | Modest manifests + occasional dumps | $1–5 |
| Secrets Manager | 1–3 secrets | &lt; $1 |
| Data transfer | Light lab traffic | $1–5 |
| **Typical total** | Instance running 24/7 | **~$290–340** |

### Cost reduction (development)

| Action | Savings |
|--------|---------|
| `aws ec2 stop-instances` when not labbing | Stops compute; EBS still bills (~$40/mo storage) |
| Use `m7i.xlarge` for non-inference chapters only | ~50% compute; **too tight** for llama + full Hermes stack |
| Delete old EBS snapshots after restore drills | Snapshot storage adds up |
| Set CloudWatch billing alarm at $50 ([Ch 7](../part-ii-aws/07-provisioning-aws-account.md)) | Catches surprise spend early |

---

## Staging — production-like, reduced scale

Same architecture as production; fewer replicas and shorter retention.

| Item | vs development | Delta |
|------|----------------|-------|
| EC2 | Same or second small node | +$0–290 if separate node |
| Hermes API replicas | 2–3 (rollout lab) | Absorbed in same node if single-node |
| Monitoring/logging | Enabled with shorter retention | +$0 (in-cluster; RAM pressure) |
| Synthetic traffic | Minimal | Negligible |
| **Typical total** | Single-node staging | **~$290–350** |

Staging value is **process** (promotion checklist), not extra hardware—on a lab budget, staging can be the same instance with different Helm values ([`environment-promotion.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/environment-promotion.example.yaml)).

---

## Production — real users, HA intent

| Item | Specification | Rough monthly (USD) |
|------|---------------|-------------------|
| EC2 control plane | `m7i.2xlarge` × 1 (single-node k3s lab path) | $250–290 |
| EC2 workers (optional) | Additional node(s) for HA | +$250+ each |
| GPU inference (optional) | `g5.xlarge` when running ([Ch 38](../part-vi-ai/38-gpu-instances.md)) | ~$1.00–1.50/hr on-demand |
| EBS | 500 GB gp3 total + snapshots | ~$50–80 |
| S3 | Backups, artifacts, log archive | $5–20 |
| Secrets Manager + API calls | Production secret count | $1–5 |
| Route 53 + ACM | DNS + TLS ([Ch 14](../part-ii-aws/14-routing-traffic-to-hermes.md) path) | $1–5 |
| CloudWatch / observability egress | If shipping logs off-cluster | Variable |
| **Single-node production** | Honest k3s lab limits | **~$350–450** |
| **+ GPU 8h/day** | Inference bursts | **+$240–360** |
| **Multi-node HA** | 2–3 EC2 + managed RDS (future) | **$800–1,500+** |

### Production cost levers ([Chapter 41](../part-vii-hermes/41-operating-hermes-in-production.md), [43](../part-vii-hermes/44-from-development-to-production.md))

| Lever | Mechanism |
|-------|-----------|
| Right-size instance | `kubectl top nodes`; scale down if headroom &gt; 60% sustained |
| HPA on workers | Scale replicas on queue depth, not fixed over-provision |
| GPU schedule | Start GPU node for inference windows; stop when idle |
| Log retention | Bound Loki retention ([Ch 34](../part-v-infrastructure/34-logging.md)) |
| Vector TTL | Expire unused Qdrant collections ([Ch 36](../part-vi-ai/36-vector-databases.md)) |
| Reserved Instances | 1-year commit on steady control plane |
| Snapshot lifecycle | Delete snapshots older than policy |

---

## Cost by book phase

| Phase | Chapters | Expected AWS spend |
|-------|----------|-------------------|
| Account setup only | 7 | ~$0 (no EC2 yet) |
| Network + EC2 provisioned | 8–9 | ~$290/mo once instance runs |
| Full platform + AI | 11–38 | ~$290–340/mo; +GPU hourly |
| Production operations | 40–43 | Same hardware; discipline matters more than size |

---

## Billing guardrails (from Day 1)

1. Enable billing alerts ([Chapter 7](../part-ii-aws/07-provisioning-aws-account.md)) — e.g. $50 while learning
2. Review Cost Explorer weekly once EC2 is running
3. Tag resources: `Project=hermes`, `Environment=dev|staging|prod`
4. Never leave GPU instances running overnight after labs

---

[← Repository Walkthrough](repository-walkthrough.md) | [Troubleshooting Guide →](troubleshooting.md)
