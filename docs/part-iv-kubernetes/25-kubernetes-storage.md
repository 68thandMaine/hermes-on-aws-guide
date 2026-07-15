---
sidebar_position: 25
description: "PersistentVolumeClaims that survive Pod restarts on k3s."
---

# Chapter 25: Storage

> Compute is disposable.
>
> State is not.

---

Chapters 20–23 built **routing compute**: Pods, Deployments, Services, Ingress. When a Pod dies, the control plane replaces it—**and any data inside the container filesystem is gone**.

From here you **persist reality**: storage that outlives Pod identity.

```text
Chapters 20–23   →  routing compute (disposable)
Chapter 25+      →  persisting state (not disposable)
```

This is required before PostgreSQL, Redis persistence, or Hermes conversation history mean anything in production.

:::note[Why this matters for Hermes]

Hermes depends on durable state—PostgreSQL, optional Redis AOF, model metadata on disk. Without PVCs (or equivalent), every Pod restart wipes memory. [Chapter 11](../part-ii-aws/11-persistent-storage.md) protected **node disks**; this chapter protects **workload data inside Kubernetes**.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why container filesystems are ephemeral by default
- [ ] Distinguish `emptyDir` vs PersistentVolumeClaim
- [ ] Create a PVC on k3s using the **local-path** StorageClass
- [ ] Mount a PVC into a Pod and verify data survives Pod deletion
- [ ] Relate PVC/PV to [Chapter 11](../part-ii-aws/11-persistent-storage.md) EBS tiers on the node
- [ ] Map storage objects to **State Layers**

---

## Prerequisites

- [Chapter 13: The First Control Plane](../part-ii-aws/13-the-first-control-plane.md) — k3s with `local-path-provisioner` in `kube-system`
- [Chapter 11: Persistent Storage](../part-ii-aws/11-persistent-storage.md) — `/models`, `/data` on EBS (node layer)
- `KUBECONFIG` configured

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get storageclass
kubectl get pods -n kube-system -l app=local-path-provisioner
```

---

## Estimated Time

**75 minutes** — 25 minutes reading, 50 minutes hands-on.

---

## Background

### The Problem

A Pod writes:

```text
/data/app.db
```

You delete the Pod:

```bash
kubectl delete pod storage-demo
```

**The file is gone.** Deployments recreate Pods with **fresh** container filesystems.

That breaks:

- Databases
- Uploads and checkpoints
- Hermes session history
- Any system “memory”

You need storage that **outlives Pod identity**.

### Two Persistence Layers on Hermes

| Layer | Chapter | What it protects |
|-------|---------|------------------|
| **Node EBS** | 11 | `/models`, `/data` on the EC2 instance |
| **Kubernetes PVC** | 24 | Data mounted into Pods (PostgreSQL data dir, etc.) |

They work together. Chapter 11 is **disk on the server**; Chapter 25 is **disk attached to workloads** through the API.

### State Layer Mapping

```text
Human Intent          ← PVC spec: size, access mode, storage class
Kubernetes API        ← PVC + PV objects; Pod volumeMount
Scheduler             ← Pod placed on node (RWO: one node)
Provisioner           ← local-path creates directory on node disk
Containers            ← process reads/writes mountPath
Linux Kernel          ← block/filesystem I/O to underlying storage
```

Same declarative pattern—new resource types, not a new mental model.

---

## Theory

### Container Storage (Default)

| Layer | Lifetime |
|-------|----------|
| Container writable layer | Pod lifetime |
| Image layers | Read-only; shared |
| Memory | Volatile |

Everything in the container root filesystem disappears when the Pod is removed.

### Kubernetes Storage Stack

```text
Pod
  └── volumeMount → /data
        └── Volume (Pod spec)
              └── PersistentVolumeClaim (app-data)
                    └── PersistentVolume (bound)
                          └── local-path on node disk
```

**You declare PVCs.** k3s **local-path-provisioner** creates PVs automatically—no manual PV YAML in this lab.

### Ephemeral vs Persistent

| Type | Example | Survives Pod delete? |
|------|---------|----------------------|
| **emptyDir** | Scratch cache | No |
| **PVC** | Database files | **Yes** (PV remains until PVC deleted) |

### k3s on EC2: local-path Reality

k3s ships **local-path** StorageClass (provisioner pod in `kube-system`). PVCs allocate directories on the **node’s disk**—typically under `/var/lib/rancher/k3s/storage/` on the root EBS volume.

| Backend | Pod dies | Node dies |
|---------|----------|-----------|
| **local-path** (this lab) | Data survives | Data on that node’s disk—restore from [Ch 11 snapshots](../part-ii-aws/11-persistent-storage.md) |
| EBS via CSI (later) | Data survives | Volume can reattach to another node (multi-node) |

You are learning **raw Kubernetes storage binding** on a single-node platform—not managed RDS or EFS yet.

---

## Architecture

### Before and After PVC

```text
Before:
  Deployment → Pod → write /data/foo → delete Pod → foo gone

After:
  Deployment → Pod → volumeMount PVC → delete Pod → new Pod → same PVC → foo still there
```

PostgreSQL and Hermes state will use this pattern (StatefulSet adds stable identity in Part VI/VII).

---

## Walkthrough

### Step 1 — Inspect StorageClass

```bash
kubectl get storageclass
```

Expected: **`local-path`** (often default on k3s). Note `PROVISIONER` = `rancher.io/local-path`.

```bash
kubectl describe storageclass local-path
```

### Step 2 — Create PersistentVolumeClaim

**[infrastructure/kubernetes/ch25-app-data-pvc.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch25-app-data-pvc.yaml)**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

Apply:

```bash
kubectl apply -f infrastructure/kubernetes/ch25-app-data-pvc.yaml
kubectl get pvc app-data
```

Expected:

```text
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES
app-data   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO
```

**Bound** means the provisioner created a PV and linked it to your claim.

### Step 3 — Mount PVC in a Pod

**[infrastructure/kubernetes/ch25-storage-demo-pod.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch25-storage-demo-pod.yaml)**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - echo "hello from $(date -Iseconds)" >> /data/hello.txt && tail -f /dev/null
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: app-data
```

