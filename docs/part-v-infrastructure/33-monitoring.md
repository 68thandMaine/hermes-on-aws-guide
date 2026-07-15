---
sidebar_position: 33
description: "Platform monitoring — Prometheus, Grafana, metrics, and alerts on k3s."
---

# Chapter 33: Monitoring

> A system you cannot observe is a system you cannot trust.

---

[Chapter 32](32-secrets-management.md) externalized credentials. The platform can now **deploy**, **scale**, and **authenticate**—but you still cannot answer:

> What is happening right now?

Without structured visibility, failures cascade silently, scaling is blind, and debugging becomes guesswork. This chapter adds the first **visibility layer** over your distributed system.

```text
Before:  kubectl get pods → binary "Running" vs "Not Running"
After:   metrics → dashboards → alerts → informed scaling and debugging
```

No new mental model—monitoring maps to **State Layers**: scrape signals from Nodes and Pods, store time series, compare against thresholds, feed HPA and humans.

:::note[Why this matters for Hermes]

Hermes is API + workers + inference + tools + memory. "All Pods Running" does not mean healthy latency, empty queues, or successful tool calls. Monitoring is how you distinguish **running** from **healthy** before users notice.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Distinguish monitoring, observability, metrics, logs, and traces
- [ ] Install kube-prometheus-stack on k3s via Helm
- [ ] Access Grafana and use Kubernetes dashboards
- [ ] Relate Prometheus metrics to [Chapter 29](../part-iv-kubernetes/29-scaling.md) HPA behavior
- [ ] Define a PrometheusRule alert for lab workloads
- [ ] Describe k3s single-node monitoring limitations honestly

---

## Prerequisites

- [Chapter 26](../part-iv-kubernetes/26-helm.md) — Helm installed
- [Chapter 29](../part-iv-kubernetes/29-scaling.md) — HPA + metrics-server (`kubectl top`)
- [Chapter 32](32-secrets-management.md) — secrets externalized (monitoring stack is separate)
- k3s cluster with sufficient RAM (monitoring adds ~1–2 GiB)

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
helm version
kubectl top nodes    # metrics-server from Ch 29
```

---

## Estimated Time

**90 minutes** — 25 minutes reading, 65 minutes install + Grafana + alert lab.

---

## Background

### The Problem

At this point:

| Capability | Status |
|------------|--------|
| Provision (Terraform + CI) | ✓ |
| Run workloads (Kubernetes) | ✓ |
| Scale (HPA) | ✓ |
| Secure credentials (Secrets Manager + ESO) | ✓ |
| **See system behavior under load** | ✗ |

Failures become visible only when Ingress returns 502 or SSH shows a full disk. Performance degradation stays anecdotal ("felt slow yesterday").

### Monitoring vs Observability

| Term | Meaning |
|------|---------|
| **Monitoring** | Predefined signals, dashboards, alerts you expect |
| **Observability** | Ability to infer internal state from outputs (includes ad-hoc questions) |

This chapter is **monitoring**—the foundation. [Chapter 34](34-logging.md) adds logs (and tracing concepts) for event reconstruction.

### The Three Pillars

| Pillar | Form | This chapter |
|--------|------|--------------|
| **Metrics** | Numeric time series (CPU, latency, QPS) | **Primary focus** — Prometheus |
| **Logs** | Discrete event streams | Chapter 34 |
| **Traces** | Request path across services | Chapter 34 (intro) |

### metrics-server vs Prometheus

Both appear in a healthy cluster—they are **not duplicates**:

| | metrics-server | Prometheus |
|---|----------------|------------|
| **Purpose** | Short-term metrics for `kubectl top` and **HPA** | Long-term TSDB, dashboards, alerts |
| **Retention** | Minutes | Days/weeks (configurable) |
| **Introduced** | [Chapter 29](../part-iv-kubernetes/29-scaling.md) | This chapter |

```text
metrics-server  →  HPA decisions (Ch 29)
Prometheus      →  human + alert visibility (Ch 33)
```

---

## Architecture

### Stack Overview

```text
Kubernetes (k3s)
        ↓
node-exporter + kube-state-metrics + cAdvisor (via kubelet)
        ↓
Prometheus (scrape + store)
        ↓
Grafana (visualize)     Alertmanager (notify)
```

**kube-prometheus-stack** (Helm chart) installs the above as one unit—same packaging pattern as [Chapter 26](../part-iv-kubernetes/26-helm.md).

### Extended System

```text
Terraform → GitHub Actions → AWS → Secrets Manager
        ↓
