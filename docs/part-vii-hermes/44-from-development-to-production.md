---
sidebar_position: 44
description: "From development to production — promoting Hermes with operational discipline."
---

# Chapter 44: From Development to Production

> Production is not a different system.
>
> It is the same system held to a higher standard.

---

You have spent forty-two chapters building Hermes piece by piece—Linux, AWS, containers, Kubernetes, Terraform, CI/CD, secrets, monitoring, logging, inference, agents, operations, governance, extensions.

**Chapter 44 is the payoff.** No new infrastructure primitives. No new AI concepts. For the first time, step back and see the whole:

> **"I could actually run this."**

It is no longer about Kubernetes, AWS, or AI individually. It is about taking the **complete system** from a laptop lab into a production environment you trust—with evidence, not optimism.

:::note[Last technical chapter]

Chapter 44 synthesizes everything into a **production operating model**. [Chapter 45](45-the-platform-you-built.md) steps back for the retrospective—connecting every layer from the first Linux process to the distributed cognitive platform you operate today.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Describe how the environment matured while Hermes stayed architecturally stable
- [ ] Promote the same artifacts from development → staging → production
- [ ] Explain what changes between lab and production (guarantees, not application logic)
- [ ] Plan HA and independent scaling per subsystem
- [ ] Complete a production readiness assessment with evidence
- [ ] Optimize costs from measurements ([Chapter 16](../part-ii-aws/16-managing-platform-costs.md))
- [ ] Recognize a "ordinary" successful production day as the goal

---

## Prerequisites

You should have worked through—or equivalent experience with:

