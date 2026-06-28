---
sidebar_position: 33
description: "Centralized logging and tracing — Loki, Promtail, LogQL, and OpenTelemetry on k3s."
---

# Chapter 33: Logging & Tracing

> Metrics tell you the system is wrong.
>
> Logs tell you what went wrong.
>
> Traces tell you why it went wrong.

---

[Chapter 32](32-monitoring.md) added **state visibility**—CPU curves, replica counts, alerts. You can see *that* something is wrong. You still cannot reconstruct:

> Which request caused it, and what path did it take?

This chapter adds **event history** (logs) and **causality** (traces)—the second half of observability.

```text
Before:  high CPU on a dashboard → guess which workload
After:   LogQL filter → trace_id → span tree → root cause
```

No new mental model—logs and traces are **State Layers** outputs: discrete events and request paths materialized from running Pods, federated into queryable stores.

:::note Why this matters for Hermes

Hermes executes tool chains, model calls, and memory lookups across multiple steps. Metrics show latency rising; logs show *which tool timed out*; traces show *the full execution graph*. Without all three, Hermes is a black box.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Distinguish metrics, logs, and traces by the questions they answer
- [ ] Deploy Loki + Promtail and query logs in Grafana
- [ ] Write basic LogQL filters for workloads
- [ ] Explain structured logging and `trace_id` correlation
- [ ] Describe OpenTelemetry spans and the collector → Tempo pipeline
- [ ] Correlate logs, metrics, and traces in Grafana
- [ ] Apply honest k3s retention and volume constraints

---

## Prerequisites

- [Chapter 32](32-monitoring.md) — Grafana + Prometheus running (`monitoring` namespace)
- [Chapter 25](../part-iv-kubernetes/25-helm.md) — Helm
- k3s cluster with headroom for Loki (~512 MiB additional)

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n monitoring
helm version
```

---

## Estimated Time

**90 minutes** — 30 minutes reading, 60 minutes logging lab + tracing concepts.

---

## Background

### The Problem

You can already see:

- CPU is high ([Chapter 32](32-monitoring.md))
- HPA scaled out ([Chapter 28](../part-iv-kubernetes/28-scaling.md))
- Pods restarted

You cannot yet see:

- Which request triggered the scale event
- Whether failure was API, worker, model, or external tool
- Order of operations inside a single Hermes interaction

Gap:

> **No event reconstruction across distributed components**

### Logs vs Metrics vs Traces

| Type | Question | Example |
|------|----------|---------|
| **Metrics** | Is something wrong? | `hermes_request_duration_seconds` p99 up |
| **Logs** | What happened? | `{"event":"tool_call","tool":"weather_api","error":"timeout"}` |
| **Traces** | Why / in what order? | Span: API → worker → inference → tool (230ms) |

[Chapter 32](32-monitoring.md) covered metrics. This chapter completes the triad.

### Monitoring vs Event Reconstruction

```text
Monitoring (Ch 32)     →  aggregate state over time
Logging (Ch 33)        →  discrete events with context
Tracing (Ch 33)        →  request lifecycle across services
```

Together: **observability correlation**:

```text
Alert (metric)  →  LogQL (events in window)  →  Trace (span tree)
```

### Centralized Logging Architecture

```text
Pod stdout/stderr
        ↓
Promtail (DaemonSet — discovers Pods, attaches labels)
        ↓
Loki (log aggregation — indexed by labels, not full text)
        ↓
Grafana Explore (LogQL queries)
```

**Loki** is label-centric (like Prometheus for logs)—efficient on k3s when you filter by `{namespace, app}` rather than full-text indexing everything.

---

## Architecture

### Stack Placement

```text
Terraform → GitHub Actions → AWS → Secrets
        ↓
k3s → Workloads
        ↓
Prometheus (metrics)  +  Loki (logs)  +  Tempo (traces, optional)
        ↓
Grafana (single pane — Ch 32 UI, Ch 33 datasources)
        ↓
Hermes (structured logs + OTLP spans — Part VI)
```

AWS logs ([Chapter 15](../part-ii-aws/15-observing-hermes-platform.md) CloudWatch) cover the **node and account**. Loki covers **workload stdout** inside the cluster. Both matter; this chapter focuses in-cluster.

### k3s Reality

On single-node EC2:

- Log volume competes with Hermes and Prometheus for disk and RAM
- **Short retention** (72h lab default)—intentionally bounded visibility
- Tracing adds overhead—start with sampling in production
- Promtail reads container logs from the node filesystem—works on k3s like any Kubernetes

---

## Walkthrough

### Step 1 — Install Loki Stack

Reuse Grafana from [Chapter 32](32-monitoring.md)—disable bundled Grafana in the logging chart:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install logging grafana/loki-stack \
  -n logging \
  --create-namespace \
  -f infrastructure/helm/logging/values-k3s-lab.yaml
```