k3s → Kubernetes workloads
        ↓
Monitoring (Prometheus / Grafana)  ← this chapter
        ↓
Hermes (application metrics — Part VI)
```

AWS-level visibility ([Chapter 15](../part-ii-aws/15-observing-hermes-platform.md) CloudWatch) complements this; **in-cluster metrics** are the focus here because Hermes runs on Kubernetes.

### k3s Reality

On single-node EC2 + k3s:

- Metrics are **coarse-grained** (one node = entire cluster)
- Prometheus competes for CPU/RAM with Hermes and inference
- **Best-effort truth**, not datacenter-grade precision
- Persistence requires explicit PVC strategy ([Chapter 25](../part-iv-kubernetes/25-kubernetes-storage.md) `local-path`)

Plan monitoring footprint when sizing the control plane ([Chapter 9](../part-ii-aws/09-provisioning-hermes-server.md)).

---

## Walkthrough

### Step 1 — Install kube-prometheus-stack

The repo ships lab-tuned values at `infrastructure/helm/monitoring/values-k3s-lab.yaml`:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f infrastructure/helm/monitoring/values-k3s-lab.yaml
```

Wait for pods:

```bash
kubectl get pods -n monitoring
kubectl get servicemonitor -A | head
```

Installed components include Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics.

### Step 2 — Access Grafana

Port-forward (lab pattern—Ingress optional later):

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Open http://localhost:3000

| Field | Value |
|-------|-------|
| User | `admin` |
| Password | From Helm values, or retrieve: |

```bash
kubectl get secret -n monitoring monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

Change the default password in production—lab values use a placeholder in `values-k3s-lab.yaml`.

### Step 3 — Explore Cluster Dashboards

In Grafana → **Dashboards** → browse Kubernetes / Node / Pod dashboards.

Verify against known state:

| Dashboard signal | Cross-check |
|------------------|-------------|
| Node CPU/memory | `kubectl top nodes` |
| Pod count for nginx-demo | `kubectl get pods -l app=nginx` |
| HPA current replicas | `kubectl get hpa nginx-hpa` |

You are learning to read **time series**, not snapshots.

### Step 4 — Connect to Chapter 29 Scaling

Re-run the [Chapter 29](../part-iv-kubernetes/29-scaling.md) load lab while watching Grafana:

1. Deploy or ensure `nginx-hpa` and load generator exist
2. Open **Kubernetes / Compute Resources / Pod** dashboard
3. Filter to `nginx-demo` Pods
4. Start load; watch CPU rise, HPA scale out, replica count climb

```text
Metrics (Prometheus)  →  confirm what HPA (metrics-server) decided
```

Without monitoring, scaling is **blind automation**—replicas change but you do not see saturation or contention on the node.

### Step 5 — Application Metrics (Hermes Bridge)

Infrastructure metrics (CPU, memory, restarts) are necessary—not sufficient. Hermes will expose **application metrics** on `/metrics` (Prometheus exposition format):

```text
hermes_request_duration_seconds
hermes_active_tasks
hermes_tool_invocations_total
```

Pattern (Part VI):

```text
Hermes API Pod :9090/metrics  →  ServiceMonitor  →  Prometheus scrape
```

Example template: `infrastructure/kubernetes/ch33-servicemonitor-hermes-bridge.example.yaml`

nginx-demo does not export app metrics by default—use cluster dashboards for this lab; wire ServiceMonitors when Hermes lands.

### Step 6 — Alerting (Failure Detection)

Apply lab rules linking monitoring to HPA:

```bash
kubectl apply -f infrastructure/kubernetes/ch33-prometheusrule-hermes-lab.yaml
```

Example rule (from manifest):

```yaml
- alert: NginxDemoHighCPU
  expr: |
    sum by (namespace, pod) (
      rate(container_cpu_usage_seconds_total{namespace="default", pod=~"nginx-demo.*"}[5m])
    ) > 0.5
  for: 2m
