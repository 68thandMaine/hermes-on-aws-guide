---
sidebar_position: 22
description: "Declare desired Pod count and let the control plane reconcile."
---

# Chapter 22: Deployments

> A Pod is something you run.
>
> A Deployment is something you describe.

---

In [Chapter 21](21-pods.md) you created a **Pod**—a one-shot execution unit.

In [Chapter 13](../part-ii-aws/13-the-first-control-plane.md) you already learned **declarative reality**: describe desired state; the control plane reconciles.

A **Deployment** is how you express that pattern for application Pods:

```text
Chapter 21   Pod        →  “run this once”
Chapter 22   Deployment →  “always keep N of these running”
```

You are not learning a new paradigm. You are **using the reconciliation loop** you already saw in system pods—now for your own workload.

:::note[Why this matters for Hermes]

Hermes will run as a Deployment (or similar controller)—not as a Pod you create by hand. Self-healing, scaling, and rollouts depend on desired state. This chapter is the control-layer knob you will turn again when deploying the agent stack.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Contrast imperative Pod creation (Ch 21) with declarative Deployment manifests
- [ ] Create a Deployment and observe ReplicaSet-managed Pods
- [ ] Scale replicas with `kubectl scale`
- [ ] Trigger self-healing by deleting a Pod and watching replacement
- [ ] Perform a basic image rollout with `kubectl set image` and `rollout status`
- [ ] Map Deployments to **State Layers** (Intent → API → controllers → Pods → kernel)

---

## Prerequisites

- [Chapter 21: Pods](21-pods.md) — bare Pod created and deleted
- k3s cluster Ready; `KUBECONFIG` configured

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
```

---

## Estimated Time

**75 minutes** — 20 minutes reading, 55 minutes hands-on.

---

## Background

### Imperative vs Declarative (Already Yours)

Chapter 21 was **imperative**:

```bash
kubectl run hello-pod --image=nginx --restart=Never
```

Meaning: *create this Pod right now*.

A Deployment is **declarative**—the model from Chapter 13 applied to workloads:

```yaml
spec:
  replicas: 3
```

Meaning: *the system should always have three Pods matching this template*. Controllers reconcile continuously.

### State Layer Mapping

```text
Human Intent          ← replicas: 3 in YAML; kubectl apply
Kubernetes API        ← Deployment + ReplicaSet objects in etcd
Scheduler             ← places each Pod on a node
Containers            ← nginx in each Pod
Linux Kernel          ← processes on hermes-controlplane-01
```

The new piece is the **controller** between API and Pods: it watches desired vs actual count and creates or deletes Pods to match.

---

## Theory

### What a Deployment Manages

A Deployment is a controller that owns:

| Responsibility | Mechanism |
|----------------|-----------|
| Pod count | ReplicaSet |
| Pod template | Container spec, labels |
| Scaling | Change `replicas` |
| Updates | Rolling replacement of Pods |
| Self-healing | Recreate Pods that disappear |

You define **desired state**. Kubernetes enforces it.

### Deployment → ReplicaSet → Pod

```text
Deployment
    ↓
ReplicaSet        ← “keep N Pods matching this template”
    ↓
Pod(s)
```

You usually interact with the Deployment only. The ReplicaSet is the object that holds the replica count and Pod template for a given revision.

### The Reconciliation Loop

Controllers run this loop forever:

```text
Read desired state (Deployment spec)
Read current state (Pods in cluster)
Diff
Apply corrections (create/delete/update Pods)
Sleep; repeat
```

That is why:

- Deleting a Pod spawns another (Deployment still wants N)
- Scaling persists (replicas is stored in etcd)
- Failed Pods get replaced when policy allows

Same behavior you observed in `kube-system` after Chapter 13—now under **your** manifest.

---

## Architecture

### Bare Pod vs Deployment

| | Chapter 21 Pod | Chapter 22 Deployment |
|---|----------------|------------------------|
| Create | `kubectl run` | `kubectl apply -f` |
| Count | One | `replicas: N` |
| Delete Pod | Stays gone | New Pod appears |
| Production use | Debugging only | Standard for apps |

On a single-node k3s cluster, three replicas still schedule on **the same node**—correct for learning. Multi-node spread comes later.

---

## Walkthrough

### Step 1 — Write the Manifest

Create `~/hermes-platform/manifests/nginx-deployment.yaml` or use the book copy:

**[infrastructure/kubernetes/ch22-nginx-deployment.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch22-nginx-deployment.yaml)**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
```

`replicas: 3` is desired state. The template is the Pod spec each replica uses.

### Step 2 — Apply Desired State

From the repo root (or path to your copy):

```bash
kubectl apply -f infrastructure/kubernetes/ch22-nginx-deployment.yaml
```

You are not starting a container. You are registering intent with the API.

### Step 3 — Observe

```bash
kubectl get deployments
kubectl get replicasets
kubectl get pods -l app=nginx
```

Expected:

- **1** Deployment (`nginx-deployment`)
- **1** ReplicaSet (hash suffix in name)
- **3** Pods, all **Running**

