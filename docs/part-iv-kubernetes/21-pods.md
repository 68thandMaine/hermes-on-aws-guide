---
sidebar_position: 21
description: "Schedule your first workload on the live control plane—execution only."
---

# Chapter 21: Pods

> How do I place something into the system I already built?

---

Chapter 13 gave you a scheduler. This chapter **uses** it.

You are not learning Kubernetes in the abstract. You are **materializing the runtime** already specified in [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md) and activated in [Chapter 13](../part-ii-aws/13-the-first-control-plane.md).

A **Pod** is the smallest executable unit the scheduler places on a node. Everything that runs in the cluster—eventually Hermes, llama.cpp, PostgreSQL, Redis—runs inside Pods (or controllers that create Pods).

For most workloads: **Pod = one container**. Start there.

:::note[Why this matters for Hermes]

Later chapters deploy Hermes, inference, and databases as scheduled workloads. This chapter is the first time you manipulate the **execution substrate** for `laptop → ingress → Hermes → model → response`. No Hermes image yet—just nginx, to learn placement and lifecycle.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Describe a Pod in practical terms: shared execution context for one or more containers
- [ ] Create a Pod on the live k3s cluster and confirm it reaches **Running**
- [ ] Inspect Pod state with `kubectl get`, `describe`, and `logs`
- [ ] Forward a port and interact with a Pod from your laptop
- [ ] Explain Pod lifecycle states (Pending, Running, Succeeded, Failed)
- [ ] Map Pod scheduling to **State Layers** and the Linux process model from [Chapter 3](../part-i-foundations/03-linux.md)

---

## Prerequisites

- [Chapter 13: The First Control Plane](../part-ii-aws/13-the-first-control-plane.md) — k3s running, node **Ready**
- `KUBECONFIG` pointing at the cluster

```bash
export AWS_PROFILE=hermes
source ~/hermes-platform/notes/controlplane.env
source ~/hermes-platform/notes/platform.env
export KUBECONFIG=~/.kube/hermes-k3s.yaml

kubectl get nodes   # must show Ready
```

---

## Estimated Time

**60 minutes** — 15 minutes reading, 45 minutes hands-on.

---

## Background

### What a Pod Actually Is

A Pod is **one or more containers that share the same execution context**:

| Shared context | Effect |
|----------------|--------|
| Network namespace | Same IP address inside the Pod |
| Storage volumes | Shared mount paths between containers |
| Scheduling | Co-started, co-located on one node |

At runtime, the simplest mental model:

```text
Pod
 └── Container(s)
```

For roughly 90% of cases—including every first workload in this book—**a Pod runs one container**.

### State Layer Mapping

Where does a Pod live in the stack from [Chapter 13](../part-ii-aws/13-the-first-control-plane.md)?

```text
Human Intent          ← you: kubectl run hello-pod ...
Kubernetes API        ← Pod object stored in etcd
Scheduler             ← assigns Pod to hermes-controlplane-01
Containers            ← nginx process in containerd
Linux Kernel          ← actual process execution
```

You declare a Pod at the **API layer**. Everything below is reconciliation you observe—not SSH commands on the node.

### Why Pods Instead of Bare Containers?

In [Chapter 3](../part-i-foundations/03-linux.md) you learned: Linux runs processes, systemd manages services, containers package processes.

Kubernetes schedules **groups of containers as a unit** because real services are rarely single-process:

- Application + log shipper sidecar
- App + metrics exporter
- Service mesh proxy alongside the app

Pods ensure those containers **start together, share network and storage, and are scheduled as one decision**. For today's lab, one container is enough—the model still holds.

---

## Theory

### Pod Lifecycle

A Pod moves through predictable states:

```text
Pending → Running → Succeeded | Failed
```

| State | Meaning |
|-------|---------|
| **Pending** | Accepted by API; scheduler assigning node; image may be pulling |
| **Running** | At least one container is active |
| **Succeeded** | All containers exited 0 (Jobs) |
| **Failed** | At least one container failed |

`--restart=Never` on a bare Pod means Kubernetes will **not** recreate it if the container exits—you see Succeeded or Failed and the Pod stays terminal.

### What Happens When You Create a Pod

When you run:

```bash
kubectl run hello-pod --image=nginx --restart=Never
```

The chain (no new model—same stack as Chapter 13):

```text
kubectl  →  API server stores Pod spec
         →  Scheduler binds Pod to node
         →  kubelet on node instructs containerd
         →  containerd pulls image (if needed)
         →  Linux kernel starts nginx process
         →  Pod status: Running
```

This is why Chapter 3 mattered: at the bottom, it is still **processes on Linux**. Kubernetes adds scheduling and declared state above that.

---

## Architecture

### Raw Pod vs Controllers

This chapter creates a **bare Pod**—no Deployment, no abstraction layer on top. That is intentional:

| Approach | This chapter | Chapter 22 |
|----------|--------------|------------|
| Create | `kubectl run … --restart=Never` | Deployment manages Pod replicas |
| If container dies | Pod stays Failed (no restart) | Deployment recreates Pod |
| Use case | Learn placement and inspection | Desired state at scale |

You are instantiating **Layer 1 of the orchestration stack**: place one unit on the scheduler you already have.

---

## Walkthrough

### Step 1 — Create a Pod

```bash
kubectl run hello-pod \
  --image=nginx \
  --restart=Never
```

This schedules a Pod running the `nginx` container. Nothing runs on the node until the scheduler and kubelet complete their work.

Verify:

```bash
kubectl get pods
```

Expected:

```text
NAME        READY   STATUS    RESTARTS   AGE
hello-pod   1/1     Running   0          10s
```