Verify:

```bash
kubectl get pods -n logging
kubectl get svc -n logging
```

Expected: `logging-loki-*` and `logging-promtail-*` Running.

### Step 2 — Connect Loki to Grafana

Port-forward Ch 32 Grafana if needed:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Add datasource: **Connections → Data sources → Add Loki**

| Field | Value |
|-------|-------|
| URL | `http://logging-loki.logging.svc:3100` |
| Access | Server (default) |

Save & test. Optionally add **Derived fields** linking `trace_id` in logs to Tempo (Step 6).

### Step 3 — Log Collection Model

Every container writes to **stdout/stderr**. Promtail:

1. Discovers Pods via Kubernetes API
2. Tails log files on the node
3. Attaches labels: `namespace`, `pod`, `container`, Pod labels
4. Pushes streams to Loki

No application code changes required for basic collection—your existing nginx-demo and config-demo Pods already emit logs Loki can ingest.

### Step 4 — Query with LogQL

Grafana → **Explore** → datasource **Loki**.

All logs in default namespace:

```logql
{namespace="default"}
```

nginx-demo Pods:

```logql
{namespace="default", pod=~"nginx-demo.*"}
```

Error filter (works best with structured JSON or consistent text):

```logql
{namespace="default"} |= "error" or {namespace="default"} | json | level="error"
```

Time-bounded troubleshooting (use Grafana time picker +):

```logql
{namespace="default"} |~ "timeout|failure|ERROR"
```

Compare to Prometheus in the same Explore split view—metric spike + log lines in the same window.

### Step 5 — Structured Logging Demo

Apply the structured log emitter:

```bash
kubectl apply -f infrastructure/kubernetes/ch33-structured-log-demo-pod.yaml
```

The Pod prints JSON lines:

```json
{"level":"info","event":"tool_call","tool":"weather_api","latency_ms":130,"trace_id":"trace-...","request_id":"req-1"}
```

Query in Loki:

```logql
{app="hermes-log-demo"} | json | event="tool_call"
```

Filter errors:

```logql
{app="hermes-log-demo"} | json | level="error"
```

**Hermes requirement:** emit JSON with stable fields (`level`, `event`, `trace_id`, `request_id`)—not unparsed strings.

### Step 6 — Tracing Concepts (OpenTelemetry)

A **trace** is one request's journey across services:

```text
User request
  → Ingress (Traefik)
    → Hermes API
      → Worker
        → Model inference
          → External tool API
```

Each step is a **span**. Spans share a `trace_id`; nested spans form a tree.

Hermes (Part VI) will emit spans like:

```text
trace_id: abc123
  span: api_request
  span: tool_execution
  span: model_inference
```

**Pipeline:**

```text
Application (OTLP)  →  OpenTelemetry Collector  →  Tempo (storage)  →  Grafana
```

### Step 7 — Optional Tempo Install (Lab)

Minimal trace backend:

```bash
helm upgrade --install tempo grafana/tempo \
  -n logging \
  -f infrastructure/helm/tempo/values-k3s-lab.yaml
```

Add Grafana datasource **Tempo** → URL `http://tempo.logging.svc:3100`

Full collector manifest pattern: `infrastructure/kubernetes/ch33-otel-collector-lab.example.yaml` (commented—wire when Hermes exports OTLP).

For this chapter, understanding the **model** matters more than running production trace volume on single-node k3s.

### Step 8 — Correlation Model

Connect signals in Grafana:

| Signal | Link |
|--------|------|
| **Metric** | HPA scale / latency alert fires |
| **Logs** | LogQL in alert window: `{app="hermes"} \| json \| trace_id="abc123"` |
| **Trace** | Tempo search by `trace_id` → span waterfall |

```text
trace_id  ──→  logs (what each step logged)
          ──→  metrics (node CPU during trace timestamp)
```

Without `trace_id` in logs, correlation devolves to timestamp guessing.

### Step 9 — Part V Observability Complete

```text
Deploy  →  Secure  →  Scale  →  Observe state  →  Observe events
  Ch29–30   Ch31      Ch28       Ch32              Ch33
```

Part VI adds **Hermes application** instrumentation on this substrate.

---

## Hands-on Lab