You did not create three Pods manually. The controller enforced `replicas: 3`.

Wide view:

```bash
kubectl get pods -l app=nginx -o wide
```

### Step 4 — Self-Healing

Pick one Pod and delete it:

```bash
POD=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD"
```

Wait a few seconds:

```bash
kubectl get pods -l app=nginx
```

You should still see **3** Pods—one with a newer `AGE`. The Deployment tracked **desired count**, not the identity of individual Pods.

### Step 5 — Scale

```bash
kubectl scale deployment nginx-deployment --replicas=5
kubectl get pods -l app=nginx
```

Five Pods. No new concept—only changed declared state.

Scale back when done:

```bash
kubectl scale deployment nginx-deployment --replicas=3
```

### Step 6 — Rollout (Introduction)

Change the image:

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.27-alpine
kubectl rollout status deployment/nginx-deployment
```

Kubernetes replaces Pods gradually—controlled rollout, not simultaneous delete-all. Full rollout strategies come in later operations chapters; for now, observe that **image change is declarative too**.

Check history:

```bash
kubectl rollout history deployment/nginx-deployment
```

### Step 7 — Cleanup (Optional)

```bash
kubectl delete deployment nginx-deployment
kubectl get pods -l app=nginx   # should be empty
```

---

## Hands-on Lab

### Lab 22: Deployment Reconciliation

**Estimated Time:** 55 minutes

**Goal:** Apply a Deployment, observe self-healing and scaling, perform one rollout.

**Steps:**

1. Apply `ch22-nginx-deployment.yaml`
2. Confirm 1 Deployment, 1 ReplicaSet, 3 Running Pods
3. Delete one Pod; confirm count returns to 3
4. Scale to 5, then back to 3
5. `set image` to `nginx:1.27-alpine`; wait for `rollout status`
6. Note which State Layer each step touched in your platform notes

---

## Verification

- [ ] Deployment `nginx-deployment` exists with `READY 3/3` (or current replica count)
- [ ] ReplicaSet visible via `kubectl get replicasets`
- [ ] Deleted Pod was replaced automatically
- [ ] Scale to 5 and back to 3 succeeded
- [ ] Rollout completed without manual Pod creation
- [ ] You can explain Deployment vs bare Pod in one sentence each

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pods keep coming back after delete | Deployment still owns them | `kubectl delete deployment nginx-deployment` to remove desired state |
| `0/3 READY` | Image pull or scheduling | `kubectl describe deployment nginx-deployment`; `kubectl describe pod` |
| Only 1 Pod despite `replicas: 3` | Typo in YAML or not applied | `kubectl get deployment nginx-deployment -o yaml` — check `replicas` |
| Rollout stuck | Image pull failed on new tag | `kubectl describe pod`; verify tag exists |
| “Why multiple Pods?” | `replicas` > 1 | Intentional—Deployment enforces count |

### Common Mistakes

**“Why does my Pod keep coming back?”**  
You deleted a Pod, not the Deployment. Remove desired state: delete the Deployment.

**“Why didn’t manual scaling stick?”**  
Only objects in the API (Deployment spec) define persistent state. Creating Pods by hand bypasses the controller.

---

## Review Questions

1. What object guarantees “N Pods matching this template”?
2. Where does `replicas: 3` live in State Layers?
3. What happens if you delete a Pod but not the Deployment?
4. How is `kubectl apply` different from `kubectl run` in Chapter 21?
5. Why does Hermes belong in a Deployment rather than a bare Pod?

---

## Key Takeaways

- **Pod** = runtime unit you ran once in Ch 21; **Deployment** = desired state for many Pods
- Controllers reconcile forever—same loop as Chapter 13, now for your manifests
- ReplicaSet sits between Deployment and Pods; you operate at Deployment level
- Self-healing and scaling are **state corrections**, not magic
- Next: [Services](23-services.md)—stable network identity over Pod IPs that change

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Deployment** | Controller that manages ReplicaSets and rolling updates for stateless apps. |
| **ReplicaSet** | Ensures a stable set of Pod replicas running at any time. |
| **Desired state** | Declared configuration the control plane converges toward. |
| **Reconciliation** | Continuous compare-and-correct loop run by controllers. |
| **Rollout** | Gradual replacement of Pods when Pod template changes. |

---

## Further Reading

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Chapter 13: Declarative Reality](../part-ii-aws/13-the-first-control-plane.md#declarative-reality)
- [Chapter 21: Pods](21-pods.md)

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
Deployments            ✓

Services               ✗
Ingress                ✗

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

██████████████░░░░░░░░ 72%
───────────────────────────────────────────────
```

Desired state is live. Next: stable networking over ephemeral Pod IPs.

---

## What's Next

[Chapter 23: Services](23-services.md) — stop targeting Pod IPs directly; expose a stable cluster address for workloads that come and go.

---

[← Chapter 21: Pods](21-pods.md) | [Next: Chapter 23 — Services →](23-services.md)
