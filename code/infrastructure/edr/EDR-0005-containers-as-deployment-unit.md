# EDR-0005: Adopt containers as the deployment unit

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 12 — Building the Application Platform |
| **Date** | 2026-06-27 |

## Context

Hermes, llama.cpp, PostgreSQL, Redis, and future internal APIs must run consistently on `hermes-controlplane-01` and in any environment rebuilt from this book. Manual installation on the host OS produces "works on my machine" drift—different package versions, conflicting libraries, and irreproducible upgrades.

## Decision

Standardize on **OCI-compatible container images** as the packaging and deployment format. Install **Docker Engine** on the control plane for image management, local testing, and build tooling. Kubernetes (k3s) will use **containerd** as the production runtime; Docker shares the same image format and registry ecosystem.

Docker `data-root` is set to `/data/docker` on the `hermes-data` volume to avoid filling the root disk with image layers.

## Consequences

**Positive:**

- Applications become portable and reproducible across rebuilds
- Runtime dependencies live inside images, reducing host configuration drift
- Natural path to Kubernetes Pods, Deployments, and Helm charts
- Aligns with production platform engineering practice

**Negative:**

- Additional daemon to maintain (Docker + later containerd under k3s)
- Image layers consume disk—mitigated by data volume placement and log rotation
- Readers must understand Docker vs containerd roles to avoid confusion

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Install packages directly on Ubuntu | High drift; conflicts with k3s workload isolation |
| containerd only (skip Docker) | Harder learning curve; weaker local build/test UX for Part III |
| Podman rootless only | Less common in k8s learning paths; weaker Docker Compose bridge |

## References

- [Chapter 12: Building the Application Platform](../../../docs/part-ii-aws/12-building-the-application-platform.md)
- [OCI specification](https://opencontainers.org/)