- k3s lab ([Chapter 13](../part-ii-aws/13-the-first-control-plane.md), [Chapter 35](../part-vi-ai/35-running-hermes.md))
- Terraform + GitHub Actions ([Chapters 29–30](../part-v-infrastructure/30-terraform.md))
- Operating procedures ([Chapter 41](41-operating-hermes-in-production.md))
- Governance ([Chapter 42](42-platform-governance.md))
- Extensions ([Chapter 43](43-extending-hermes.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n hermes
```

---

## Estimated Time

**75 minutes** — 45 minutes reading and reflection, 30 minutes readiness checklist.

---

## Looking Back

The first time you ran Hermes, the architecture looked like this:

```text
Laptop
   │
Docker
   │
Single Process
```

As the book progressed:

```text
Laptop
   │
SSH
   │
AWS EC2
   │
k3s
   │
Hermes
```

Now:

```text
Git
   │
GitHub Actions
   │
Terraform
   │
AWS
   │
Kubernetes
   │
Hermes
```

**Notice something important:** Hermes itself—the reasoning loop, task model, worker mediation, tool gateway—has **barely changed** since [Chapter 39](../part-vi-ai/39-ai-agent-architecture.md). The **environment around it** matured. That is the sign of a platform, not a demo.

| Phase | What you learned | Book anchor |
|-------|------------------|-------------|
| Foundations | Processes, networks, Linux | Part I |
| Cloud substrate | EC2, VPC, storage, cost | Part II |
| Orchestration | k3s, Deployments, Helm | Parts III–IV |
| Platform engineering | Terraform, CI, secrets, observability | Part V |
| Cognitive runtime | Hermes, Qdrant, llama-server, agents | Parts VI–VII |

You did not learn forty-three unrelated tools. You learned **one stack**, assembled deliberately from [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md) forward.

---

## What Changes Between Development and Production?

Many readers assume production requires a completely different architecture. **It does not.** Most components stay the same software. **Operational guarantees** change.

| Component | Development (lab) | Production | Book reference |
|-----------|-------------------|------------|----------------|
| Kubernetes | Single-node k3s | Multi-node or HA k3s | [Ch 13](../part-ii-aws/13-the-first-control-plane.md), [Ch 29](../part-iv-kubernetes/29-scaling.md) |
| Hermes API | 1–2 replicas | 3+ replicas, rolling deploy | [Ch 41](41-operating-hermes-in-production.md), `values-production-rollout.yaml` |
| PostgreSQL | Single Pod + PVC | Managed RDS or replicated | [Ch 11](../part-ii-aws/11-persistent-storage.md), [Ch 35](../part-vi-ai/35-running-hermes.md) |
| Redis | Single instance | HA Redis or managed | [Ch 35](../part-vi-ai/35-running-hermes.md) |
| Qdrant | local-path PVC | Replicated volume or managed | [Ch 36](../part-vi-ai/36-vector-databases.md) |
| Model server | CPU inference | CPU pool + optional GPU pool | [Ch 37–38](../part-vi-ai/37-model-serving.md) |
| Monitoring | Lab Grafana | Persistent dashboards + on-call alerts | [Ch 33](../part-v-infrastructure/33-monitoring.md) |
| Logging | Short retention | Centralized long-term Loki | [Ch 34](../part-v-infrastructure/34-logging.md) |
| Secrets | Lab ESO setup | Rotated SM secrets, scoped IAM | [Ch 32](../part-v-infrastructure/32-secrets-management.md) |
| Capabilities | Ski-trip tools | Your domain tools via registry | [Ch 43](43-extending-hermes.md) |

The software evolves slowly. **Reliability, security, and recoverability** evolve dramatically.

---

## CI/CD as Source of Truth

Every change should begin the same way ([Chapter 31](../part-v-infrastructure/31-github-actions.md)):

```text
Developer
    │
Git commit
    │
Pull request + review
    │
Merge to main
    │
GitHub Actions
    │
terraform plan / apply
    │
helm upgrade
    │
Production cluster
```

**The production cluster should never be changed manually.** `kubectl edit` on a live Deployment is a regression to heroics. Declarative infrastructure—Terraform state, Helm values in Git, synced secrets—is the **authoritative source**.

You already proved this pattern:

- Network: Terraform module ([Ch 30](../part-v-infrastructure/30-terraform.md))
- Workloads: `hermes-lab` Helm chart ([Ch 35](../part-vi-ai/35-running-hermes.md))
- Observability: monitoring/logging Helm releases ([Ch 33–34](../part-v-infrastructure/33-monitoring.md))
- Rollouts: `values-production-rollout.yaml` ([Ch 41](41-operating-hermes-in-production.md))

Production is **the same pipelines**, stricter gates.

---

## Environment Promotion

Avoid separate application code per environment. **Promote the same artifacts.** Configuration differs; logic does not.

```text
Development  →  Staging  →  Production
(same images, same charts, different values)
```

Reference: [`environment-promotion.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/environment-promotion.example.yaml)

```yaml
production:
  helm_values:
    - values.yaml
    - values-with-llama.yaml
    - values-production-rollout.yaml
```

| Layer | What varies | What stays identical |
|-------|-------------|----------------------|
| Terraform | `environments/dev` vs `prod` variables | Same modules |
| Helm | `-f` values chain | Same chart templates |
| Hermes | Tool registry + policy ConfigMaps | Same worker loop |
| Container images | Tags promoted through registry | Same Dockerfile/build |

Staging exists to **break things safely**—run the readiness checklist, synthetic traffic, and rollback drills before real users arrive.

---

## High Availability

Development tolerated failure. Production **assumes** failure and continues anyway ([Chapter 41](41-operating-hermes-in-production.md)).

Increase resilience by distributing critical workloads:

| Workload | HA mechanism | Already in book |
|----------|--------------|-----------------|
| Hermes API | ≥3 replicas, `maxUnavailable: 0` | `values-production-rollout.yaml` |
| Workers | Multiple replicas + Redis locks | [Ch 39](../part-vi-ai/39-ai-agent-architecture.md) |
| Ingress | Traefik on k3s; multi-node for prod | [Ch 24](../part-iv-kubernetes/24-ingress.md) |
| Databases | Backups + restore drills; managed HA when ready | [Ch 41](41-operating-hermes-in-production.md) |
| AZ spread | Terraform subnets across AZs | [Ch 8](../part-ii-aws/08-creating-network-for-hermes.md) |

The goal is not to eliminate failures. The goal is to **continue operating despite them**—durable tasks survive worker crashes; rollouts replace Pods incrementally; backups make data loss a procedure, not a catastrophe.

---

## Scaling Strategy

Scale **independently**. Each subsystem has different saturation signals ([Chapter 29](../part-iv-kubernetes/29-scaling.md)):

```text
Ingress traffic  →  scale hermes-api (HPA on CPU/latency)
Task backlog     →  scale hermes-workers (queue depth)
Inference queue  →  scale llama-server replicas or GPU pool
Vector queries   →  scale Qdrant resources or shard collections
```

Do not scale the entire platform because one component is hot. Measure, then scale the bottleneck—exactly as [Chapter 40](40-distributed-cognitive-execution.md) scales `agent_role=weather` workers independently from summary agents.

---

## Operational Readiness Checklist

Before exposing Hermes to real users, verify with **evidence**:

[`production-readiness.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/production-readiness.example.yaml)

| Area | Must be true |
|------|--------------|
| Infrastructure | Recreatable from Terraform |
| CI/CD | GitHub Actions deploys without manual kubectl |
| Secrets | AWS SM + ESO; not in Git |
| Operations | Zero-downtime rollout + rollback tested |
| Backups | Restore drill completed |
| Observability | Dashboards, SLOs ([`slo.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/slo.example.yaml)), alerts fired in drill |
| Logging | Structured worker logs in Loki |
| Security | Tool policy default-deny; audit reconstructable |
| Extensions | At least one capability added via Ch 43 checklist |
| Cost | Budgets or review cadence ([Ch 16](../part-ii-aws/16-managing-platform-costs.md)) |

