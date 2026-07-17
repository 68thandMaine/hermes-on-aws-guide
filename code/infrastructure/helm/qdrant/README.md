# Qdrant — Hermes semantic memory (Chapter 36)

Vector database for **meaning-aware retrieval** in the Hermes namespace.

## Install

Requires [hermes-lab](../hermes-lab/README.md) namespace (or create `hermes`).

```bash
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo update
helm upgrade --install hermes-qdrant qdrant/qdrant \
  -n hermes \
  -f code/infrastructure/helm/qdrant/values-k3s-lab.yaml
```

Service: `hermes-qdrant:6333` (HTTP API).

## Initialize collection

```bash
chmod +x code/infrastructure/aws/cli/ch36-init-hermes-memory-collection.sh
kubectl port-forward -n hermes svc/hermes-qdrant 6333:6333 &
./code/infrastructure/aws/cli/ch36-init-hermes-memory-collection.sh
```

## Retrieval demo

```bash
./code/infrastructure/aws/cli/ch36-vector-retrieval-demo.sh
```

## Three memory layers

| Store | Role |
|-------|------|
| PostgreSQL | Structured system state |
| Redis | Ephemeral coordination / queues |
| Qdrant | Semantic memory / similarity search |
