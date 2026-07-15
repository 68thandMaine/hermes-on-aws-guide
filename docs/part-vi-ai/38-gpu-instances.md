---
sidebar_position: 38
description: "GPU acceleration — heterogeneous compute for Hermes inference on AWS."
---

# Chapter 38: GPU Instances

> A system's intelligence is bounded by its slowest layer of computation.

---

[Chapter 37](37-model-serving.md) brought **local reasoning** via llama.cpp on CPU. That works for learning—it is not enough for interactive agent loops at scale.

Constraint:

> **If reasoning exists locally, hardware becomes the limiting factor—not architecture**

This chapter introduces **acceleration as a system layer**: GPU instances as a distinct tensor compute substrate, scheduled by Kubernetes alongside CPU inference.

```text
Before:  cognition = CPU-bound simulation (slow tokens, low concurrency)
After:   heterogeneous stack — CPU baseline + GPU accelerated path
```

No new mental model—GPUs are another **execution substrate** in State Layers, like choosing a node pool for memory-heavy vs compute-heavy work.

:::note[Optional but architecturally important]

You can complete the book on CPU-only. This chapter documents the **production path** when agent latency and concurrency matter—and when cost becomes a first-class design constraint.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain GPUs as a compute substrate, not a "performance tweak"
- [ ] Provision a GPU EC2 instance and join it to k3s with labels
- [ ] Install the NVIDIA device plugin and verify `nvidia.com/gpu` allocatable
- [ ] Deploy CUDA llama.cpp (`llama-server-gpu`) with GPU resource limits
- [ ] Compare CPU vs GPU inference latency and cost tradeoffs
- [ ] Wire dual-path inference URLs for Hermes workers
- [ ] Identify GPU scheduling and utilization failure modes

---

## Prerequisites

- [Chapter 37](37-model-serving.md) — CPU `llama-server` working
- [Chapter 8](../part-ii-aws/08-creating-network-for-hermes.md) — VPC for GPU instance in same network
- AWS account with **GPU instance quota** (g5 family)
- Willingness to incur GPU hourly cost during lab (stop instance when done)

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
```

---

## Estimated Time

**120 minutes** — 40 minutes reading, 80 minutes GPU node + plugin + deploy (excluding AWS quota approval wait).

---

## Background

### The Problem

Hermes today:

| Capability | Status |
|------------|--------|
| Execute (Ch 35) | ✓ |
| Remember meaning (Ch 36) | ✓ |
| Reason locally (Ch 37) | ✓ CPU-bound |
| **Real-time cognition** | ✗ |

CPU inference creates:

- Slow token generation
- Limited concurrent completions
- Bottlenecked multi-step agent loops
- Tool orchestration waiting on inference

### Why GPUs (System View)

GPUs are **not**:

- Faster CPUs
- Optional optimizations
- "Nice to have" for demos

They are:

> **A different execution model for parallel tensor math**

Kubernetes schedules them as **heterogeneous nodes**—same cluster, different hardware profiles.

### Architecture Update

```text
                ┌──────────────┐
                │  Hermes API  │
                └──────┬───────┘
                       ↓
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
   PostgreSQL      Redis         Qdrant
                       ↓
                ┌──────────────┐
                │ Model layer  │
                └──────┬───────┘
                       ↓
        ┌──────────────────────────────┐
        │  CPU nodes    │  GPU nodes   │
        │ llama-server  │ llama-server-gpu │
        │ (baseline)    │ (CUDA)       │
        └──────────────────────────────┘
```

Workers route by policy (lab: env URLs; production: task metadata):

```text
if interactive / high complexity → llama-server-gpu
else                             → llama-server (CPU)
```

---

## Walkthrough

### Step 1 — GPU Node Provisioning (AWS)

Launch a GPU instance in the **same VPC** as `hermes-controlplane`:

| Instance | GPU | Use |
|----------|-----|-----|
| `g5.xlarge` | 1× A10G (24 GB) | Lab baseline |
| `g5.2xlarge` | 1× A10G, more vCPU/RAM | Heavier models |

1. EC2 → Launch → Ubuntu 22.04 AMI → `g5.xlarge`
2. Same VPC/subnet strategy as [Chapter 9](../part-ii-aws/09-provisioning-hermes-server.md) (or dedicated inference subnet)
3. Attach EBS for `/models` or sync GGUF from control plane ([Chapter 11](../part-ii-aws/11-persistent-storage.md))
4. Security group: cluster internal traffic only; no public inference ports

**Cost:** Stop or terminate GPU instance when lab ends ([Chapter 16](../part-ii-aws/16-managing-platform-costs.md) mindset).

### Step 2 — NVIDIA Runtime on GPU Node

On the GPU instance (see [k3s NVIDIA docs](https://docs.k3s.io/advanced#nvidia-gpu-support)):

```bash
# Driver + toolkit (distribution-specific — verify NVIDIA docs for your AMI)
nvidia-smi   # must show GPU

