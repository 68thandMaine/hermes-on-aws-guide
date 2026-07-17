---
sidebar_position: 41
description: "Operating Hermes in production — rolling deploys, backups, SLOs, and runbooks."
---

# Chapter 41: Operating Hermes in Production

> Building a system is a milestone.
>
> Operating it is the profession.

---

Parts I–VI and [Chapters 39](40-distributed-cognitive-execution.md) built Hermes. **Chapter 41 begins a different job**: you are no longer primarily a builder—you are an **operator** of a living distributed AI platform.

```text
Chapters 1–39:  "Does it work?"
Chapter 41+:    "Will it still work tomorrow while we change it?"
```

By now: users request, workers reason, models serve, memory grows. The new problem:

> **How do you change the system without breaking it?**

This chapter ties together [Terraform](../part-v-infrastructure/30-terraform.md), [GitHub Actions](../part-v-infrastructure/31-github-actions.md), [Secrets](../part-v-infrastructure/32-secrets-management.md), [Monitoring & Logging](../part-v-infrastructure/33-monitoring.md), [Kubernetes](../part-iv-kubernetes/22-deployments.md), and [Hermes runtime](40-distributed-cognitive-execution.md) into **production engineering**—preserving correctness while change is continuous.

:::note[Operator shift]

No new infrastructure primitives. You apply patterns you already built—rolling updates, backups, alerts, runbooks—against a **system that thinks**.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Distinguish development ("does it work?") from operations ("still works under change")
- [ ] Perform zero-downtime rolling deployments on `hermes-api`
- [ ] Roll back failed releases with `kubectl rollout undo`
- [ ] Manage model upgrades separately from application deploys
- [ ] Define backup scope for Postgres, Qdrant, and Redis
- [ ] Outline disaster recovery using Terraform + declarative manifests
- [ ] Set SLOs and connect them to [Chapter 33](../part-v-infrastructure/33-monitoring.md) alerts
- [ ] Use runbooks when alerts fire

---

## Prerequisites

