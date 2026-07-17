---
sidebar_position: 37
description: "Local inference — llama.cpp as a cluster-native reasoning layer for Hermes."
---

# Chapter 37: Model Serving

> A system without a model executes logic.
>
> A system with a model executes cognition.

---

[Chapter 36](36-vector-databases.md) added **semantic memory** (Qdrant). [Chapter 35](35-running-hermes.md) deployed execution layers—but the model stub was not real inference.

Gap:

> **No native reasoning engine inside the system**

This chapter replaces the stub with **llama.cpp** as infrastructure: inference as a cluster-internal service Hermes workers call—not an external API assumption.

```text
Before:  Hermes orchestrates intelligence (external or implied)
After:   Hermes contains intelligence (local llama-server)
```

Aligned with [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md): **Hermes and llama.cpp are separate services**—orchestration vs inference runtime.

:::note[Phase shift]

| Chapter | Capability |
|---------|------------|
| Ch 35 | System **executes** |
| Ch 36 | System **remembers** (meaning) |
| Ch 37 | System **reasons** (local inference) |

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Deploy llama.cpp server as a Kubernetes workload in `hermes`
- [ ] Mount GGUF models from the node `/models` path ([Chapter 11](../part-ii-aws/11-persistent-storage.md))
- [ ] Expose inference via internal Service only (no Ingress)
- [ ] Wire workers to `http://llama-server:8080/completion`
- [ ] Explain CPU-only latency, memory, and concurrency constraints on k3s
- [ ] Distinguish model **serving** (infra) from model **usage** (application prompts)

---

## Prerequisites

