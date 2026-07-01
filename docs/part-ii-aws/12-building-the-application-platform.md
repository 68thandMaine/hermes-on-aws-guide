---
sidebar_position: 12
description: "Transform hermes-controlplane-01 from a server into a container application platform."
---

# Chapter 12: Building the Application Platform

> Why does Kubernetes need a container runtime—and why prepare the OS before installing Kubernetes?

---

Until now, **`hermes-controlplane-01` was a server**—a trustworthy machine with storage, trust boundaries, and persistence.

After this chapter, it becomes a **platform**—a host that runs applications **predictably, consistently, and repeatedly**.

```text
Server                          Platform
    │                               │
Runs software manually            Runs applications in containers
SSH + apt + hope                  Images + runtime + repeatable deploys
```

You are no longer provisioning infrastructure. You are **building the application platform** everything else runs on.

This chapter is not "install Docker." It explains **why containers exist**, what a runtime does, and how to verify the platform before Kubernetes arrives.

:::note[Why this matters for Hermes]

Hermes, llama.cpp, PostgreSQL, and Redis will eventually run as orchestrated workloads—not as packages you `apt install` on Ubuntu. Containers package each service with its dependencies so the same image runs after a rebuild, a k3s upgrade, or a move to a second node. Docker is the on-ramp; Kubernetes is the conductor. **Hermes comes after the platform is ready**—not before.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why containers exist and what problem they solve
- [ ] Contrast virtual machines and containers at the resource and startup level
- [ ] Define container runtime, image, and registry—and how they relate
- [ ] Explain why Docker is installed when k3s will use **containerd** in production
- [ ] Describe immutable infrastructure and why it matters for the Hermes platform
- [ ] Install and verify Docker Engine on `hermes-controlplane-01` with storage on `hermes-data`
- [ ] Confirm the runtime survives reboot and runs without `sudo`

"Install Docker" is one step—not the subject.

---

## Prerequisites

- [Chapter 11: Persistent Storage for Models and Data](11-persistent-storage.md) — three volumes mounted; `/data` available
- SSH to `hermes-controlplane-01` as `ubuntu`
- `controlplane.env` sourced

```bash
export AWS_PROFILE=hermes
source ~/hermes-platform/notes/controlplane.env
KEY=~/.ssh/${HERMES_KEY_NAME}.pem
```

---

## Estimated Time

**90 minutes** — 45 minutes concept and design, 45 minutes implementation and verification.

---

## Background

### Concept — The Problem

> "It works on my machine."

Why?

- Different Node.js or Python versions
- Different OpenSSL or `glibc`
- Different system packages and library paths
- Environment variables and config files only on one laptop

The application is not isolated from the host. **Containers** package the application **with its runtime dependencies** into an image that runs the same way wherever the container runtime executes it.

Now Docker has a purpose—not as an end in itself, but as the **unit of deployment** your platform will orchestrate.

### Server → Platform

| Phase | Chapters | `hermes-controlplane-01` is… |
|-------|----------|------------------------------|
| Infrastructure | 7–11 | Secured server with persistent storage |
| **Platform** | **12–13 + Part IV** | **Container runtime + k3s + Kubernetes objects** |
| Applications | Part VI–VII | Hermes, llama.cpp, PostgreSQL, Redis |

**Strategic reading order:** Install and learn Kubernetes **before** deploying Hermes. Build infrastructure → platform → applications. That mirrors how production platform teams work and keeps the book maintainable as Hermes evolves independently of AWS and k3s details.

---

## Theory

### Virtual Machines vs Containers

**Virtual machine** — full guest OS on a hypervisor:

```text
Physical / EC2 host
    │
Hypervisor
    │
Virtual Machine
    ├── Guest OS (full kernel + userspace)
    └── Application
```

**Container** — shared host kernel, isolated process tree:

```text
Host Linux (hermes-controlplane-01)
    │
Container runtime (Docker / containerd)
    ├── Container A (process + filesystem layer)
    ├── Container B
    └── Container C
```

| | VM | Container |
|---|-----|-----------|
| Kernel | Own guest kernel | Shares host kernel |
| Startup | Minutes | Seconds |
| Overhead | GB RAM for guest OS | MB for process + layers |
| Isolation | Strong (hardware virtualized) | Strong (namespaces, cgroups) |

You already run a **VM** (EC2). Inside it, **containers** pack applications efficiently—that is why k3s can run Hermes, PostgreSQL, and Redis on one node without three full Ubuntu installs.

### Images — Blueprint, Not Container

An **image** is a **read-only blueprint** for creating containers.

- **Image** = template (layers, filesystem snapshot, metadata)
- **Container** = running instance of an image