# If joining as k3s agent, configure containerd nvidia runtime per k3s docs
```

Verify driver before Kubernetes scheduling—CUDA mismatch failures are common.

### Step 3 — Join Cluster and Label Node

Join GPU node to k3s (agent) or run inference-only node with kubeconfig access.

Label for scheduling:

```bash
kubectl label node <gpu-node-name> accelerator=nvidia --overwrite
```

Helper script:

```bash
chmod +x infrastructure/aws/cli/ch38-gpu-node-prep.sh
NODE_NAME=<gpu-node-name> ./infrastructure/aws/cli/ch38-gpu-node-prep.sh
```

### Step 4 — NVIDIA Device Plugin

```bash
kubectl apply -f infrastructure/kubernetes/ch38-nvidia-device-plugin.yaml
```

Verify allocatable GPUs:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
```

Optional smoke test:

```bash
kubectl apply -f infrastructure/kubernetes/ch38-gpu-smoke-test-pod.yaml
kubectl logs -n hermes gpu-smoke-test
kubectl delete pod -n hermes gpu-smoke-test
```

### Step 5 — Deploy GPU Model Server

Second Helm release—CUDA image, GPU limits, node selector:

```bash
# Ensure /models/model.gguf on GPU node (copy or symlink)
helm upgrade --install llama-server-gpu infrastructure/helm/llama-server \
  -n hermes \
  -f infrastructure/helm/llama-server/values-gpu.yaml
```

Key scheduling fragment from `values-gpu.yaml`:

```yaml
runtimeClassName: nvidia
nodeSelector:
  accelerator: nvidia
resources:
  limits:
    nvidia.com/gpu: 1
image:
  tag: server-cuda
service:
  name: llama-server-gpu
```

CPU path remains: `llama-server` on control plane ([Chapter 37](37-model-serving.md)).

### Step 6 — Dual-Path Worker Wiring

```bash
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml \
  -f infrastructure/helm/hermes-lab/values-with-llama.yaml \
  -f infrastructure/helm/hermes-lab/values-dual-inference.yaml
```

Worker env:

| Variable | Target |
|----------|--------|
| `LLAMA_SERVER_URL` | `http://llama-server:8080` (CPU) |
| `LLAMA_SERVER_GPU_URL` | `http://llama-server-gpu:8080` (GPU) |

Production Hermes implements routing logic; lab proves **both endpoints exist**.

### Step 7 — Compare CPU vs GPU

Run the same completion against both (port-forward each Service):

```bash
# CPU
kubectl port-forward -n hermes svc/llama-server 8080:8080 &
curl -sf http://127.0.0.1:8080/completion \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Count to five.","n_predict":64,"stream":false}' | head -c 400

# GPU (different terminal)
kubectl port-forward -n hermes svc/llama-server-gpu 8081:8080 &
curl -sf http://127.0.0.1:8081/completion \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Count to five.","n_predict":64,"stream":false}' | head -c 400
```

Record tokens/sec and wall time in notes—**cost/latency tradeoff is data, not opinion**.

### Step 8 — Cost / Latency Model

| Mode | Latency | Cost | Hermes use |
|------|---------|------|------------|
| **CPU** | High | Low (existing node) | Background tasks, dev, batch |
| **GPU** | Low | High ($/hour g5) | Interactive agents, multi-step loops |

Architectural rule:

> **Do not leave GPU nodes running idle**—scale to zero or stop EC2 when not inferencing.

---

## Hands-on Lab

### Lab 37: Heterogeneous Inference

