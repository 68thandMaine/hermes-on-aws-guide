# Monitoring stack (Chapter 33)

Helm values for [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) on single-node k3s.

## Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f code/infrastructure/helm/monitoring/values-k3s-lab.yaml
```

## Access Grafana

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# http://localhost:3000 — user admin; password from values or secret
kubectl get secret -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

## Related manifests

- [`../../kubernetes/ch33-prometheusrule-hermes-lab.yaml`](../../kubernetes/ch33-prometheusrule-hermes-lab.yaml) — lab alerts tied to Ch 29 HPA
- [`../../kubernetes/ch33-servicemonitor-hermes-bridge.example.yaml`](../../kubernetes/ch33-servicemonitor-hermes-bridge.example.yaml) — Hermes `/metrics` pattern

## k3s note

**metrics-server** (Ch 29 `kubectl top`, HPA) and **Prometheus** (this chapter) serve different roles — both stay installed.
