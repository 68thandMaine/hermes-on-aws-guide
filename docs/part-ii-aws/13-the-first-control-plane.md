---
sidebar_position: 13
description: "Install k3s and give the Hermes platform its first Kubernetes control plane."
---

# Chapter 13: The First Control Plane

> We are now giving Hermes a scheduler.

---

Up to now, you have been assembling a **capable Linux machine**—network, trust, storage, Docker. Each chapter added a component. None of them, by themselves, *behaved* like a platform.

After k3s, the machine becomes something else entirely:

> **A self-hosted compute platform that can schedule and run systems.**

That transition is the real threshold—not Docker.

Docker turned `hermes-controlplane-01` into a host that **can** run containers ([Chapter 12](12-building-the-application-platform.md)).

**k3s** turns it into a host that **schedules** containers—automatically, declaratively, and repeatedly.

```text
Until Chapter 12     →  A capable Linux server
After Chapter 13   →  A self-hosted compute platform that can schedule and run systems
```

You are not "installing Kubernetes" as a checklist item. You are **installing a control plane**—the brain that decides which containers run where, when they restart, and how they connect.

### The Big Idea

Docker was **preparation**.

k3s is the first chapter of the platform layer that **produces behavior**.

After this chapter, `kubectl get nodes` returns Ready. System pods run. The machine is **alive**.

**Hermes does not deploy yet.** Learn Pods, Deployments, Services, and Ingress with simple examples in [Part IV — Kubernetes](../part-iv-kubernetes/20-pods.md) first. Applications come after the platform works.

### Why This Chapter Sits Here (Pedagogically)

Most books introduce Kubernetes in a detached "Part IV"—theory first, install later, applications somewhere after that. That separates **understanding** from **experience** at exactly the moment the reader needs both.

This book does the opposite:

| Typical order | This book |
|---------------|-----------|
| Learn K8s theory in abstract | Install the control plane on *your* server first |
| Install a cluster in a lab chapter | See system pods Running on `hermes-controlplane-01` |
| Deploy an app to "learn Kubernetes" | Learn object types with simple examples—**not** Hermes |

**Why not wait for Part IV?** Part IV teaches *what* to schedule (Pods, Deployments, Services). Chapter 13 gives you *something that schedules*. Without a live control plane, Part IV is vocabulary without a machine. With k3s installed, every object you create in Part IV has immediate, observable consequences—the book **snaps into place**.

**Why not "Installing k3s"?** Titles that name tools describe steps. Titles that name outcomes describe transformation. You are not checking a box; you are giving Hermes infrastructure that can **reconcile desired state**—the prerequisite for running an agent, an inference server, and two databases as cooperating services.

**Why Docker is not the threshold:** Docker answers *how* to run one container. Hermes needs *many* containers that stay running, find each other, and upgrade without SSH surgery. Docker prepares the runtime; k3s provides the **agency** to operate a system.

:::note Why this matters for Hermes

Hermes, llama.cpp, PostgreSQL, and Redis are separate services—they need restart policies, service discovery, and declarative config. Running them as ad-hoc `docker run` commands does not scale to production. Kubernetes is how you **operate** a multi-service agent platform; k3s is how you learn it on one node without EKS overhead ([Chapter 6 design](../part-i-foundations/06-designing-the-hermes-platform.md)).

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain what a Kubernetes control plane does (API, scheduler, controller manager, etcd)
- [ ] Describe why k3s fits a single-node learning platform vs EKS
- [ ] Install k3s server mode on `hermes-controlplane-01`
- [ ] Verify node Ready status and system pods Running
- [ ] Use `kubectl` from the server and from your laptop
- [ ] Articulate the before/during/after state change: machine → incomplete install → scheduler with state
- [ ] Explain why application workloads wait until Part IV core objects are learned

---

## Prerequisites

- [Chapter 12: Building the Application Platform](12-building-the-application-platform.md) — Docker verified, `/data/docker` on `hermes-data`
- SSH and `controlplane.env` / `platform.env`