**Running** confirms: scheduled, image pulled, container started—the control plane is managing lifecycle.

If **Pending** persists beyond two minutes, see [Troubleshooting](#troubleshooting).

### Step 2 — Inspect the Pod

```bash
kubectl describe pod hello-pod
```

Read these sections first:

- **Events** — scheduling, image pull, container start (primary debug surface)
- **Containers** — state, image, restart count
- **Node** — should be `hermes-controlplane-01` (or your node name)

This command is how you **see what the scheduler did** without SSH guessing.

### Step 3 — Logs

```bash
kubectl logs hello-pod
```

Logs are the container's stdout/stderr. Kubernetes **collects** them; it does not replace the process. Same idea as `journalctl` for systemd—streams from a running process ([Chapter 3](../part-i-foundations/03-linux.md)).

### Step 4 — Access the Pod

Forward port 80 inside the Pod to your laptop:

```bash
kubectl port-forward pod/hello-pod 8080:80
```

In another terminal—or browser—open:

```text
http://localhost:8080
```

You should see the nginx welcome page. You are interacting with a process **inside the cluster**, declared through the API—not with a manually started Docker container on the node.

Stop port-forward with `Ctrl+C` when done.

### Step 5 — Delete the Pod

```bash
kubectl delete pod hello-pod
```

Kubernetes stops the container, tears down Pod networking, frees node resources, and removes the object from etcd. Confirm:

```bash
kubectl get pods
```

`hello-pod` should be gone.

---

## Hands-on Lab

### Lab 21: First Pod on the Hermes Cluster

**Estimated Time:** 45 minutes

**Goal:** Create, inspect, access, and delete a Pod; map each step to a State Layer.

**Steps:**

1. Confirm `kubectl get nodes` → **Ready**
2. Create `hello-pod` with nginx; wait for **Running**
3. `kubectl describe pod hello-pod` — note Events and Node
4. `kubectl logs hello-pod`
5. `port-forward` and load nginx in browser
6. Delete the Pod; confirm removal
7. In your notes, write one line per State Layer for this exercise

**Do not** deploy Hermes, llama.cpp, or database images in this lab.

---

## Verification

- [ ] `kubectl get nodes` → **Ready** before starting
- [ ] `hello-pod` reached **Running** (1/1 Ready)
- [ ] `describe` shows Events with successful schedule and start
- [ ] `kubectl logs hello-pod` returned nginx output
- [ ] Port-forward served nginx on `localhost:8080`
- [ ] Pod deleted cleanly
- [ ] You can state where Pod, Scheduler, and containerd each appear in State Layers

---

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| `Unable to connect to the server` | Wrong or missing `KUBECONFIG` | `export KUBECONFIG=~/.kube/hermes-k3s.yaml`; check Ch 13 kubeconfig |
| Pod stuck **Pending** | Image pull slow or node NotReady | `kubectl describe pod hello-pod`; check Events; `kubectl get nodes` |
| `ImagePullBackOff` | Registry unreachable or bad image name | Verify `nginx` tag; check node outbound network |
| `CrashLoopBackOff` (if restart policy changed) | Container exits immediately | `kubectl logs hello-pod`; fix command or image |
| Port-forward fails | Pod not Running or wrong port | Confirm `1/1 Running`; nginx listens on 80 |

---

## Review Questions

1. In one sentence, what is a Pod?
2. Which State Layer does `kubectl run` write to first?
3. What is the difference between **Pending** and **Running**?
4. Why does this chapter use `--restart=Never`?
5. Where do Pod logs come from?
6. Why will Hermes eventually run in Pods rather than via `docker run` on the node?

---

## Key Takeaways

- **Chapter 21 uses the scheduler** from Chapter 13—no second ignition moment
- A Pod is the smallest **scheduled** execution unit; most Pods run one container
- **Inspect with** `get`, `describe`, `logs`—operate the system, do not SSH by default
- Lifecycle: Pending → Running → terminal states
- **State Layers:** Intent (you) → API (Pod object) → Scheduler → containerd → kernel
- Bare Pods are for learning; [Chapter 22](22-deployments.md) manages Pods as **desired state**

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Pod** | Smallest schedulable unit in Kubernetes; one or more containers sharing network and storage context. |
| **Pending** | Pod accepted but not yet running (scheduling or image pull in progress). |
| **kubelet** | Node agent that creates/manages Pod containers via the container runtime. |
| **port-forward** | Temporary tunnel from local port to a Pod port—for debugging, not production ingress. |

---

## Further Reading

- [Kubernetes Pod documentation](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Chapter 20: Why Kubernetes Exists](20-why-kubernetes-exists.md) — optional theory depth
- [Chapter 3: Linux](../part-i-foundations/03-linux.md) — processes and systemd (execution foundation)

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
Docker Engine          ✓

Kubernetes (k3s)       ✓
Control Plane          ✓
Node Ready             ✓
First Pod scheduled    ✓

Deployments            ✗
Services               ✗
Ingress                ✗

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

█████████████░░░░░░░░░ 68%
───────────────────────────────────────────────
```

You placed workload on the scheduler. Next: manage Pods as desired state.

---

## What's Next

[Chapter 22: Deployments](22-deployments.md) — stop creating Pods by hand; declare how many should run and let the control plane reconcile.

Optional: [Chapter 20: Why Kubernetes Exists](20-why-kubernetes-exists.md) for theory depth without blocking progress.

---

[← Chapter 13: The First Control Plane](../part-ii-aws/13-the-first-control-plane.md) | [Next: Chapter 22 — Deployments →](22-deployments.md)
