# Centralized logging (Chapter 33)

[Loki stack](https://github.com/grafana/helm-charts/tree/main/charts/loki-stack) — Promtail ships Pod logs to Loki.

## Install

Requires [Chapter 32](../monitoring/README.md) Grafana for query UI (this chart disables bundled Grafana).

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install logging grafana/loki-stack \
  -n logging --create-namespace \
  -f infrastructure/helm/logging/values-k3s-lab.yaml
```

## Add Loki to Grafana (Ch 32)

In Grafana → Connections → Data sources → Add **Loki**:

| Field | Value |
|-------|-------|
| URL | `http://logging-loki.logging.svc:3100` |
| Access | Server (default) |

Explore → pick Loki → run LogQL, e.g. `{namespace="default"}`.

## Tracing (optional)

[`../tempo/values-k3s-lab.yaml`](../tempo/values-k3s-lab.yaml) — minimal Tempo for trace storage. Full OpenTelemetry wiring lands with Hermes in Part VI.

## Demo manifests

- [`../../kubernetes/ch33-structured-log-demo-pod.yaml`](../../kubernetes/ch33-structured-log-demo-pod.yaml)
- [`../../kubernetes/ch33-otel-collector-lab.example.yaml`](../../kubernetes/ch33-otel-collector-lab.example.yaml)