### Lab 33: Event Reconstruction

**Estimated Time:** 60 minutes

**Goal:** Centralize Pod logs; query structured JSON; walk correlation workflow.

**Steps:**

1. Install `logging` Helm release with `values-k3s-lab.yaml`
2. Add Loki datasource to Ch 32 Grafana
3. Run `{namespace="default"}` — confirm nginx-demo or system logs appear
4. Apply `ch33-structured-log-demo-pod.yaml`
5. LogQL: `{app="hermes-log-demo"} | json | event="tool_call"`
6. Optional: install Tempo; review `ch33-otel-collector-lab.example.yaml`
7. Write one paragraph: how you would debug a Hermes tool timeout using metrics + logs + traces

---

## Verification

- [ ] Loki and Promtail pods Running in `logging` namespace
- [ ] Loki datasource connected in Grafana
- [ ] LogQL returns logs for default namespace workloads
- [ ] Structured demo Pod logs parse with `| json`
- [ ] You can explain metrics vs logs vs traces
- [ ] You understand bounded retention on k3s

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| No logs in Loki | Promtail not ready | `kubectl logs -n logging -l app=promtail` |
| Grafana Loki error | Wrong URL | Use cluster DNS `http://logging-loki.logging.svc:3100` |
| Empty `{namespace="default"}` | Time range / no workloads | Widen time picker; generate log traffic |
| JSON parse fails | Non-JSON lines mixed in | Filter `\| json` only on structured apps |
| Loki OOM | Retention / volume too high | Lower `retention_period` in values |
| Traces missing | OTLP not exported yet | Expected until Hermes Part VI |

### Failure Modes

**Log explosion** — Debug verbosity at `info` on every request fills disk. Use levels; sample debug logs.

**Missing correlation IDs** — Logs without `trace_id` cannot link to Tempo. Enforce in Hermes logging middleware.

**Sampling gaps** — 100% trace capture is expensive. Sample head or tail in production; keep errors always.

**False confidence from metrics** — CPU normal while logs show repeated tool failures—need app-level log fields.

---

## Review Questions

1. What question does each pillar (metrics, logs, traces) answer?
2. Why does Loki index labels, not full log text?
3. Why reuse one Grafana for Prometheus and Loki?
4. What fields should Hermes JSON logs include at minimum?
5. Why is observability "intentionally bounded" on k3s?

---

## Key Takeaways

- **Logs describe events; metrics describe state; traces describe causality**
- **Loki + Promtail** centralize Kubernetes workload logs
- **LogQL** filters by labels and parses structured JSON
- **Structured logging** with `trace_id` enables correlation
- **OpenTelemetry + Tempo** model request paths—full wiring with Hermes in Part VI
- **Observability is a design constraint**, not a bolt-on tool
- Part V substrate is complete: deploy, secure, scale, observe state, observe events

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **LogQL** | Loki's query language (label selectors + filters + parsers). |
| **Promtail** | Agent that ships Pod logs to Loki with Kubernetes metadata. |
| **Structured logging** | JSON (or key-value) logs with stable fields for filtering. |
| **Trace** | End-to-end record of one request across services. |
| **Span** | Single operation within a trace (has timing, parent/child). |
| **OpenTelemetry (OTLP)** | Vendor-neutral instrumentation and export protocol for traces/metrics/logs. |
| **trace_id** | Correlation identifier linking logs and spans. |

---

## Further Reading

- [Grafana Loki documentation](https://grafana.com/docs/loki/latest/)
- [LogQL query examples](https://grafana.com/docs/loki/latest/query/)
- [OpenTelemetry documentation](https://opentelemetry.io/docs/)
- [Grafana Tempo](https://grafana.com/docs/tempo/latest/)
- [Chapter 32: Monitoring](32-monitoring.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Infrastructure (TF + CI)  ✓
Secrets (external)        ✓
Kubernetes platform       ✓

Metrics (Prometheus)      ✓
Logs (Loki)               ✓
Traces (Tempo / OTel)     ◐ (lab / Part VI)
Hermes instrumentation    ◐ (Part VI)

Hermes application        ✗
───────────────────────────────────────────────
```

Part V complete. Part VI begins: **run Hermes on the instrumented substrate**.

---

## What's Next

[Chapter 34: Running Hermes](../part-vi-ai/34-running-hermes.md) — assemble and run the Hermes agent on everything built so far.

---

[← Chapter 32: Monitoring](32-monitoring.md) | [Next: Chapter 34 — Running Hermes →](../part-vi-ai/34-running-hermes.md)