- [Chapter 35](35-running-hermes.md) — `hermes-lab` running
- [Chapter 11](../part-ii-aws/11-persistent-storage.md) — `/models` on `hermes-models` EBS
- GGUF file available on the k3s node (small Q4 model recommended for CPU lab)
- Helm ([Chapter 26](../part-iv-kubernetes/26-helm.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n hermes
# On EC2 node via SSH:
ls -lh /models/model.gguf || ./code/infrastructure/aws/cli/ch37-prepare-model-lab.sh
```

---

## Estimated Time

**120 minutes** — 30 minutes reading, 90 minutes model prep + deploy + first completion (model load is slow on CPU).

---

## Background

### The Problem

Hermes today has:

| Layer | Status |
|-------|--------|
| Structured state (Postgres) | ✓ |
| Coordination (Redis) | ✓ |
| Semantic memory (Qdrant) | ✓ |
| Workers | ✓ |
| **Local inference** | ✗ |

Workers orchestrate but do not **generate cognition** until a model server exists inside the cluster.

### Model Serving vs Model Usage

| Concept | Meaning |
|---------|---------|
| **Model usage** | Calling OpenAI/Anthropic APIs from app code |
| **Model serving** | Running inference as **infrastructure** in your cluster |

We implement:

> **Inference as a first-class infrastructure component**

Hermes API and workers **use** the model Service; they do not embed the GGUF file.

### Why llama.cpp, Not Ollama?

**Ollama** is excellent for local experimentation—it downloads models, runs a daemon, and exposes a simple API. This book does **not** use it.

We deploy **llama.cpp** directly as `llama-server` because the learning goal is **production-shaped inference on Kubernetes**:

| Requirement | llama.cpp path | Why not Ollama alone |
|-------------|----------------|----------------------|
| Explicit GGUF on `/models` | You place files on EBS ([Ch 11](../part-ii-aws/11-persistent-storage.md)) | Ollama manages its own model store |
| Helm + Deployment + Service | `code/infrastructure/helm/llama-server/` | Extra abstraction layer around the runtime |
| Cluster-internal HTTP only | `ClusterIP`, no Ingress to model | Same possible, but less transparent in labs |
| CPU/GPU resource limits | `resources` + device plugin ([Ch 38](38-gpu-instances.md)) | Harder to reason about in ops chapters |
| Swap models like infra | Symlink `model.gguf`, rolling restart | `ollama pull` hides file layout |

Hermes workers call a stable HTTP contract—`POST /completion`—whether the backend is llama.cpp today or another engine tomorrow. **The book teaches you to operate that contract on your platform**, not a desktop tool.

:::note

You may use Ollama on your laptop for casual testing. Everything in Parts VI–VII assumes **llama-server** inside the `hermes` namespace.

:::

### Architecture Update

```text
                ┌──────────────┐
                │  Hermes API  │
                └──────┬───────┘
                       ↓
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
   PostgreSQL      Redis         Qdrant
        └──────────────┼──────────────┘
                       ↓
                ┌──────────────┐
                │ llama-server │  ClusterIP only
                └──────┬───────┘
                       ↓
              /models/model.gguf (hostPath)
```

---

## Walkthrough

### Step 1 — Prepare Model on Node

llama.cpp reads GGUF from disk at pod start—**cold load is real latency**.

On the control plane EC2 (SSH):

```bash
chmod +x code/infrastructure/aws/cli/ch37-prepare-model-lab.sh
./code/infrastructure/aws/cli/ch37-prepare-model-lab.sh

# Example: point at an existing GGUF under /models/
sudo ln -sf /models/qwen/your-lab-model.Q4_K_M.gguf /models/model.gguf
./code/infrastructure/aws/cli/ch37-prepare-model-lab.sh --check
```

This path maps to **hermes-models** EBS— the physical substrate of reasoning.

### Step 2 — Deploy llama-server

```bash
helm upgrade --install llama-server code/infrastructure/helm/llama-server \
  -n hermes \
  -f code/infrastructure/helm/llama-server/values.yaml
```

Chart highlights (`code/infrastructure/helm/llama-server/`):

```yaml
args:
  - "-m"
  - "/models/model.gguf"
  - "--host"
  - "0.0.0.0"
  - "--port"
  - "8080"
volumeMounts:
  - mountPath: /models
    hostPath: /models   # node path from Ch 11
```

Wait for readiness (model load may take 1–3 minutes on CPU):

```bash
kubectl get pods -n hermes -l app=llama-server -w
```

### Step 3 — Internal Service

```bash
kubectl get svc llama-server -n hermes
```

| Property | Value |
|----------|-------|
| DNS | `llama-server.hermes.svc` |
| Port | 8080 |
| Exposure | **ClusterIP** — not on Ingress |

Inference stays **inside the trust boundary**—only Hermes components call it.

### Step 4 — Disable Model Stub; Rewire hermes-lab

```bash
helm upgrade hermes-lab code/infrastructure/helm/hermes-lab -n hermes \
  -f code/infrastructure/helm/hermes-lab/values.yaml \
  -f code/infrastructure/helm/hermes-lab/values-with-llama.yaml
```

This sets `model.enabled: false`, `model.host: llama-server`, and worker env `LLAMA_SERVER_URL`.

Verify API Pod env:

```bash
kubectl exec -n hermes deploy/hermes-api -- env | grep -E 'MODEL_|LLAMA'
```

### Step 5 — First Completion (Inference Proof)

```bash
chmod +x code/infrastructure/aws/cli/ch37-verify-llama-inference.sh
./code/infrastructure/aws/cli/ch37-verify-llama-inference.sh
```

Or from a worker Pod:

```bash
kubectl exec -n hermes deploy/hermes-workers -- \
  wget -qO- --post-data='{"prompt":"Hello","n_predict":32,"stream":false}' \
  --header='Content-Type: application/json' \
  http://llama-server:8080/completion | head -c 500
```

Flow:

```text
Worker → POST /completion → llama-server → token generation → JSON response
```

### Step 6 — Streaming (Concept)

Enable streaming for responsive UX:

```json
{"prompt": "...", "stream": true}
```

Server emits partial tokens; clients must handle **backpressure**—slow consumers stall generation. Hermes API will stream to users in Part VII; here you verify the endpoint supports it.

### Step 7 — Connect to RAG (Ch 36 Bridge)

Full agent loop (later):

```text
Query → Qdrant retrieval → prompt assembly → llama-server → response → embed → Qdrant upsert
```

Model serving provides the **generation** step; Qdrant provides **context**.

### Step 8 — Observability

**Metrics** — watch Pod memory during inference ([Chapter 33](../part-v-infrastructure/33-monitoring.md)):

- `container_memory_working_set_bytes{namespace="hermes",pod=~"llama-server.*"}`

**Logs** — llama.cpp server logs load time and requests ([Chapter 34](../part-v-infrastructure/34-logging.md)):

```logql
{namespace="hermes", app="llama-server"}
```

Latency becomes a **design constraint** you can measure—not guess.

---

## Hands-on Lab

### Lab 36: Local Inference

**Estimated Time:** 90 minutes

**Goal:** llama-server Running; `/completion` returns generated text; workers reference `LLAMA_SERVER_URL`.

**Steps:**

1. Place or symlink GGUF at `/models/model.gguf` on node
2. `helm install llama-server ...`
3. Wait for readiness probe `/health`
4. Run `ch37-verify-llama-inference.sh`
5. Upgrade hermes-lab with `values-with-llama.yaml`
6. Confirm worker logs include `llama` URL field
7. Record cold-start time and first-token latency in notes

---

## Verification

- [ ] `/models/model.gguf` exists on EC2 node
- [ ] `llama-server` Pod Running and ready
- [ ] `/completion` returns content JSON
- [ ] `hermes-model` stub scaled away (`model.enabled: false`)
- [ ] Workers have `LLAMA_SERVER_URL=http://llama-server:8080`
- [ ] Inference not exposed via Ingress
- [ ] You can explain serving vs usage

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| CrashLoop on start | Missing GGUF | `--check` script on node; verify hostPath |
| OOMKilled | Model too large for RAM | Smaller quant (Q4); raise limits; smaller model |
| Readiness never passes | Slow CPU load | Increase `initialDelaySeconds`; wait longer |
| Empty completion | Wrong API path | Use POST `/completion` with JSON body |
| Permission denied on /models | Mount read-only / ownership | `sudo chmod o+r` or fix ownership on GGUF |
| Workers cannot reach server | DNS / namespace | Same namespace `hermes`; use `llama-server:8080` |

### Failure Modes

**Cold start latency** — First request after Pod restart pays full GGUF load. Fix: keep Pod warm; use `minReplicas: 1`; preload on node.

**Memory exhaustion** — Concurrent requests exceed RAM. Fix: `-np 1` parallel slots; queue at worker layer; GPU path ([Chapter 38](38-gpu-instances.md)).

**Queue saturation** — Workers outpace inference. Fix: backpressure in Redis queue; scale model tier (GPU) not infinite workers.

**Streaming backpressure** — Slow HTTP client blocks generation. Fix: timeouts; buffered streams; separate worker consumer.

---

## k3s Reality Constraints

| Constraint | Impact |
|------------|--------|
| CPU-only | Low tokens/sec; long responses |
| Single node | Model + Hermes + observability share RAM |
| No GPU (until Ch 38) | Small models only |
| Disk IO | Large GGUF slow to mmap on first load |

This is a **bounded cognition environment**—honest for learning, not datacenter LLM serving.

---

## Review Questions

1. Why is llama.cpp a separate Deployment from Hermes API?
2. Why hostPath `/models` instead of baking GGUF into the image?
3. Why ClusterIP only for llama-server?
4. What happens to workers if inference is slower than task arrival rate?
5. How does Ch 37 change the Hermes system type?

---

## Key Takeaways

- **Model serving is infrastructure**, not application logic
- **llama.cpp** runs inference inside k3s; Hermes **uses** it via HTTP
- **GGUF on `/models`** ties inference to [Chapter 11](../part-ii-aws/11-persistent-storage.md) storage design
- **Workers depend on internal reasoning runtime** — cognition is in-cluster
- **Latency and memory** are system design constraints on single-node CPU
- System evolution: **Execution → Memory → Reasoning**

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **GGUF** | File format for quantized LLM weights used by llama.cpp. |
| **Model serving** | Hosting inference as a network service in infrastructure. |
| **Completion** | llama.cpp HTTP API for text generation from a prompt. |
| **Cold start** | Latency to load model weights on first Pod start or request. |
| **hostPath** | Kubernetes volume mapping a path on the node into a Pod. |

---

## Further Reading

- [llama.cpp server documentation](https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md)
- [Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md)
- [Chapter 35: Running Hermes](35-running-hermes.md)
- [Chapter 36: Vector Databases](36-vector-databases.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Execution + memory       ✓
llama-server (local)     ✓
GPU inference            ◐ (Ch 38)
Full agent loop          ◐ (Part VII)

Hermes production image  ◐
───────────────────────────────────────────────
```

```text
Execution → Memory → Reasoning
```

---

## What's Next

[Chapter 38: GPU Instances](38-gpu-instances.md) — when CPU inference is insufficient; GPU nodes and model serving at scale.

[Chapter 39: The Hermes Reasoning Loop](39-ai-agent-architecture.md) — platform-owned task loop; memory + inference + tools.

---

[← Chapter 36: Vector Databases](36-vector-databases.md) | [Next: Chapter 38 — GPU Instances →](38-gpu-instances.md)