```

Alerts flow: **Prometheus → Alertmanager → (notification channel)**

Notification channels (Slack, PagerDuty, email) are configuration—not required for the lab. View firing alerts in Alertmanager UI:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

### Step 7 — Prometheus UI (Optional)

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Run PromQL—for example, node memory pressure:

```promql
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
```

Prometheus is the **source of truth for metrics**; Grafana is the human layer.

---

## Hands-on Lab

### Lab 32: Platform Visibility

**Estimated Time:** 65 minutes

**Goal:** Install monitoring stack; correlate Grafana metrics with HPA scale event.

**Steps:**

1. Install kube-prometheus-stack with `values-k3s-lab.yaml`
2. Port-forward Grafana; log in; open Node and Pod dashboards
3. Record baseline CPU for nginx-demo at idle
4. Run Ch 29 load generator; watch HPA and Grafana concurrently
5. Apply `ch33-prometheusrule-hermes-lab.yaml`; trigger high CPU; check Alertmanager
6. Document one metric you would watch for Hermes API latency (future)

---

## Verification

- [ ] All `monitoring` namespace pods Running
- [ ] Grafana accessible via port-forward
- [ ] Node and Pod CPU visible during load test
- [ ] HPA scale-out visible in kube-state-metrics / Grafana
- [ ] PrometheusRule applied; alert visible when threshold exceeded
- [ ] You can explain metrics-server vs Prometheus

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pods Pending in `monitoring` | Insufficient node RAM | Reduce Prometheus limits in values; bigger instance |
| Grafana login fails | Wrong secret | Retrieve password from K8s secret (Step 2) |
| Empty dashboards | Scrape not ready | Wait 2–3 min; check `kubectl get prometheus -n monitoring` |
| Alerts not firing | Wrong `release` label on PrometheusRule | Label `release: monitoring` must match Helm release name |
| Prometheus OOMKilled | Retention/cardinality too high | Lower retention; avoid high-cardinality labels |
| "Healthy" but users unhappy | No app-level metrics | Add `/metrics` + ServiceMonitor for Hermes |

### Failure Modes

**Missing metrics** — ServiceMonitor selector mismatch or Pod not exposing `/metrics`.

**Overloaded Prometheus** — High-cardinality labels (per-user IDs) explode TSDB size. Keep labels low-cardinality.

**False confidence** — All probes green while queue depth grows—infra metrics without app metrics.

**Single-node blind spot** — Node metrics look fine while disk I/O on `/data` saturates—instrument EBS and app SLOs ([Chapter 11](../part-ii-aws/11-persistent-storage.md)).

---

## Review Questions

1. What is the difference between monitoring and observability?
2. Why keep metrics-server if Prometheus is installed?
3. How does monitoring make HPA less "blind"?
4. What Hermes signals would you add beyond CPU and memory?
5. Why is k3s single-node monitoring "best-effort truth"?

---

## Key Takeaways

- **Monitoring** provides structured visibility—running ≠ healthy
- **Prometheus** is the metrics engine; **Grafana** is the human interface
- **metrics-server** feeds HPA; **Prometheus** feeds humans and alerts
- **Alerts** encode failure detection as code
- **k3s on EC2** limits precision—size and scope accordingly
- **Hermes** needs application metrics on `/metrics`, not just kube-state-metrics
- Observability spans **Kubernetes + infrastructure** ([Chapter 15](../part-ii-aws/15-observing-hermes-platform.md) AWS + this chapter in-cluster)

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Metric** | Numeric measurement over time (counter, gauge, histogram). |
| **Prometheus** | Pull-based TSDB that scrapes `/metrics` endpoints. |
| **Grafana** | Dashboard and visualization layer over Prometheus (and others). |
| **ServiceMonitor** | CRD telling Prometheus which Services to scrape. |
| **PrometheusRule** | CRD defining recording and alerting rules. |
| **Alertmanager** | Routes and deduplicates alerts from Prometheus. |

---

## Further Reading

- [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus documentation](https://prometheus.io/docs/)
- [Grafana Kubernetes dashboards](https://grafana.com/grafana/dashboards/)
- [Chapter 29: Scaling](../part-iv-kubernetes/29-scaling.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS + Terraform + CI     ✓
Secrets (external)       ✓
Kubernetes platform      ✓

Prometheus + Grafana     ✓
App metrics (Hermes)     ◐ (Part VI)
Centralized logging      ✓
Tracing (OTel/Tempo)     ◐ (lab / Part VI)

Hermes application       ✗
───────────────────────────────────────────────
```

Part V: codify → automate → secure → **observe**.

---

## What's Next

[Chapter 34: Logging](34-logging.md) — centralized logs and request-flow reconstruction (tracing concepts) so you can debug individual events, not only aggregate metrics.

---

[← Chapter 32: Secrets Management](32-secrets-management.md) | [Next: Chapter 34 — Logging →](34-logging.md)