**Estimated Time:** 80 minutes (if quota and AMI ready)

**Goal:** GPU node labeled; device plugin reports GPUs; `llama-server-gpu` Running; dual URLs in workers.

**Steps:**

1. Launch `g5.xlarge`; install NVIDIA driver; `nvidia-smi`
2. Join k3s; label `accelerator=nvidia`
3. Apply device plugin; verify allocatable GPU
4. Place `model.gguf` on GPU node `/models`
5. `helm install llama-server-gpu` with `values-gpu.yaml`
6. Upgrade hermes-lab with `values-dual-inference.yaml`
7. Compare completion latency CPU vs GPU
8. Stop GPU instance; document $/hour in notes

---

## Verification

- [ ] `nvidia-smi` works on GPU node
- [ ] Node shows `nvidia.com/gpu: 1` allocatable
- [ ] `llama-server-gpu` Pod Running on GPU node
- [ ] `/completion` succeeds on GPU Service
- [ ] Workers log `llama_gpu` URL
- [ ] CPU `llama-server` still available for baseline path

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pod Pending | No GPU allocatable | Device plugin; node label; driver |
| `CUDA error` | Driver/runtime mismatch | Match toolkit to driver version |
| Wrong node | Missing nodeSelector | `accelerator=nvidia` label |
| OOM on GPU | Model too large for VRAM | Smaller quant; g5.2xlarge; shorter context |
| Models missing on GPU node | hostPath only on control plane | Copy/sync `/models` to GPU instance |
| Expensive idle bill | GPU EC2 left running | Stop instance after lab |

### Failure Modes

**GPU underutilization** — g5 running 24/7 for occasional queries. Fix: scheduled scale-down, separate inference node pool.

**Scheduling imbalance** — Many GPU Pods, one GPU node. Fix: queue; second GPU node; limit `replicaCount`.

**Driver instability** — Kernel update breaks NVIDIA module. Fix: pin AMI; test after upgrades.

**CPU/GPU output divergence** — Different quant or context between paths. Fix: same GGUF; document path in logs.

---

## Review Questions

1. Why is a GPU not "a faster CPU" in system design terms?
2. What does `nvidia.com/gpu: 1` in Pod limits accomplish?
3. Why keep CPU inference after adding GPU?
4. When is GPU inference not worth the cost?
5. How does dual-path routing change worker design?

---

## Key Takeaways

- **GPUs are a distinct compute substrate** for tensor workloads
- **Kubernetes schedules heterogeneous nodes** via labels + resource requests
- **Hermes spans CPU + GPU execution domains** — routing is architecture
- **Cost is a first-class constraint** — acceleration is never free
- Without GPU: reasoning **simulation**; with GPU: **real-time cognition** potential
- System evolution: **Execution → Memory → Reasoning → Acceleration**

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Heterogeneous cluster** | Kubernetes cluster with different node hardware profiles. |
| **Device plugin** | DaemonSet exposing GPUs as `nvidia.com/gpu` resources. |
| **CUDA** | NVIDIA parallel compute platform for GPU inference. |
| **runtimeClassName: nvidia** | Pod spec selecting NVIDIA container runtime. |
| **Dual-path inference** | CPU baseline + GPU accelerated model servers. |

---

## Further Reading

- [k3s NVIDIA GPU support](https://docs.k3s.io/advanced#nvidia-gpu-support)
- [NVIDIA k8s device plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [AWS EC2 G5 instances](https://aws.amazon.com/ec2/instance-types/g5/)
- [Chapter 37: Model Serving](37-model-serving.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

CPU inference (llama-server)     ✓
GPU inference (llama-server-gpu) ◐ (optional lab)
Dual-path routing                ◐ (env wired)
Agent reasoning loop             ◐ (Ch 39)

Hermes cognitive system          ◐
───────────────────────────────────────────────
```

```text
Execution → Memory → Reasoning → Acceleration
```

---

## What's Next

[Chapter 39: The Hermes Reasoning Loop](39-ai-agent-architecture.md) — task-driven loop; workers own execution; models propose.

---

[← Chapter 37: Model Serving](37-model-serving.md) | [Next: Chapter 39 — The Hermes Reasoning Loop →](39-ai-agent-architecture.md)
