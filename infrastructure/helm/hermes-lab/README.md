# Hermes lab stack (Chapter 34)

Minimal **system instantiation** — API, workers, model stub, Redis, PostgreSQL on k3s.

Stub images stand in for real Hermes and llama.cpp until [Chapter 36](../../../docs/part-vi-ai/36-model-serving.md) and Part VII.

## Prerequisites

- k3s + Traefik ([Chapter 13](../../../docs/part-ii-aws/13-the-first-control-plane.md))
- `local-path` storage ([Chapter 24](../../../docs/part-iv-kubernetes/24-kubernetes-storage.md))
- Optional: Ch 32–33 observability for verification

## Install

```bash
kubectl create namespace hermes --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install hermes-lab infrastructure/helm/hermes-lab \
  -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml
```

## Verify

```bash
kubectl get pods,svc,ingress -n hermes
curl -H "Host: hermes.local" http://<NODE_IP>/
```

Add to `/etc/hosts` or use curl `-H "Host: hermes.local"` against node IP ([Chapter 23](../../../docs/part-iv-kubernetes/23-ingress.md) pattern).

## Components

| Workload | Role | Real replacement |
|----------|------|------------------|
| `hermes-api` | External interface | Hermes API |
| `hermes-workers` | Task executors | Hermes worker pool |
| `hermes-model` | Inference (internal) | llama.cpp service |
| `hermes-redis` | Queue / cache | Production Redis |
| `hermes-postgres` | Durable state | Production PostgreSQL |
| `hermes-qdrant` | Semantic memory | Qdrant ([Chapter 35](../../../docs/part-vi-ai/35-vector-databases.md)) |

## Uninstall

```bash
helm uninstall hermes-lab -n hermes
kubectl delete pvc hermes-postgres-data -n hermes
```