Production readiness is **demonstrated**, not declared. Sign the checklist when you have artifacts—not when you feel ready.

---

## Cost Optimization

Production runs continuously. Optimize from **measurements** ([Chapter 16](../part-ii-aws/16-managing-platform-costs.md), [Chapter 41](41-operating-hermes-in-production.md)):

| Lever | Action |
|-------|--------|
| Workers | HPA on queue depth—not fixed over-provisioning |
| GPU | Schedule GPU nodes for inference bursts ([Ch 38](../part-vi-ai/38-gpu-instances.md)) |
| Logs | Retention bounds in Loki ([Ch 34](../part-v-infrastructure/34-logging.md)) |
| Vectors | Expire unused Qdrant collections ([Ch 36](../part-vi-ai/36-vector-databases.md)) |
| Compute | Right-size EC2; consider Reserved Instances for steady state |
| Models | CPU path for light tasks; GPU only when latency requires |

Cost optimization must not sacrifice the readiness items above—cheap platforms that lose data are not production.

---

## A Day in the Life of Hermes

Imagine a typical production day. Nothing heroic—**that is the goal**.

```text
1. User submits request via Ingress (Ch 24)
2. API creates task in PostgreSQL (Ch 39)
3. Worker claims task via Redis lock
4. Qdrant retrieves semantic context (Ch 36)
5. llama-server completes inference (Ch 37)
6. Tool gateway authorizes and executes external call (Ch 42–43)
7. Step persisted to hermes_task_steps
8. Prometheus records latency (Ch 33)
9. Structured log line ships to Loki (Ch 34)
10. Alerts remain silent
11. Response returns to user
```

Reliable systems make complex work appear **ordinary**. If operators only notice the platform when it fails, the design is working on successful days.

---

## Production Is a Process

Launching Hermes is not the finish line. Production systems evolve:

- New capabilities ([Chapter 43](43-extending-hermes.md))
- Model upgrades with parallel validation ([Chapter 41](41-operating-hermes-in-production.md))
- Security policy updates ([Chapter 42](42-platform-governance.md))
- Coordinator workflows ([Chapter 40](40-distributed-cognitive-execution.md))

The platform you built is **designed for that evolution**. Git → Actions → Terraform → Helm is not bureaucracy—it is how you change production safely.

---

## End-to-End Platform

This is no longer a collection of technologies. It is **one operational platform**:

```text
Developer
      │
Git
      │
GitHub Actions          (Ch 31)
      │
Terraform             (Ch 30)
      │
AWS VPC + EC2         (Ch 7–8)
      │
Kubernetes / k3s      (Ch 13–29)
      │
Ingress               (Ch 24)
      │
Hermes API            (Ch 35)
      │
Workers + reasoning loop (Ch 39)
      │
Redis │ PostgreSQL │ Qdrant
      │
Model Server          (Ch 37–38)
      │
Tools + capabilities  (Ch 42–43)
      │
Monitoring / Logging  (Ch 33–34)
      │
Response
```

You can draw this diagram from memory because **you built every arrow**.

---

## Production Readiness Assessment

Ask yourself honestly:

| Question | Evidence if "yes" |
|----------|-------------------|
| Can infrastructure be recreated from source? | `terraform apply` from Git |
| Can deployments run without downtime? | Rolling rollout lab passed |
| Can failures be detected automatically? | Alert fired and acknowledged |
| Can backups be restored? | Restore drill log |
| Can secrets be rotated? | ESO refresh + SM rotation |
| Can new capabilities be added safely? | Extension checklist complete |
| Can operators explain every major action? | `hermes_task_steps` + trace |

If every answer is **yes**, you have built more than an application.

**You have built a platform—and you could actually run it.**

---

## Hands-on Lab

### Lab 43: Production Readiness Review

**Estimated Time:** 30 minutes

**Goal:** Complete `production-readiness.example.yaml` with evidence from your lab—not checkboxes alone.

**Steps:**

1. Open `production-readiness.example.yaml`
2. For each `required: true` item, write the evidence (command output, screenshot path, or date)
3. Identify the **three weakest** items—plan remediation before any real traffic
4. Walk through "A Day in the Life" and name the Pod/Service for each step in *your* cluster
5. Draft `environment-promotion.example.yaml` notes for how staging would differ from your current lab
6. Sign the `sign_off` block when satisfied—or leave blank and know what remains

---

## Verification

- [ ] You can narrate the arc from laptop → Git → production without new concepts
- [ ] You can explain what changes between dev and prod (guarantees, not app logic)
- [ ] You completed readiness assessment with evidence for required items
- [ ] You can name independent scaling targets for API, workers, and inference
- [ ] You recognize "ordinary success" as the production goal

---

## Review Questions

1. Why has Hermes architecture stayed stable while the environment matured?
2. Why should production clusters not be changed manually?
3. What is the difference between staging and production if images are identical?
4. Why scale subsystems independently?
5. What does "I could actually run this" mean in terms of evidence?

---

## Key Takeaways

- **Chapter 44 is the payoff**—the first time the whole system feels real
- **Production extends architecture through operational discipline**, not rewrites
- **Declarative infrastructure** (Terraform, Helm, Git) enables repeatability
- **High availability** comes from redundancy and durable state—not perfection
- **The transition is evolutionary**: same Hermes, higher standard
- **Reliable systems feel boring on success days**—that is the compliment

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Environment promotion** | Moving identical artifacts through dev → staging → prod with different config. |
| **Production readiness** | Demonstrated evidence that operational guarantees hold—not a feeling. |
| **Source of truth** | Git + declarative config; not live cluster state. |

---

## Further Reading

- [Chapter 41: Operating Hermes in Production](41-operating-hermes-in-production.md)
- [Chapter 31: GitHub Actions](../part-v-infrastructure/31-github-actions.md)
- [Chapter 30: Terraform](../part-v-infrastructure/30-terraform.md)
- [`production-readiness.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/production-readiness.example.yaml)
- [`environment-promotion.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/hermes/environment-promotion.example.yaml)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Platform built (Ch 1–42)           ✓
Production operating model (Ch 44) ✓

Retrospective (Ch 45)              ◐
───────────────────────────────────────────────
```

```text
"I could actually run this."
```

You did not just learn cloud and AI. You built a **personal cognitive platform** worthy of production.

---

## What's Next

[Chapter 45: The Platform You Built](45-the-platform-you-built.md) — step back from implementation. Revisit the journey from the first Linux process to the distributed cognitive system running in AWS. Understand what you built—and why each layer matters.

No new commands. No new YAML. **Understanding.**

---

[← Chapter 43: Extending Hermes](43-extending-hermes.md) | [Next: Chapter 45 — The Platform You Built →](45-the-platform-you-built.md)