```bash
export AWS_PROFILE=hermes
source ~/hermes-platform/notes/controlplane.env
source ~/hermes-platform/notes/platform.env 2>/dev/null || true
KEY=~/.ssh/${HERMES_KEY_NAME}.pem
```

---

## Estimated Time

**90 minutes** — 40 minutes concept and design, 50 minutes install and verification.

---

## Background

### Concept — From Runtime to Scheduler

Docker answers: **How do I run this container?**

Kubernetes answers:

- Run **three** replicas of this container
- Keep them running if the node hiccups
- Expose them on a stable network name
- Roll out a new image without manual SSH
- Store configuration and secrets declaratively

That requires a **control plane**:

```text
You / CI  →  kubectl  →  API Server
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
               Scheduler  Controller  etcd
                    │         │      (state)
                    └────┬────┘
                         ▼
                    kubelet (on node)
                         ▼
                    containerd → Pods
```

Before k3s: you manually `docker run`.  
After k3s: you declare desired state; the platform reconciles reality.

### Why k3s on This Node?

| Option | Role in this book |
|--------|-------------------|
| **Amazon EKS** | Managed; hides control plane—learn later |
| **kubeadm** | Full K8s; heavier install |
| **k3s** | Single binary; production-capable; ideal for one-node Hermes platform |

k3s bundles control plane + kubelet + **containerd** (embedded). Docker from Chapter 12 remains for **build and test**; k3s pulls and runs workload images via its own containerd.

### What Changes on hermes-controlplane-01

| Component | After install |
|-----------|---------------|
| `k3s.service` | Runs control plane + agent |
| `/etc/rancher/k3s/k3s.yaml` | Admin kubeconfig |
| `/var/lib/rancher/k3s/` | Cluster state (etcd, data) |
| System pods | `coredns`, `metrics-server`, `local-path-provisioner`, etc. |

Disk: k3s state grows on **root volume**—monitor space; snapshots from [Chapter 11](11-persistent-storage.md) protect you.

---

## Theory

### Control Plane Components (What You Are Installing)

| Piece | Job |
|-------|-----|
| **API server** | Front door for `kubectl` and controllers |
| **Scheduler** | Assigns Pods to nodes |
| **Controller manager** | Reconciles desired vs actual (Deployments, etc.) |
| **etcd** | Cluster state database |
| **kubelet** | Runs Pods on this node via containerd |
| **Container runtime** | k3s embeds containerd for workloads |

You install one command (`curl get.k3s.io`). k3s wires these together—later Part IV chapters **open the hood** on each object type.

### Single-Node Server Mode

```text
hermes-controlplane-01
    │
    k3s server (control plane + worker)
    │
    ├── System namespace (kube-system)
    └── (your Pods later — Part IV)
```

No separate worker nodes yet. The scheduler always picks **this** node—correct for a personal platform.

### kubectl — Your Platform Remote Control

`kubectl` sends declarations to the API server:

```yaml
# Future chapter — not today
kind: Deployment
spec:
  replicas: 2
```

The cluster **converges** toward that declaration. Today you only verify the API is alive.

---

## Architecture

### Design — Platform Layer After k3s

```text
Layer 1  Infrastructure (Ch 7–11)   AWS + EC2 + storage + trust
Layer 2  Runtime (Ch 12)             Docker / OCI images
Layer 3  Orchestration (Ch 13+)      k3s → Pods → Deployments → …
Layer 4  Applications (Part VI+)     Hermes, llama.cpp, PostgreSQL, Redis
```

**Reading order:** Finish Layer 3 core objects before Layer 4.

Optional AWS polish ([Chapter 14](14-routing-traffic-to-hermes.md) DNS, [15](15-observing-hermes-platform.md) observability, [16](16-managing-platform-costs.md) cost) can wait until after Part IV or when you expose HTTPS.

### What Chapter 6 Predicted

In [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md), you designed the Hermes platform on paper—before any AWS resources existed. Chapter 13 is where that design becomes **physically observable**:

| Chapter 6 concept | What you see now |
|-------------------|------------------|
| Single-node architecture | k3s running locally on `hermes-controlplane-01` |
| Hermes as orchestrator | The Kubernetes API is now the real orchestrator—Hermes will register as a workload |
| llama.cpp as separate service | Will become a **scheduled** Pod, not a manual `docker run` |
| PostgreSQL / Redis | Will become **declarative** StatefulSets or Deployments with persistent volumes |
| Platform mindset (secure, observable, upgradeable) | Control plane state in etcd; rolling upgrades become possible in Part IV |

The book stops feeling linear here. It starts feeling **designed**—each infrastructure chapter was building toward a scheduler you can now touch.

### State Layers — A Lens for the Rest of the Book

Every platform chapter from here forward explains **where something lives** in this stack:

```text
Human Intent
    ↓
Kubernetes API (desired state)
    ↓
Scheduler
    ↓
Containers
    ↓
Linux Kernel
```

- **Part IV (Pods, Deployments, Services)** — objects at the API and scheduler layers
- **Part VI (Hermes, llama.cpp)** — application intent expressed as declarations
- **Infrastructure chapters (7–11)** — everything below the API, still running underneath

Return to this diagram when a new concept feels disconnected. Ask: *which layer am I operating at right now?*

---

## Walkthrough

### Implementation — Install k3s

#### Step 1 — Pre-flight on the Server

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
docker run --rm hello-world | tail -1
df -h / /data | tail -2
free -h
EOF
```

Ensure Docker still works and you have headroom (~32 GiB instance).

#### State 1 — Before k3s: Just a Machine

Pause and name what you have **before** changing it. Run this mental snapshot—or save it in your platform notes:

```text
hermes-controlplane-01

- Linux:        running
- Docker:       installed
- Networking:   configured
- Kubernetes:   does not exist

This is still a single-node server.
```

You SSH in, run commands, containers start when **you** start them. There is no cluster. There is no API that remembers desired state. There is no scheduler watching the node.

Everything you built in Chapters 7–12 is real—and it is **not yet a platform**.

#### Step 2 — Install k3s Server

#### State 2 — During Install: Incomplete

:::warning The system is incomplete

When the install script runs, hold this in mind:

> At this moment, there is no cluster.
> There is no API server you can trust yet.
> There is only a process being introduced into the system.

Copy/paste install is not instant Kubernetes. The binary downloads, systemd starts `k3s`, etcd initializes, the API server binds to port 6443, controllers begin reconciling—**in sequence**. If you run `kubectl` too early, you will get connection errors. That is correct behavior for an incomplete transition, not a mistake on your part.

:::

From laptop (review script first):

```bash
bash infrastructure/aws/cli/ch13-install-k3s.sh
```

Or on the server:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -
sudo systemctl enable k3s
```

`--write-kubeconfig-mode 644` lets the `ubuntu` user read `/etc/rancher/k3s/k3s.yaml` without sudo for read-only kubectl (optional hardening later).

#### Step 3 — Verify on the Server

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
sudo systemctl is-active k3s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
EOF
```

Expected:

- Node `hermes-controlplane-01` (or similar) **Ready**
- `kube-system` pods **Running** (coredns, metrics-server, local-path-provisioner, …)

This is your first look at cluster state—from **on the server**. Step 4 is where the ontology shift lands from your laptop.

#### Step 4 — kubectl from Your Laptop

```bash
mkdir -p ~/.kube
scp -i "$KEY" ubuntu@${HERMES_PUBLIC_IP}:/etc/rancher/k3s/k3s.yaml ~/.kube/hermes-k3s.yaml

# Replace localhost with public IP for remote access
sed -i.bak "s/127.0.0.1/${HERMES_PUBLIC_IP}/" ~/.kube/hermes-k3s.yaml
# macOS: sed -i '' "s/127.0.0.1/${HERMES_PUBLIC_IP}/" ~/.kube/hermes-k3s.yaml

export KUBECONFIG=~/.kube/hermes-k3s.yaml
echo "export KUBECONFIG=~/.kube/hermes-k3s.yaml" >> ~/hermes-platform/notes/platform.env

