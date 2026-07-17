---
sidebar_position: 35
description: "First Hermes system instantiation — deploy the coordinated execution stack on k3s."
---

# Chapter 35: Running Hermes

> Everything so far has been preparation.
>
> This is the first time the system becomes real.

---

Parts I–V built the **substrate**: AWS, k3s, Kubernetes platform, CI, secrets, scaling, monitoring, logging.

Part VI begins **system instantiation**—deploying Hermes as a **coordinated execution system**, not a single Pod or image.

```text
Before:  platform runs demo workloads (nginx, config-demo)
After:   Hermes namespace — API + workers + model + memory + queue — alive as one organism
```

This chapter is **not** architecture design—that was [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md). This is the first **end-to-end deployment** on everything you built.

:::note[Lab honesty]

The repo ships `hermes-lab` with **stub images** that wire the same topology as production Hermes. Real Hermes API and llama.cpp replace stubs in later chapters ([Chapter 37](37-model-serving.md), Part VII). The lesson is **system assembly and verification**, not a specific container tag.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Deploy Hermes as cooperating Kubernetes workloads in namespace `hermes`
- [ ] Explain each layer: API, workers, model, queue, memory
- [ ] Wire Service and Ingress for external access via Traefik
- [ ] Validate end-to-end request flow through Ingress
- [ ] Verify observability signals (metrics, logs) for Hermes components
- [ ] Distinguish **system correctness** (components interact) from **system completeness** (full agent intelligence)
- [ ] Recognize **emergent behavior** from component interactions

---

## Prerequisites

