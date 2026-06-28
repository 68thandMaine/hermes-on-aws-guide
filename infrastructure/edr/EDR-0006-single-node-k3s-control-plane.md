# EDR-0006: Single-node k3s as the Hermes control plane

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 13 — The First Control Plane |
| **Date** | 2026-06-27 |

## Context

The Hermes platform needs a scheduler to run multiple containerized services (inference, databases, agents) with restarts, networking, and declarative config. Options include Amazon EKS, self-managed kubeadm, or lightweight k3s.

The book prioritizes **understanding** over managed abstraction. The reader already operates a single EC2 instance (`hermes-controlplane-01`) with Docker for image workflow.

## Decision

Install **k3s** in **single-node server mode** on `hermes-controlplane-01`. The k3s server embeds the Kubernetes control plane and runs workloads on the same node. `kubectl` access is configured for both on-node (`k3s kubectl`) and laptop (`KUBECONFIG` with public IP).

Hermes and application workloads deploy **only after** core Kubernetes objects are learned (Pods, Deployments, Services, Ingress, storage).

## Consequences

**Positive:**

- Full control plane visibility without EKS cost and complexity
- Same Kubernetes API used in production clusters
- Natural upgrade path to multi-node or EKS later
- Platform becomes **alive**—scheduling behavior exists before application deploy

**Negative:**

- Single point of failure—no HA control plane
- Control plane and workloads compete for CPU/RAM on one instance
- Operator must patch and backup k3s etcd/data (later chapters)

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Amazon EKS | Hides control plane; higher cost; premature for learning |
| kubeadm multi-component | Heavier install; more moving parts than k3s for one node |
| Docker Compose only | No Kubernetes API; weak path to production orchestration patterns |

## References

- [Chapter 13: The First Control Plane](../../docs/part-ii-aws/13-the-first-control-plane.md)
- [k3s documentation](https://docs.k3s.io/)