kubectl get nodes
kubectl get pods -A
```

#### State 3 — After First kubectl: Ontology Shift

Run `kubectl get pods -A` and read the output differently than every command before it in this book.

> This is the first time you are not inspecting the machine.
>
> You are now inspecting a **control plane that is managing the machine**.

You did not SSH in and start these pods. You did not run `docker run` for each one. The control plane declared them, scheduled them, and is reconciling them toward Running—continuously.

Example output (names may vary slightly by k3s version):

```text
NAMESPACE     NAME                                      READY   STATUS
kube-system   coredns-7b98449c4-xxxxx                     1/1     Running
kube-system   local-path-provisioner-84db5d44d9-xxxxx     1/1     Running
kube-system   metrics-server-67b6c879f5-xxxxx               1/1     Running
kube-system   traefik-c98fdf6fb-xxxxx                     1/1     Running
```

**The system is no longer a server. It is now a scheduler with state.**

That sentence is the click moment. Infrastructure chapters gave you pieces; this output is proof those pieces compose into **a system that acts on its own**. Everything in Part IV—and eventually Hermes—builds on this moment.

### Declarative Reality

Until now, you *ran commands*:

```bash
docker run ...
apt install ...
systemctl start ...
```

Each action was imperative—you told the machine what to do, once, directly.

From here forward, you *describe desired state* and the system reconciles reality:

```yaml
# Future chapter — not today
kind: Deployment
spec:
  replicas: 2
```

You submit that declaration to the API. Controllers watch. The scheduler assigns. The kubelet runs containers. If a Pod dies, the control plane notices the gap between desired and actual—and fixes it.

This is a different programming model. Kubernetes is not "another tool" like Docker. It is **declarative infrastructure**—the bridge to Deployments, ReplicaSets, Services, and eventually Hermes orchestrating tools and inference as cooperating scheduled workloads.

Return to the **State Layers** diagram when this feels abstract: your intent enters at the top; reconciliation flows down to containers and the Linux kernel.

**Security note:** The API listens on 6443. For learning, kubectl over the public IP uses TLS with admin credentials—equivalent to root on the cluster. Restrict source IP in Security Group when possible; [Chapter 14](14-routing-traffic-to-hermes.md) and hardening chapters tighten exposure.

#### Step 5 — Confirm Docker Still Works

k3s and Docker coexist:

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} 'docker run --rm hello-world | tail -1'
```

Both runtimes available—Docker for build, k3s containerd for orchestrated workloads.

