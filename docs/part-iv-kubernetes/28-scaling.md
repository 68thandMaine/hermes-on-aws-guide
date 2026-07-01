---
sidebar_position: 28
description: "HPA and scaling behavior under load on k3s."
---

# Chapter 28: Scaling

> Scaling is what happens when correctness meets load.

---

Structure is complete: Deployments, Services, Ingress, PVCs, Helm, Config, Security. This chapter is **behavior under constraints**—how the system reacts when demand exceeds steady-state assumptions.

Scaling is not “more Pods.” It is **feedback control over time**:

```text
observe load → compare target → change replica count → repeat
```

:::note[Why this matters for Hermes]

Hermes API and workers scale horizontally; inference may scale differently; PostgreSQL scales vertically. Without scaling, Hermes has fixed capacity. With HPA—and honest limits—you design for bursts, not just idle state.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Contrast manual scale, horizontal scale, and vertical scale
- [ ] Verify metrics-server and use `kubectl top`
- [ ] Configure HPA on `nginx-deployment`
- [ ] Simulate load and observe scale-out / scale-in
- [ ] Explain k3s single-node scaling limits on EC2
- [ ] Map scaling to the Deployment reconciliation loop from [Chapter 21](21-deployments.md)

---

## Prerequisites

- [Chapter 21: Deployments](21-deployments.md) — `nginx-deployment` (or reinstall via Helm `nginx-demo`)
- [Chapter 22: Services](22-services.md) — `nginx-service` reachable in-cluster
- [Chapter 27: Security](27-kubernetes-security.md) — if NetworkPolicy blocks load-gen Pods, allow or remove policy for this lab
- `KUBECONFIG` → k3s cluster

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get deployment nginx-deployment
kubectl get svc nginx-service
```

---

## Estimated Time

**90 minutes** — 20 minutes reading, 70 minutes hands-on (includes waiting for HPA reactions).

---

## Background

### The Problem

Your platform handles **steady desired state**. Real traffic is not steady:

- Bursts and spikes
- Sustained load periods
- Idle overnight

Something must adjust replica count (horizontal) or resources (vertical) when demand changes.

### Horizontal vs Vertical

| Type | Change | Best for |
|------|--------|----------|
| **Horizontal** | 1 → N Pods | Stateless APIs, Hermes workers behind Services |
| **Vertical** | More CPU/RAM per Pod | Databases, large model inference |

This chapter focuses on **horizontal** scaling via **HPA**. Vertical scaling on EC2 often means bigger instance types ([Chapter 11](../part-ii-aws/11-persistent-storage.md) data survives; compute changes).

### Manual Scale (Baseline)

```bash
kubectl scale deployment nginx-deployment --replicas=4
```

Explicit desired state mutation—**no feedback**. You watch load; you change the number. HPA automates that loop.

---

## Theory

### HPA Control Loop

HPA is a **second reconciler** on top of Deployments:

```text
metrics-server → HPA reads CPU/memory
       ↓
compare to target (e.g. 50% CPU)
       ↓
patch Deployment.spec.replicas
       ↓
Deployment controller creates/destroys Pods
       ↓
Service + Ingress routes to new Pods (Ch 22–23)
```

Same declarative pattern—new controller, not a new mental model.

### Metrics Requirement

HPA needs the **metrics API**. k3s installs **metrics-server** in `kube-system` ([Chapter 13](../part-ii-aws/13-the-first-control-plane.md)).

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top nodes
kubectl top pods
```

If `top` fails, wait 2–3 minutes after cluster boot or check metrics-server logs.

### CPU Requests Required

HPA CPU utilization is **usage ÷ requests**. Without `resources.requests.cpu` on containers, utilization is undefined and HPA may not scale.

---

## Architecture

### Scaling Depends on Earlier Layers

```text
Ingress → Service → Deployment → Pod
         ↑
    stable routing while Pod count changes
```

Without Services, clients would chase Pod IPs. Without Deployments, HPA has nothing to patch.

### k3s on EC2 Constraints

| Constraint | Effect |
|------------|--------|
| **Single node** | `maxReplicas` capped by CPU/RAM on `hermes-controlplane-01` |
| **Metrics lag** | 15–60s+ before HPA reacts |
| **Pending Pods** | Scale-out hits node limit → Pods Pending, not “elastic cloud” |
| **nginx idle CPU** | Low baseline—need **load generator** to trigger scale |

Scaling here is **delayed feedback control**, not instant hyperscaler elasticity.

---

## Walkthrough

### Step 1 — Verify metrics-server

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top nodes
```

### Step 2 — Add CPU Requests to nginx

Patch the Deployment so HPA has a signal:

```bash
kubectl patch deployment nginx-deployment --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources","value":{
    "requests":{"cpu":"100m","memory":"128Mi"},
    "limits":{"cpu":"200m","memory":"256Mi"}
  }}
]'
kubectl rollout status deployment/nginx-deployment
```

Rollout creates new Pods with requests defined.

### Step 3 — Manual Scale (Baseline)

```bash
kubectl scale deployment nginx-deployment --replicas=2
kubectl get pods -l app=nginx
```

You changed desired state directly—no automation.

### Step 4 — Create HPA

**[ch28-nginx-hpa.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch28-nginx-hpa.yaml)**

```bash
kubectl apply -f infrastructure/kubernetes/ch28-nginx-hpa.yaml
kubectl get hpa nginx-deployment
```

Or imperative:

```bash
kubectl autoscale deployment nginx-deployment --cpu-percent=50 --min=2 --max=6
```

Expected HPA fields: `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`.

### Step 5 — Generate Load

In-cluster traffic to the Service (adjust name if using `nginx-demo-service`):

```bash
SVC=nginx-service
kubectl run load-gen \
  --restart=Never \
  --image=busybox:1.36 \
  --labels="access=frontend" \
  -- sh -c "while true; do wget -q -O- http://${SVC}.default.svc.cluster.local/ >/dev/null 2>&1; done"
