---
sidebar_position: 26
description: "ConfigMaps and Secrets — separate code from configuration and credentials."
---

# Chapter 26: Configuration (ConfigMaps & Secrets)

> Code defines behavior.
>
> Configuration defines reality.

---

Helm packages systems ([Chapter 25](25-helm.md)). Before RBAC and network policy, you need something worth protecting: **runtime configuration** decoupled from images and YAML hardcoding.

This chapter is the shift from *infrastructure objects* to **application composition**—how Hermes will receive model settings, API endpoints, and credentials without rebuilding containers.

```text
Chapter 25   Helm        →  install the system
Chapter 26   Config/Secret →  parameterize the system
Chapter 27   Security    →  who may change what
```

No new mental model—configuration enters at **Human Intent** and mounts into **Containers** via the API and kubelet.

:::note Why this matters for Hermes

Hermes needs model selection, inference parameters, tool URLs, and API keys. ConfigMaps hold tunable non-secret settings; Secrets hold credentials. Without them, every tweak requires a new image—unacceptable for an agent platform.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Distinguish code, configuration, and secrets
- [ ] Create ConfigMaps for non-sensitive settings
- [ ] Create Secrets for sensitive values (lab-safe patterns)
- [ ] Inject config via environment variables and volume mounts
- [ ] Restart workloads after config changes
- [ ] Map injection flow to **State Layers**

---

## Prerequisites

- [Chapter 25: Helm](25-helm.md) — Helm installed; optional nginx-demo release
- `KUBECONFIG` → k3s cluster

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
```

---

## Estimated Time

**60 minutes** — 20 minutes reading, 40 minutes hands-on.

---

## Background

### The Problem

Everything so far hardcodes behavior in manifests or images:

```yaml
image: nginx:1.27
replicas: 3
```

Or worse—credentials in plain YAML or baked into images. That blocks:

- Dev/staging/prod differences
- Safe credential rotation
- Feature flags without rebuilds

Kubernetes provides **ConfigMaps** (non-sensitive) and **Secrets** (sensitive).

### Code vs Config vs Secret

| Type | Example | Change frequency |
|------|---------|----------------|
| **Code** | Hermes API handlers | Low (releases) |
| **Config** | Log level, model temperature, service URLs | Medium |
| **Secret** | API keys, DB passwords, tokens | Rotation-driven |

### Secrets Reality on k3s

Kubernetes Secrets are **base64-encoded by default**, not encrypted in etcd unless you enable encryption at rest. Treat them as **better than plain YAML**, not vault-grade—[Chapter 31](../part-v-infrastructure/31-secrets-management.md) hardens external secret storage later.

---

## Theory

### Injection Flow

```text
ConfigMap / Secret  (API objects)
        ↓
kubelet on node
        ↓
Pod env vars  OR  mounted files
        ↓
Application process
```

Two common patterns:

| Pattern | Use when |
|---------|----------|
| **Environment variables** | Simple key/value, 12-factor apps |
| **Volume mounts** | Config files, certs, structured config |

Pods read values at **startup**. Changing a ConfigMap/Secret does **not** hot-reload running processes—you must restart Pods (e.g. `kubectl rollout restart deployment/...`).

---

## Walkthrough

### Step 1 — Create ConfigMap

**[ch26-app-config-configmap.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch26-app-config-configmap.yaml)**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "debug"
  API_URL: "http://nginx-demo-service.default.svc.cluster.local"
```

```bash
kubectl apply -f infrastructure/kubernetes/ch26-app-config-configmap.yaml
kubectl get configmap app-config -o yaml
```

### Step 2 — Create Secret

**[ch26-app-secret.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch26-app-secret.yaml)**

Using `stringData` lets you avoid manual base64 in the lab:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  API_KEY: hello_world
```

```bash
kubectl apply -f infrastructure/kubernetes/ch26-app-secret.yaml
kubectl get secret app-secret
```

Never commit real production secrets to git.

### Step 3 — Pod With Env and Volume Injection

**[ch26-config-demo-pod.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch26-config-demo-pod.yaml)**

Apply:

```bash
kubectl apply -f infrastructure/kubernetes/ch26-config-demo-pod.yaml
kubectl wait --for=condition=Ready pod/config-demo --timeout=60s
```

### Step 4 — Verify Injection

```bash
kubectl logs config-demo
kubectl exec config-demo -- printenv LOG_LEVEL API_URL API_KEY
kubectl exec config-demo -- cat /config/app.properties
```

Expected logs include `LOG_LEVEL=debug`, `API_URL=...`, `API_KEY=hello_world`, and mounted file content.

### Step 5 — Update ConfigMap and Restart

```bash
kubectl patch configmap app-config --type merge \
  -p '{"data":{"LOG_LEVEL":"info"}}'