Confusing the two causes Kubernetes mistakes later—a Deployment references an **image**; Pods run **containers** created from that image.

Images are **immutable** at rest: you do not `ssh` in and `apt upgrade` production containers. You build a **new image** and redeploy. That is **immutable infrastructure**—reduce drift, increase reproducibility.

### Registries — Trusted Sources

A **registry** stores and distributes images:

| Registry | Use |
|----------|-----|
| [Docker Hub](https://hub.docker.com/) | Public images (`hello-world`, base images) |
| GitHub Container Registry (ghcr.io) | Project and CI-published images |
| Amazon ECR | Private AWS-hosted images (production) |

Chapter 10 established **trust boundaries** for the network. Registries are the **trust boundary for software supply**:

- Prefer official or verified publishers
- Pin image **digests** in production—not floating `:latest` tags
- Scan images before deploy (later chapters)

### Why Docker If Kubernetes Uses containerd?

**k3s** runs **containerd** as the kubelet's container runtime—not the Docker daemon.

We install **Docker Engine** anyway because it provides:

| Capability | Why it matters |
|------------|----------------|
| Familiar CLI (`docker run`, `docker build`) | Learn images before kubectl abstractions |
| Build tooling | Buildx, Dockerfile workflow |
| Local testing | Run Postgres or llama.cpp in a container before k3s |
| OCI bridge | Same image format containerd pulls—images you build with Docker run on k3s |

Docker and containerd can coexist on Ubuntu. k3s installs its own containerd; Docker uses the system containerd.io package for its backend. You will use **Docker to learn and build**; **Kubernetes to run the platform**.

### Docker Storage and Chapter 11

Docker stores:

| Data | Default location | Our choice |
|------|------------------|------------|
| Images and layers | `/var/lib/docker` | **`/data/docker`** on `hermes-data` |
| Container writable layers | Under data-root | Same |
| Named volumes | Under data-root | Same |

**Design decision:** Set `"data-root": "/data/docker"` in `/etc/docker/daemon.json`.

**Why:** Image layers can grow to tens of GB with ML base images. Placing Docker on **`hermes-data`** keeps **`hermes-root`** free for OS, k3s, and logs—consistent with [Chapter 11](11-persistent-storage.md) separation of concerns.

**Tradeoff:** Docker and future PostgreSQL data share the data volume—monitor disk usage; expand `hermes-data` EBS if needed.

---

## Architecture

### Design — Platform Layer on hermes-controlplane-01

```text
hermes-controlplane-01
    │
    ├── hermes-root (/)           Ubuntu, k3s (later), system logs
    ├── hermes-models (/models)   GGUF files (not Docker images)
    ├── hermes-data (/data)       PostgreSQL (later), Docker data-root
    │
    └── Docker Engine
            ├── containerd (backend)
            ├── image layers → /data/docker
            └── containers (hello-world, future local tests)
```

Next platform milestone: **k3s** (Kubernetes)—orchestration above this runtime. **Hermes workloads deploy only after Kubernetes is operational.**

---

## Walkthrough

### Implementation — Install Docker Engine

Each step maps to **platform readiness**, not arbitrary package installs.

#### Step 1 — Connect and Update the Host

```bash
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP}
```

On the server (just-in-time Linux — `apt` when the platform needs it):

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

Platform readiness: security patches applied before running a persistent daemon.

#### Step 2 — Install Docker (Official Repository)

On the server, or from your laptop:

```bash
# From laptop — review infrastructure/aws/cli/ch12-install-docker.sh first
bash infrastructure/aws/cli/ch12-install-docker.sh
```

Manual equivalent on the server:

```bash
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Step 3 — Configure data-root and Log Rotation

```bash
sudo mkdir -p /data/docker

sudo tee /etc/docker/daemon.json <<'EOF'
{
  "data-root": "/data/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl enable docker
sudo systemctl restart docker
```

Log rotation prevents a noisy container from filling `/var/log` or Docker metadata.

#### Step 4 — Grant ubuntu Access to Docker

```bash
sudo usermod -aG docker ubuntu
```

Log out and SSH back in—or run `newgrp docker`—for group membership to apply.

**Authorization note:** Docker socket access is equivalent to root on the host. Only trusted users belong in the `docker` group—consistent with [Chapter 10](10-establishing-trust.md) trust model.

#### Step 5 — Verify Runtime

After reconnecting SSH:

```bash
docker --version
docker info | grep -E 'Docker Root Dir|Server Version'
systemctl is-enabled docker
systemctl is-active docker

docker run --rm hello-world
```

Expected: `Hello from Docker!` and `Docker Root Dir: /data/docker`.

#### Step 6 — Reboot Test

```bash
sudo reboot
# wait ~45s
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} 'docker run --rm hello-world && systemctl is-active docker'
```

---

## Hands-on Lab

### Lab 12: Build the Application Platform

**Estimated Time:** 45 minutes

**Goal:** Docker Engine running on `/data/docker`, hello-world succeeds, survives reboot, no sudo required.

**Steps:**

1. Complete Walkthrough Steps 1–6
2. Run full [Verification](#verification) checklist
3. Record `docker info` Root Dir in `~/hermes-platform/notes/platform.env`
4. Read [EDR-0005](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0005-containers-as-deployment-unit.md)

---

## Verification

- [ ] `docker.service` **enabled** and **active**
- [ ] `docker run hello-world` succeeds as `ubuntu` **without sudo**
- [ ] `Docker Root Dir` is `/data/docker`
- [ ] `/data/docker` on `hermes-data` volume (`df -h /data`)
- [ ] Log rotation configured in `daemon.json` (`max-size`, `max-file`)
- [ ] After reboot, Docker starts and hello-world runs
- [ ] `journalctl -u docker --no-pager -n 20` shows no critical errors
- [ ] k3s **not** installed yet

Only then is the platform ready for Kubernetes.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `permission denied` on docker.sock | User not in `docker` group | `sudo usermod -aG docker ubuntu`; re-login |
| Docker fails after daemon.json edit | Invalid JSON | `sudo journalctl -u docker`; fix `/etc/docker/daemon.json` |
| `/data/docker` on wrong filesystem | data-root typo | Fix daemon.json; migrate or reinstall with empty dir |
| hello-world pull timeout | No outbound HTTPS | Check SG, UFW outbound, VPC route to IGW |
| k3s conflicts later | Both manage containerd | k3s uses embedded containerd; Docker uses package—coexist on learning node |

---

## Review Questions

1. Why is "it works on my machine" a container problem?
2. How is a container different from the EC2 instance you already have?
3. What is the difference between an image and a container?
4. Why pin registries and digests in production?
5. Why install Docker if k3s uses containerd?
6. Why put Docker's data-root on `/data/docker`?
7. Why is Docker socket access sensitive?
8. Why learn Kubernetes before deploying Hermes?

---

## Key Takeaways

- **Server → platform** — containers turn `hermes-controlplane-01` into a repeatable application host
- **Images are blueprints** — immutable; rebuild and redeploy instead of patching live containers
- **Docker teaches; containerd runs** — same OCI images, different daemons
- **Storage intentional** — Docker on `hermes-data`, models on `/models`, OS on root
- **Layering:** Infrastructure (AWS) → Platform (Docker + k8s) → Applications (Hermes stack)
- **Hermes waits** until Kubernetes is operational

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Container** | Running instance of an image—isolated process with layered filesystem. |
| **Image** | Read-only template of filesystem layers and metadata used to create containers. |
| **Container runtime** | Software that runs containers (Docker Engine, containerd). |
| **Registry** | Service storing and distributing container images. |
| **OCI** | Open Container Initiative—standard image and runtime specifications. |
| **Immutable infrastructure** | Replace and redeploy rather than mutate running systems. |
| **data-root** | Docker daemon directory for images, layers, and volumes. |

---

## Further Reading

- [Docker Engine install — Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [OCI project](https://opencontainers.org/)
- [containerd vs Docker](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- Part III — deeper Docker, Compose, and OCI ([Chapter 16](../part-iii-containers/16-docker.md))

---

## Engineering Decision Record

**[EDR-0005: Adopt containers as the deployment unit](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0005-containers-as-deployment-unit.md)**

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
Container Runtime      ✓
OCI Images             ✓

Kubernetes             ✗
Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

███████████░░░░░░░░░░░ 55%
───────────────────────────────────────────────
```

The application platform runtime is ready. Kubernetes is next—not Hermes yet.

---

## What's Next

**Platform layer continues:** [Chapter 13 — The First Control Plane](13-the-first-control-plane.md) installs k3s—the scheduler that makes the platform **alive**. Then learn Pods, Deployments, Services, Ingress, and storage in [Part IV — Kubernetes](../part-iv-kubernetes/20-pods.md) with simple examples before any Hermes deploy.

Optional AWS polish ([Chapter 14](14-routing-traffic-to-hermes.md), [15](15-observing-hermes-platform.md), [16](16-managing-platform-costs.md)) can wait until you expose HTTPS or tune observability.

---

[← Chapter 11: Persistent Storage for Models and Data](11-persistent-storage.md) | [Next: Chapter 13 — The First Control Plane →](13-the-first-control-plane.md)