Apply:

```bash
kubectl apply -f infrastructure/kubernetes/ch25-storage-demo-pod.yaml
kubectl wait --for=condition=Ready pod/storage-demo --timeout=120s
```

### Step 4 — Verify Data on Disk

```bash
kubectl exec storage-demo -- cat /data/hello.txt
```

You should see at least one line with `hello from …`.

### Step 5 — Delete the Pod (Not the PVC)

```bash
kubectl delete pod storage-demo
kubectl get pvc app-data    # still Bound
```

The Pod is gone. The PVC—and the data on the PV—remain.

### Step 6 — Recreate the Pod

```bash
kubectl apply -f infrastructure/kubernetes/ch25-storage-demo-pod.yaml
kubectl wait --for=condition=Ready pod/storage-demo --timeout=120s
kubectl exec storage-demo -- cat /data/hello.txt
```

**Same file contents**—including lines written before the delete. Pod identity changed; **storage identity persisted**.

### Step 7 — Optional emptyDir Contrast

Ephemeral volume (do not use for Hermes data):

```yaml
volumes:
  - name: scratch
    emptyDir: {}
```

Data in `emptyDir` dies with the Pod—useful for temp files only.

---

## Hands-on Lab

### Lab 24: Persistence Survives Pod Death

**Estimated Time:** 50 minutes

**Goal:** Prove PVC data outlives Pod deletion on k3s local-path.

**Steps:**

1. Confirm `local-path` StorageClass and provisioner Running
2. Apply PVC; wait for **Bound**
3. Apply `storage-demo` Pod; append to `/data/hello.txt`
4. Delete Pod; confirm PVC still **Bound**
5. Reapply Pod; read file—content preserved
6. Note where PVC fits in State Layers vs Ch 11 EBS mounts

**Cleanup (optional):**

```bash
kubectl delete pod storage-demo
kubectl delete pvc app-data    # destroys PV data—only when done experimenting
```

---

## Verification

- [ ] `app-data` PVC **Bound** to a PV
- [ ] Data written before Pod delete readable after Pod recreate
- [ ] You can explain Pod ephemeral root vs PVC mount
- [ ] You know local-path is node-local (single-node caveat)
- [ ] You can name Hermes components that will need PVCs

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| PVC **Pending** | No StorageClass / provisioner down | `kubectl get sc`; check local-path-provisioner pod |
| Pod **Pending** | PVC not Bound or RWO conflict | `kubectl describe pod storage-demo` |
| Permission denied on mount | Rare with local-path | `kubectl describe pvc`; check Events |
| Data gone after recreate | Deleted PVC or used emptyDir | Keep PVC; use `claimName: app-data` |
| Disk full | Root EBS filling | `df -h` on node; Ch 11 monitoring |

### Failure Modes (Operations)

| Event | local-path on single node |
|-------|---------------------------|
| Pod crash / delete | **Data safe** (PVC intact) |
| Deployment rollout | Mount same PVC in new Pod template |
| Node loss | **Data on that node’s disk**—recover from EBS snapshots (Ch 11) |
| PVC deleted | **Data destroyed**—treat like dropping a database |

---

## Review Questions

1. Why does deleting a Pod erase files written to `/tmp` inside the container?
2. What object do you create to request storage from the cluster?
3. What does **Bound** mean on a PVC?
4. How is Ch 11 EBS different from a Kubernetes PVC?
5. Why is local-path insufficient for multi-node HA without extra work?

---

## Key Takeaways

- **Compute is disposable; state is not**—PVCs survive Pod lifecycle
- **PVC → PV → node disk** on k3s via **local-path**
- **ReadWriteOnce** = one node at a time (fine for single-node Hermes)
- Hermes/PostgreSQL need this before they are real systems
- Full stack so far: **Ingress → Service → Deployment → Pod → PVC**

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **PersistentVolume (PV)** | Cluster storage resource backing a claim. |
| **PersistentVolumeClaim (PVC)** | Request for storage; binds to a PV. |
| **StorageClass** | Defines how PVCs are provisioned (`local-path` on k3s). |
| **ReadWriteOnce (RWO)** | Volume mountable read-write by a single node. |
| **emptyDir** | Ephemeral volume lifecycle tied to a Pod. |
| **local-path** | k3s provisioner storing data on the node filesystem. |

---

## Further Reading

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [k3s local storage](https://docs.k3s.io/storage)
- [Chapter 11: Persistent Storage](../part-ii-aws/11-persistent-storage.md)

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
Services               ✓
Ingress (HTTP)         ✓
Persistent K8s volumes ✓

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

█████████████████░░░░░ 82%
───────────────────────────────────────────────
```

Routing and persistence layers exist. Next: package and harden the platform.

---

## What's Next

[Chapter 26: Helm](26-helm.md) — package manifests (Deployments, Services, Ingress, PVCs) into reusable charts before the Hermes stack lands.

When you deploy PostgreSQL in Part VI/VII, you will combine **PVCs from this chapter** with **StatefulSet** identity (stable network names, ordered rollout)—the database-shaped application of the same storage model.

---

[← Chapter 24: Ingress](24-ingress.md) | [Next: Chapter 26 — Helm →](26-helm.md)