```

If NetworkPolicy from [Chapter 27](27-kubernetes-security.md) blocks traffic, label `load-gen` with `access=frontend` (as above) or remove the policy for this lab.

Watch scaling in separate terminals:

```bash
kubectl get hpa nginx-deployment -w
kubectl get pods -l app=nginx -w
kubectl top pods -l app=nginx
```

Over several minutes, replicas may **increase** toward `maxReplicas` as CPU rises above 50% of request.

### Step 6 — Remove Load and Observe Scale-In

```bash
kubectl delete pod load-gen
```

After cooldown, HPA should **decrease** replicas toward `minReplicas`—slower than scale-out.

### Step 7 — Inspect HPA Details

```bash
kubectl describe hpa nginx-deployment
```

Read Events: scaling reasons, current/target metrics.

### Step 8 — Cleanup

```bash
kubectl delete hpa nginx-deployment
kubectl scale deployment nginx-deployment --replicas=3
kubectl delete pod load-gen --ignore-not-found
```

---

## Hands-on Lab

### Lab 28: HPA Under Load

**Estimated Time:** 70 minutes

**Goal:** Trigger horizontal scale-out on k3s with simulated load.

**Steps:**

1. Confirm metrics-server and `kubectl top pods`
2. Patch nginx with CPU requests; rollout complete
3. Apply HPA min=2 max=6 target CPU 50%
4. Run `load-gen`; watch HPA and Pod count
5. Delete load-gen; watch scale-in
6. Record max replicas achieved on single node—note Pending Pods if any

---

## Verification

- [ ] `kubectl top pods` works
- [ ] HPA shows TARGETS and adjusts REPLICAS under load
- [ ] Service still returns 200 during scale (curl from allowed client Pod)
- [ ] You can explain manual scale vs HPA feedback loop
- [ ] You documented single-node limits for Hermes design notes

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| HPA `unknown` targets | No CPU requests on Pods | Patch Deployment resources |
| No scale-out | nginx idle; load too low | Keep load-gen running; lower target % |
| Pods Pending | Node CPU/RAM exhausted | Lower `maxReplicas`; bigger instance or multi-node later |
| Oscillation | Target too aggressive | Raise CPU target; increase min replicas |
| `top` fails | metrics-server not ready | `kubectl -n kube-system logs -l k8s-app=metrics-server` |
| Load cannot reach nginx | NetworkPolicy | Label `access=frontend` on load-gen |

### Scaling Signals (Beyond CPU)

| Signal | Source | Hermes use |
|--------|--------|------------|
| CPU | metrics-server | API workers |
| Memory | metrics-server | Inference pods |
| Custom | Prometheus adapter | Queue depth, latency |
| External | CloudWatch / custom | Business metrics |

Custom metrics come in [Chapter 32: Monitoring](../part-v-infrastructure/32-monitoring.md).

---

## Review Questions

1. What is the difference between `kubectl scale` and HPA?
2. Why does HPA require CPU requests?
3. Why is single-node k3s not “unlimited” horizontal scale?
4. Which Hermes components scale horizontally vs vertically?
5. What layer keeps clients stable while Pod count changes?

---

## Key Takeaways

- **Scaling = feedback control over time**, not provisioning
- **HPA** patches Deployment replicas from metrics-server signals
- **Services** make horizontal scale safe for clients
- **k3s on EC2** — delayed, capped elasticity; design accordingly
- Part IV Kubernetes stack is **behaviorally complete**; Part V+ builds Hermes on top

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **HPA** | Horizontal Pod Autoscaler—adjusts Deployment replicas from metrics. |
| **metrics-server** | Cluster component providing resource usage for kubectl top and HPA. |
| **scale-out / scale-in** | Increase / decrease replica count. |
| **feedback loop** | Observe → compare → act → repeat. |

---

## Further Reading

- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Resource metrics pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)

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
Deployments            ✓
Services               ✓
Ingress (HTTP)         ✓
Persistent K8s volumes ✓
Helm packaging         ✓
ConfigMaps / Secrets   ✓
RBAC / NetworkPolicy   ✓
HPA (scaling lab)      ✓

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

█████████████████████░ 94%
───────────────────────────────────────────────
```

Kubernetes platform layer: structurally and behaviorally complete under load.

---

## What's Next

[Chapter 29: Terraform](../part-v-infrastructure/29-terraform.md) — codify the AWS foundation you built manually in Part II.

Observability under load (Prometheus, Grafana, alerts) continues in [Chapter 32: Monitoring](../part-v-infrastructure/32-monitoring.md)—after IaC and CI/CD give you reproducible environments.

---

[← Chapter 27: Security](27-kubernetes-security.md) | [Next: Chapter 29 — Terraform →](../part-v-infrastructure/29-terraform.md)