#### Step 6 — Reboot Test

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} 'sudo reboot' || true
sleep 60
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
```

Node should return **Ready** without manual intervention.

---

## Hands-on Lab

### Lab 13: Install the First Control Plane

**Estimated Time:** 50 minutes

**Goal:** k3s running, node Ready, system pods healthy, kubectl works locally and from laptop.

**Steps:**

1. Record **State 1** snapshot (machine, no Kubernetes)
2. Pre-flight Docker and disk
3. Install k3s (script or manual)—notice **State 2** incompleteness while install runs
4. Verify node and `kube-system` pods on the server
5. Copy kubeconfig; run `kubectl get pods -A` from laptop—**State 3** ontology shift
6. Reboot test
7. Read [EDR-0006](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0006-single-node-k3s-control-plane.md)

**Do not** deploy Hermes, PostgreSQL, or llama.cpp in this lab.

---

## Verification

- [ ] **State 1** documented: server with Docker, no Kubernetes
- [ ] **State 2** understood: install is a transition, not instant magic
- [ ] **State 3** experienced: `kubectl get pods -A` shows control plane managing the node
- [ ] `k3s.service` active and enabled
- [ ] `kubectl get nodes` → **Ready**
- [ ] All `kube-system` pods **Running** (or Completed for jobs)
- [ ] `kubectl` from laptop with `KUBECONFIG=~/.kube/hermes-k3s.yaml`
- [ ] Docker hello-world still succeeds
- [ ] Cluster survives reboot
- [ ] No application workloads deployed yet

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| k3s install fails | Insufficient memory or ports in use | `free -h`; check 6443/10250 not bound |
| Node NotReady | CNI or containerd starting | Wait 2 min; `sudo journalctl -u k3s -n 50` |
| kubectl connection refused | Wrong IP in kubeconfig | Replace `127.0.0.1` with `HERMES_PUBLIC_IP`; open SG 6443 from your IP if needed |
| Docker broken after k3s | Rare socket conflict | Both should coexist; restart docker and k3s |
| Pods pending | First install still pulling | Wait; check `kubectl describe pod` |

---

## Review Questions

1. What is the difference between Docker (Ch 12) and k3s (Ch 13)?
2. What does the scheduler do?
3. Why single-node k3s instead of EKS?
4. Why defer Hermes until after Part IV core objects?
5. Where is cluster state stored?
6. Why two container runtimes (Docker + k3s containerd)?
7. Why install k3s in Part II instead of waiting for Part IV?
8. What changes in how you operate the platform after the "ontology shift"?
9. Name each layer in the State Layers stack.

---

## Key Takeaways

- **Three states:** before k3s = machine; during install = incomplete; after `kubectl` = scheduler with state
- **k3s is the first control plane**—the platform becomes alive, not just capable
- **Ontology shift:** `kubectl get pods -A` inspects a control plane managing the machine, not the machine itself
- **Declarative reality:** from here, describe desired state; the system reconciles—imperative SSH commands are no longer the primary model
- **State Layers** — Human Intent → API → Scheduler → Containers → Kernel (reuse in every Part IV+ chapter)
- **Chapter 6 pays off** — design on paper is now physically observable
- **Applications wait** — learn Pods, Deployments, Services, Ingress before Hermes

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Control plane** | Kubernetes components that manage cluster state and scheduling. |
| **k3s** | Lightweight certified Kubernetes distribution from Rancher/SUSE. |
| **kubelet** | Node agent that runs Pods via the container runtime. |
| **etcd** | Key-value store holding cluster configuration and state. |
| **kubectl** | CLI for the Kubernetes API. |
| **System pods** | Cluster infrastructure (DNS, metrics, storage provisioner). |
| **Declarative infrastructure** | Describe desired state; controllers reconcile actual state toward it. |
| **State Layers** | Human Intent → Kubernetes API → Scheduler → Containers → Linux Kernel. |

---

## Further Reading

- [k3s quick start](https://docs.k3s.io/quick-start)
- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [Part IV — Kubernetes](../part-iv-kubernetes/19-why-kubernetes-exists.md) — deepens theory while you work with objects

---

## Engineering Decision Record

**[EDR-0006: Single-node k3s as the Hermes control plane](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0006-single-node-k3s-control-plane.md)**

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

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

████████████░░░░░░░░░░ 65%
───────────────────────────────────────────────
```

The platform schedules. Next: learn what to schedule—and which **State Layer** each object occupies.

---

## The Boundary

> **From this point forward, we are no longer configuring a machine. We are operating a system.**

Chapter 13 is the only ontology shift at the platform layer. What follows **exercises** the control plane—visibility, manipulation, expansion—not new frameworks. Part IV begins by scheduling a Pod, not by re-explaining why Kubernetes exists.

---

## What's Next

[Chapter 20: Pods](../part-iv-kubernetes/20-pods.md) — exercise the scheduler. Deploy a simple container **not** Hermes; map the Pod to a **State Layer**. No second ignition moment—just hands-on control plane use.

Optional anytime (execution and refinement only): [Chapter 14 — Routing Traffic to Hermes](14-routing-traffic-to-hermes.md) (DNS/TLS), [15 — Observing the Platform](15-observing-hermes-platform.md) (*how do I see what it is doing?*), [16 — Managing Platform Costs](16-managing-platform-costs.md).

---

[← Chapter 12: Building the Application Platform](12-building-the-application-platform.md) | [Next: Chapter 20 — Pods →](../part-iv-kubernetes/20-pods.md)