- Part V complete ([Chapters 29–33](../part-v-infrastructure/30-terraform.md))
- k3s + Traefik Ingress ([Chapter 13](../part-ii-aws/13-the-first-control-plane.md), [Chapter 24](../part-iv-kubernetes/24-ingress.md))
- PVC storage class `local-path` ([Chapter 25](../part-iv-kubernetes/25-kubernetes-storage.md))
- Helm ([Chapter 26](../part-iv-kubernetes/26-helm.md))
- Recommended: monitoring + logging ([Chapters 33–34](../part-v-infrastructure/33-monitoring.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
helm version
```

---

## Estimated Time

**120 minutes** — 35 minutes reading, 85 minutes deploy + verify + observability walkthrough.

---

## Background

### What Hermes Actually Is

Hermes is not a service. It is a **distributed execution system**:

| Component | Responsibility | Kubernetes object |
|-----------|----------------|-------------------|
| **API layer** | Receives requests | `Deployment` + `Service` + `Ingress` |
| **Worker layer** | Executes tasks (consumes queue) | `Deployment` (stateless) |
| **Model layer** | Inference (isolated, no direct external access) | `Deployment` + internal `Service` |
| **Tool layer** | External integrations | MCP / HTTP clients (Part VII) |
| **Memory layer** | Durable state | PostgreSQL + PVC |
| **Queue layer** | Async work | Redis |

Each piece is independent. Together they form a system—aligned with [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md):

```text
Hermes API  ← orchestration
     ├── llama.cpp / model service  ← inference (separate)
     ├── PostgreSQL                 ← durable state
     ├── Redis                      ← queue / cache
     └── tools (later)              ← MCP, external APIs
```

### Deployment as Instantiation

Until now you **configured** the platform. Now you **instantiate** a system:

> Deployment is not "apply YAML." It is bringing a coordinated organism online.

**Correctness** (this chapter): components start, discover each other, accept traffic, emit observability signals.

**Completeness** (later chapters): real inference, agent logic, tool chains, production hardening.

### Phase Transition

```text
Part I–V:  systems that run workloads
Part VI+:  a workload that defines a system
```

Infrastructure is no longer the focus—**system behavior** is.

---

## Architecture

### System Diagram

```text
                ┌──────────────┐
                │   Ingress    │  hermes.local (Traefik)
                └──────┬───────┘
                       ↓
                ┌──────────────┐
                │  Hermes API  │  :8080 → Service :80
                └──────┬───────┘
           ┌───────────┼───────────┐
           ↓           ↓           ↓
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Workers  │ │  Model   │ │  Redis   │
   │ (queue)  │ │ (internal)│ │ (queue)  │
   └────┬─────┘ └──────────┘ └──────────┘
        ↓
   ┌──────────┐
   │ Postgres │  PVC (local-path)
   │ (memory) │
   └──────────┘
```

### Request Flow (Target State)

```text
User request
   ↓
Ingress (Traefik)
   ↓
Hermes API
   ↓
Worker queue (Redis) — async path
   ↓
Model execution (internal Service)
   ↓
Tool call (future)
   ↓
Response assembly
   ↓
User
```

Lab stubs echo HTTP at the API layer; workers emit structured heartbeats to Redis; model is reachable only inside the cluster.

### Full Stack Context

```text
Terraform → GitHub Actions → AWS → Secrets → k3s → Kubernetes
        → Monitoring + Logging → Hermes (RUNNING)
```

---

## Walkthrough

### Step 1 — Create Namespace

Isolate Hermes from platform demos:

```bash
kubectl create namespace hermes
```

All Hermes workloads live here—RBAC and NetworkPolicy can scope to `namespace: hermes` ([Chapter 28](../part-iv-kubernetes/28-kubernetes-security.md)).

### Step 2 — Deploy the Lab Stack

The repo packages the full topology in `code/infrastructure/helm/hermes-lab/`:

```bash
helm upgrade --install hermes-lab code/infrastructure/helm/hermes-lab \
  -n hermes \
  -f code/infrastructure/helm/hermes-lab/values.yaml
```

Watch rollout:

```bash
kubectl get pods -n hermes -w
```

Expected workloads:

| Pod prefix | Role |
|------------|------|
| `hermes-api` | API (2 replicas) |
| `hermes-workers` | Workers (2 replicas) |
| `hermes-model` | Model stub (1 replica, internal) |
| `hermes-redis` | Queue |
| `hermes-postgres` | Memory (PVC) |

### Step 3 — Inspect Core API Deployment

The chart deploys API Pods with environment wiring to sibling services:

```yaml
env:
  - name: REDIS_HOST
    value: hermes-redis
  - name: POSTGRES_HOST
    value: hermes-postgres
  - name: MODEL_HOST
    value: hermes-model
```

Production Hermes uses the same **service discovery pattern**—Kubernetes DNS names, not hardcoded IPs.

### Step 4 — Worker System

Workers are **stateless executors**:

> They consume tasks, not HTTP requests from users.

Lab workers ping Redis and log JSON:

```json
{"level":"info","event":"worker_tick","component":"worker","redis":"PONG"}
```

Scale independently from API:

```bash
kubectl scale deployment/hermes-workers -n hermes --replicas=3
```

### Step 5 — Model Layer

Model Pods:

- Run behind internal `ClusterIP` only (`hermes-model:8080`)
- No Ingress route—API orchestrates calls
- Scale independently when GPU/CPU inference arrives ([Chapter 37](37-model-serving.md))

Verify internal reachability from an API Pod:

```bash
kubectl exec -n hermes deploy/hermes-api -- wget -qO- http://hermes-model:8080/ 2>/dev/null | head
```

### Step 6 — Service Wiring

```bash
kubectl get svc -n hermes
```

| Service | Type | Purpose |
|---------|------|---------|
| `hermes-api` | ClusterIP | API front door inside cluster |
| `hermes-model` | ClusterIP | Inference (internal) |
| `hermes-redis` | ClusterIP | Queue |
| `hermes-postgres` | ClusterIP | Database |

### Step 7 — Ingress Exposure

Chart creates Traefik Ingress for `hermes.local` ([Chapter 24](../part-iv-kubernetes/24-ingress.md) pattern):

```bash
kubectl get ingress -n hermes
```

Resolve node IP from Part II notes, then:

```bash
export NODE_IP=<your-controlplane-public-ip>
curl -s -H "Host: hermes.local" "http://${NODE_IP}/" | head -20
```

```text
http://hermes.local → Ingress → hermes-api → system
```

### Step 8 — First End-to-End Verification

Checklist:

- [ ] All Pods `Running` in `hermes`
- [ ] `curl` through Ingress returns HTTP 200
- [ ] Workers log `worker_tick` with `redis: PONG`
- [ ] PostgreSQL PVC bound (`hermes-postgres-data`)
- [ ] Model reachable from API Pod, not from Ingress path alone

```bash
kubectl logs -n hermes -l app.kubernetes.io/component=worker --tail=5
kubectl get pvc -n hermes
```

**The system is alive** when components interact dynamically—not when YAML applied successfully.

### Step 9 — Observability Verification

Use Part V stacks to confirm behavior, not just Pod status.

**Metrics** ([Chapter 33](../part-v-infrastructure/33-monitoring.md)):

- Grafana → Pod CPU/memory for `namespace="hermes"`
- kube-state-metrics → replica counts for API and workers

**Logs** ([Chapter 34](../part-v-infrastructure/34-logging.md)):

```logql
{namespace="hermes"} | json | event="worker_tick"
```

**Traces** — full OTLP wiring comes with production Hermes; correlate by `trace_id` in logs when available.

| Signal | Question |
|--------|----------|
| Metrics | Is the node saturated during load? |
| Logs | Are workers processing? Any errors? |
| Traces | Which span failed? (Part VI+) |

### Step 10 — Optional External Secrets

Wire API keys via [Chapter 32](../part-v-infrastructure/32-secrets-management.md) `ExternalSecret` into `hermes` namespace before production Hermes lands—same pattern as `app-secret`, scoped to `hermes/*` in Secrets Manager.

---

## Hands-on Lab

### Lab 34: System Instantiation

**Estimated Time:** 85 minutes

**Goal:** Hermes lab stack running; Ingress curl succeeds; logs visible in Loki.

**Steps:**

1. Create namespace `hermes`
2. `helm upgrade --install hermes-lab ...`
3. Wait for all Pods Running
4. Curl via Ingress with `Host: hermes.local`
5. Confirm worker JSON logs in `kubectl logs`
6. Query Loki: `{namespace="hermes"}`
7. Scale workers to 3; observe replica count in Grafana
8. Document node IP + hostname in `~/hermes-platform/notes/hermes-lab.md`

---

## Verification

- [ ] `kubectl get pods -n hermes` — all Running
- [ ] Ingress returns 200 via curl
- [ ] Workers emit structured logs with Redis PONG
- [ ] Postgres PVC bound
- [ ] Model service internal-only
- [ ] Logs queryable in Grafana/Loki
- [ ] You can draw the request flow from Ingress to model

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pods Pending | Insufficient CPU/RAM on single node | Lower replicas in `values.yaml`; check `kubectl describe pod` |
| Ingress 404 | Wrong Host header | Use `-H "Host: hermes.local"` |
| Postgres CrashLoop | PVC mount permissions | Check `subPath: pgdata` in chart; delete PVC and retry |
| Workers redis FAIL | Redis not ready | Wait for `hermes-redis` Running |
| No logs in Loki | Promtail lag / wrong namespace | Query `{namespace="hermes"}` with wide time range |
| ImagePullBackOff | Registry unreachable | Verify node egress; use cached public images |

### Failure Modes

**Worker starvation** — API accepts traffic but queue depth grows; workers underscaled. Fix: scale workers; later HPA on queue depth ([Chapter 29](../part-iv-kubernetes/29-scaling.md), Ch 33 custom metrics).

**Model bottleneck** — Inference latency spikes; worker backlog grows. Fix: scale model tier or GPU ([Chapter 37](37-model-serving.md)).

**Tool failure cascade** — External API failures cause retries that amplify load. Fix: circuit breakers, timeouts (Part VII).

**Memory inconsistency** — Multiple API Pods without shared DB state. Fix: PostgreSQL as source of truth; sticky sessions only if required.

---

## Review Questions

1. Why is Hermes a system, not a single Deployment?
2. Why is the model Service internal-only?
3. What is the difference between correctness and completeness in this chapter?
4. How do workers differ from the API layer?
5. What does "emergent behavior" mean for Hermes?

---

## Key Takeaways

- **First system instantiation** — Hermes runs as cooperating workloads, not one container
- **API / workers / model / Redis / Postgres** mirror [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md) design
- **Ingress → Service → Pods** completes the external path
- **Running = alive** — dynamic interaction, not static YAML
- **Observability validates behavior** — metrics + logs confirm the system, not just Pod phase
- **Emergent behavior** — no single component defines system behavior; interactions do
- Infrastructure phase ends; **system behavior phase** begins

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **System instantiation** | Deploying all cooperating components so the platform executes as one system. |
| **Emergent behavior** | System outcomes arising from component interactions, not one module. |
| **Correctness** | Components wired and interacting (this chapter). |
| **Completeness** | Full agent intelligence, inference, tools (later chapters). |

---

## Further Reading

- [Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md)
- [Chapter 37: Model Serving](37-model-serving.md)
- [`code/infrastructure/helm/hermes-lab/README.md`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/helm/hermes-lab/README.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Platform substrate       ✓
Observability            ✓

Hermes lab stack         ✓ (stubs)
Real Hermes API          ◐ (Part VI/VII)
llama.cpp inference      ◐ (Ch 37)
Tool integrations        ◐ (Part VII)

End-to-end agent         ◐
───────────────────────────────────────────────
```

**Hermes is RUNNING** as a coordinated lab system.

---

## What's Next

[Chapter 36: Vector Databases](36-vector-databases.md) — vector storage for retrieval and memory workloads that Hermes will use.

[Chapter 37: Model Serving](37-model-serving.md) replaces the model stub with llama.cpp.

---

[← Chapter 34: Logging & Tracing](../part-v-infrastructure/34-logging.md) | [Next: Chapter 36 — Vector Databases →](36-vector-databases.md)