- Hermes lab stack running ([Chapter 35](../part-vi-ai/35-running-hermes.md))
- Monitoring + logging ([Chapters 33–34](../part-v-infrastructure/33-monitoring.md))
- CI pipeline awareness ([Chapter 31](../part-v-infrastructure/31-github-actions.md))
- Backup baseline ([Chapter 11](../part-ii-aws/11-persistent-storage.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n hermes
```

---

## Estimated Time

**90 minutes** — 35 minutes reading, 55 minutes rollout + rollback lab.

---

## Background

### The Production Mindset

| Question | Owner |
|----------|--------|
| Does it work? | Development / build chapters |
| Will it work tomorrow? | **Operations** |
| Can we change it safely? | **Operations** |
| Can we recover when it fails? | **Operations** |

Production engineering = **preserving correctness while change occurs**.

### The Production Stack (All Alive)

```text
                 Users
                   │
                Ingress
                   │
            Hermes API Pods
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
    Workers    Model      Databases
        │          │          │
        └──────────┼──────────┘
                   ▼
             Monitoring
                   │
             Logging / Tracing
                   │
              Alerting
```

Your responsibility: **keep every layer healthy** while deploying, scaling, and upgrading.

### Operational Lifecycle

```text
Code change
      ↓
GitHub Actions (Ch 31)
      ↓
Image / manifest publish
      ↓
Rolling deployment (K8s)
      ↓
Monitoring detects drift
      ↓
Alert → Runbook → Recovery
```

---

## Walkthrough

### Step 1 — Rolling Deployments

Never require users to wait for a full restart. Kubernetes **rolling updates** replace Pods incrementally:

```text
Old Pods  ████████
          ██████░░
          ████░░░░
          ░░░░████
New Pods  ████████
```

Production strategy (in `values-production-rollout.yaml`):

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

Apply three API replicas:

```bash
helm upgrade hermes-lab code/infrastructure/helm/hermes-lab -n hermes \
  -f code/infrastructure/helm/hermes-lab/values.yaml \
  -f code/infrastructure/helm/hermes-lab/values-with-llama.yaml \
  -f code/infrastructure/helm/hermes-lab/values-production-rollout.yaml
```

Watch rollout:

```bash
kubectl rollout status deployment/hermes-api -n hermes
kubectl get pods -n hermes -l app=hermes-api -w
```

### Step 2 — Lab: Zero-Downtime Deploy

1. Scale API to 3 replicas (values above)
2. Continuous curl via Ingress (`while true; do curl -sf -H "Host: hermes.local" http://$NODE_IP/ || echo FAIL; sleep 0.5; done`)
3. Change API image tag in values; `helm upgrade`
4. Observe Pods replace one at a time
5. Confirm no `FAIL` lines during rollout

### Step 3 — Rollbacks

Not every deploy succeeds.

```bash
kubectl rollout history deployment/hermes-api -n hermes
kubectl rollout undo deployment/hermes-api -n hermes
```

Practice: deploy a deliberately broken tag (e.g. invalid image), confirm failure, `rollout undo`. **Every deployment must be reversible.**

### Step 4 — Model Version Management

Models are **large binaries** on `/models` ([Ch 37](../part-vi-ai/37-model-serving.md))—not git diffs.

Do not swap `Qwen-9B` → `Qwen-14B` in place without validation:

```text
Worker routes by policy
      ├────────► llama-server (model v1 / CPU)
      └────────► llama-server-gpu or second release (model v2)
```

Compare latency, quality, memory, error rate. Promote only after measurement. Model upgrades are **operations events**, not casual config edits.

### Step 5 — Database Migrations

App deploys roll back easily. **Schema changes do not.**

Safe sequence:

```text
1. Deploy app compatible with OLD and NEW schema
2. Run migration (forward-only, tested)
3. Verify reads/writes
4. Enable new code paths
5. Remove compatibility shims in later release
```

Task schema ([`task-schema.example.sql`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/task-schema.example.sql)) changes follow the same discipline—especially with distributed tasks ([Ch 40](40-distributed-cognitive-execution.md)).

### Step 6 — Backup Strategy

| Component | Backup? | Why |
|-----------|---------|-----|
| **PostgreSQL** | Yes | Durable tasks, steps, user state |
| **Qdrant** | Yes | Semantic memory |
| **Kubernetes manifests / Helm** | Yes (Git) | Desired state recovery |
| **Redis** | Usually no | Ephemeral locks/queues |
| **GGUF on EBS** | Yes ([Ch 11](../part-ii-aws/11-persistent-storage.md)) | Re-download is slow |

**Restore drill:** before trusting backups, restore Postgres + Qdrant into a fresh namespace once.

### Step 7 — Disaster Recovery Outline

EC2 control plane lost:

1. `terraform apply` — VPC, node ([Ch 30](../part-v-infrastructure/30-terraform.md))
2. Bootstrap k3s ([Ch 13](../part-ii-aws/13-the-first-control-plane.md))
3. Restore Helm releases from Git (`hermes-lab`, `llama-server`, monitoring, logging)
4. Restore Postgres snapshot / dump
5. Restore Qdrant volume or snapshot
6. Verify monitoring + sample task
7. Resume Ingress traffic

Declarative infra makes recovery **reproducible**, not heroic.

### Step 8 — Capacity Planning

Failures from **saturation**, not only crashes. Watch ([Ch 33](../part-v-infrastructure/33-monitoring.md)):

- Node CPU/memory (`kubectl top`)
- Disk on `/models` and Postgres PVC
- Inference queue depth / worker backlog
- p95 API and completion latency

Scale on **measurements**—[Chapter 44](44-from-development-to-production.md) brings the full stack into production with operational discipline.

### Step 9 — Service Level Objectives

Define healthy. Example targets ([`slo.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/slo.example.yaml)):

| Metric | Target |
|--------|--------|
| API availability | 99.9% / 30d |
| API latency p50 | < 300 ms |
| Inference p95 | < 2 s |
| Task completion | > 99% |

Monitoring without SLOs is dashboards without decisions.

### Step 10 — Runbooks

When alerts fire, responders follow **documented steps**—not improvisation.

Example: [`code/infrastructure/hermes/runbooks/high-cpu-model-server.md`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/runbooks/high-cpu-model-server.md)

Link runbooks from Alertmanager annotations ([Ch 33](../part-v-infrastructure/33-monitoring.md)).

### Step 11 — Cost Management

Production runs continuously ([Ch 16](../part-ii-aws/16-managing-platform-costs.md)):

- EC2 + GPU instance hours
- EBS + snapshots
- Model storage size
- Log/metric retention (Ch 33–34 bounds)

Optimize from **observed** usage—stop GPU nodes when idle ([Ch 38](../part-vi-ai/38-gpu-instances.md)).

---

## Operational Principles

Hermes is operated by rules, not heroics:

1. **Every deployment is reversible**
2. **Every change is observable**
3. **Every failure is recoverable** (durable tasks, Ch 39)
4. **Every backup is tested**
5. **Every alert has a runbook**
6. **Every component is recreatable from source** (Git + Terraform)

---

## Hands-on Lab

### Lab 40: Operate a Rollout

**Estimated Time:** 55 minutes

**Goal:** Rolling update with zero failed curls; successful rollback practice.

**Steps:**

1. Apply `values-production-rollout.yaml`
2. Start continuous Ingress curl loop
3. `helm upgrade` with harmless label change on API
4. `kubectl rollout status` — confirm success
5. Deploy broken image tag; observe failure; `rollout undo`
6. Write one SLO for your lab in `~/hermes-platform/notes/slo.md`

---

## Verification

- [ ] API runs ≥3 replicas with `maxUnavailable: 0`
- [ ] Rollout completes without user-visible errors in curl loop
- [ ] Successful `rollout undo` after bad deploy
- [ ] You can list backup targets for Postgres, Qdrant, Redis
- [ ] You can sketch DR steps from Terraform to traffic
- [ ] One runbook exists for a known alert

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Rollout stuck | `maxSurge` 0 + no capacity | Free node resources; adjust surge |
| All curls fail mid-rollout | Single replica or bad probe | Use production rollout values |
| Undo doesn't help | ReplicaSet history pruned | Lower `revisionHistoryLimit`; redeploy known good |
| Model upgrade OOM | Larger GGUF | Dual-path validate on GPU; rollback symlink |
| Backup useless | Never tested restore | Run restore drill quarterly |

---

## Review Questions

1. Why is operating different from building?
2. Why `maxUnavailable: 0` for user-facing API?
3. Why treat model upgrades separately from app deploys?
4. Why is Redis usually not backed up?
5. What ties an alert to an action?

---

## Key Takeaways

- **Chapter 41 is the operator shift**—Hermes is alive; you preserve correctness under change
- **Rolling deploys + rollbacks** are core Kubernetes operations skills
- **Backups and DR** leverage declarative infra from Part II and Part V
- **SLOs + runbooks** turn monitoring into engineering discipline
- **Production-ready** means reversible, observable, recoverable—not merely "deployed once"

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Rolling update** | Replace Pods incrementally to maintain availability. |
| **SLO** | Service level objective—measurable target for reliability. |
| **Runbook** | Documented incident response procedure. |
| **DR** | Disaster recovery—restore platform from backups + IaC. |

---

## Further Reading

- [Kubernetes Deployments — rolling updates](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
- [Chapter 31: GitHub Actions](../part-v-infrastructure/31-github-actions.md)
- [Chapter 11: Persistent Storage](../part-ii-aws/11-persistent-storage.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

System built (Ch 1–39)         ✓
Operating procedures (Ch 41)   ✓
Governance / security (Ch 42)  ✓

Capstone (Ch 45)               ◐
───────────────────────────────────────────────
```

You are now an **operator** of Hermes—not only its builder.

---

## What's Next

[Chapter 42: Security, Governance, and Trust](42-platform-governance.md) — authorization, auditability, prompt-injection resistance, human approvals, and AI-specific controls. **The language model is never the security boundary.**

---

[← Chapter 40: Distributed Cognitive Execution](40-distributed-cognitive-execution.md) | [Next: Chapter 42 — Security & Governance →](42-platform-governance.md)