kubectl delete pod config-demo
kubectl apply -f infrastructure/kubernetes/ch26-config-demo-pod.yaml
kubectl logs config-demo
```

`LOG_LEVEL` should show **info**—Pod restart picked up the new ConfigMap.

### Step 6 — Helm Values Connection

Helm charts ([Chapter 25](25-helm.md)) often **generate** ConfigMaps and Secrets from `values.yaml`:

```text
values.yaml  →  Helm template  →  ConfigMap/Secret  →  Pod reference
```

Hermes charts will follow the same pattern: `helm upgrade -f values-prod.yaml` changes config without editing templates.

### Step 7 — Cleanup

```bash
kubectl delete pod config-demo --ignore-not-found
kubectl delete configmap app-config secret/app-secret
```

---

## Hands-on Lab

### Lab 26: Config and Secret Injection

**Estimated Time:** 40 minutes

**Goal:** Create ConfigMap + Secret; inject via env and volume; prove restart picks up changes.

**Steps:**

1. Apply ConfigMap and Secret manifests
2. Apply `config-demo` Pod; verify env and mount
3. Patch ConfigMap `LOG_LEVEL`; recreate Pod; confirm new value
4. List which Hermes settings would be ConfigMap vs Secret in your notes

---

## Verification

- [ ] ConfigMap `app-config` exists with expected keys
- [ ] Secret `app-secret` exists (values not in plain git)
- [ ] Pod env shows `LOG_LEVEL`, `API_URL`, `API_KEY`
- [ ] Volume mount `/config/app.properties` readable
- [ ] ConfigMap patch requires Pod restart to take effect

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `CreateContainerConfigError` | Missing ConfigMap/Secret or wrong key | `kubectl describe pod config-demo` |
| Env empty | Wrong `configMapKeyRef` name/key | Match metadata.name and data keys |
| Secret garbled | Used `data` without base64 | Use `stringData` in lab, or `echo -n x \| base64` |
| Change not visible | Pod not restarted | Delete Pod or `rollout restart` Deployment |
| Wrong namespace | CM/Secret in different ns | `kubectl get cm,secret -A` |

---

## Review Questions

1. Why not put API keys in Deployment YAML?
2. What is the difference between ConfigMap and Secret?
3. Why are Kubernetes Secrets not fully secure by default?
4. When use volume mount vs environment variable?
5. Which Hermes settings belong in ConfigMap vs Secret?

---

## Key Takeaways

- **ConfigMaps** externalize non-sensitive runtime settings
- **Secrets** externalize sensitive values—encode/encrypt properly for production
- **Injection** happens at Pod start via kubelet—restart to reload
- **Config → Identity → Security** is the correct pre-Hermes order
- Next: [Chapter 27](27-kubernetes-security.md)—RBAC and network policy protect what you configured

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **ConfigMap** | API object storing non-sensitive configuration as key-value pairs. |
| **Secret** | API object storing sensitive data (encoded; encrypt at rest for production). |
| **stringData** | Secret field accepting plain text; Kubernetes encodes to base64. |
| **configMapKeyRef** | Pod env source referencing a ConfigMap key. |

---

## Further Reading

- [Configure a Pod to use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Chapter 31: Secrets Management](../part-v-infrastructure/31-secrets-management.md) — production hardening

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
First Pod scheduled    ✓
Deployments            ✓
Services               ✓
Ingress (HTTP)         ✓
Persistent K8s volumes ✓
Helm packaging         ✓
ConfigMaps / Secrets   ✓

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

███████████████████░░░ 88%
───────────────────────────────────────────────
```

Configuration is externalized. Next: permissions and boundaries.

---

## What's Next

[Chapter 27: Security](27-kubernetes-security.md) — RBAC and NetworkPolicy: who may access the configuration and workloads you defined.

---

[← Chapter 25: Helm](25-helm.md) | [Next: Chapter 27 — Security →](27-kubernetes-security.md)
