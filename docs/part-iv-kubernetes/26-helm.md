---
sidebar_position: 26
description: "Package Deployment, Service, and Ingress as an installable Helm chart."
---

# Chapter 26: Helm

> Kubernetes gives you primitives.
>
> Helm gives you systems.

---

Chapters 20–24 taught individual objects. You applied YAML file by file: Deployment, Service, Ingress, PVC.

Real platforms deploy **systems**—versioned, configurable, upgradeable bundles. **Helm** is the packaging layer for Kubernetes: charts define the system; **releases** track what is installed.

```text
Chapters 20–24   →  primitives (apply YAML)
Chapter 26       →  packaged system (helm install)
```

You are not learning a new mental model. You are **stacking packaging on top of the State Layers you already use**.

:::note[Why this matters for Hermes]

Hermes is not one Deployment—it is API, workers, inference, storage, and Ingress wired together. Helm is how that becomes:

```bash
helm install hermes ./charts/hermes -f values-prod.yaml
```

One installable product—not a folder of loose manifests.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain Helm charts vs releases vs values
- [ ] Install Helm 3 on your laptop and talk to the k3s cluster
- [ ] Install the book’s **nginx-demo** chart (Ch 22–23 packaged)
- [ ] Upgrade a release with `--set` or a values file
- [ ] Roll back a failed upgrade with `helm rollback`
- [ ] Contrast `kubectl apply` (primitives) with `helm install` (versioned systems)

---

## Prerequisites

- Chapters [21](22-deployments.md)–[24](25-kubernetes-storage.md) understood (objects the chart contains)
- `KUBECONFIG` → k3s cluster
- **Remove** prior manual nginx resources if they conflict (same names):

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl delete ingress nginx-ingress --ignore-not-found
kubectl delete svc nginx-service --ignore-not-found
kubectl delete deployment nginx-deployment --ignore-not-found
```

PVCs from Chapter 25 (`app-data`) are unrelated—leave them unless you are cleaning up that lab.

---

## Estimated Time

**90 minutes** — 25 minutes reading, 65 minutes hands-on.

---

## Background

### The Problem

Manual YAML works for learning. Production systems need:

- **Dependencies** — Deployment + Service + Ingress together
- **Environments** — dev vs prod values, same chart
- **Versioning** — upgrade and rollback without hand-editing cluster state
- **Drift control** — one chart is the source of truth

| Ecosystem | Package manager |
|-----------|-----------------|
| Linux | apt |
| Node.js | npm |
| Python | pip |
| **Kubernetes** | **Helm** |

### What a Chart Is

```text
infrastructure/helm/nginx-demo/
  Chart.yaml          ← chart metadata
  values.yaml         ← default configuration
  values-lab-scale.yaml
  templates/
    deployment.yaml   ← templated Kubernetes objects
    service.yaml
    ingress.yaml
```

Templates use Go templating: `{{ .Values.replicaCount }}` becomes `3` at install time.

### State Layer Mapping

Helm sits at **Human Intent**—you declare `helm install` with values; Helm renders templates and writes objects to the **Kubernetes API**. Everything below (scheduler, Services, Pods, PVCs) is unchanged.

```text
Helm CLI + values.yaml
      ↓
Rendered manifests → API (Deployment, Service, Ingress)
      ↓
Existing stack (scheduler → Pod → storage)
```

---

## Theory

### Releases

Each `helm install` creates a **release**—a named, versioned instance of a chart in the cluster.

| Concept | Meaning |
|---------|---------|
| **Chart** | Package (files in git) |
| **Release** | Installed chart instance (`web` v1, v2, …) |
| **Revision** | Numbered history for rollback |

### Helm vs kubectl apply

| | `kubectl apply -f` | `helm install` |
|---|---------------------|----------------|
| Input | Static YAML | Templated chart + values |
| Tracking | None built-in | Release history |
| Upgrade | Edit files, re-apply | `helm upgrade` |
| Rollback | Manual | `helm rollback` |

Both talk to the same API. Helm adds **system lifecycle**.

---

## Architecture

### nginx-demo Chart (This Book)

The chart in `infrastructure/helm/nginx-demo/` packages what you built manually in Chapters 21–23:

| Template | Chapter equivalent |
|----------|-------------------|
| `deployment.yaml` | Ch 22 — `nginx-deployment` |
| `service.yaml` | Ch 23 — ClusterIP Service |
| `ingress.yaml` | Ch 24 — Traefik Ingress `nginx.local` |

Default values match the k3s-on-EC2 platform: `ingress.className: traefik`, host `nginx.local`.

### Full Stack With Packaging

```text
Helm release
  ↓
Deployment → Pod
  ↓
Service
  ↓
Ingress
  ↓
(PVC when chart includes persistence — Hermes charts later)
```

---

## Walkthrough

### Step 1 — Install Helm on Your Laptop

Helm runs on your workstation like `kubectl`:

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

Expected: `version.BuildInfo{Version:"v3.x"...}`

### Step 2 — Dry-Run the Chart

From the repository root:

```bash
helm template web infrastructure/helm/nginx-demo
```

Review rendered YAML—same objects you wrote by hand, with values filled in.

Override replicas:

```bash
helm template web infrastructure/helm/nginx-demo --set replicaCount=2
```

### Step 3 — Install the Release

```bash
helm install web infrastructure/helm/nginx-demo
```

Helm applies Deployment, Service, and Ingress in one operation.

Verify:

```bash
helm list
kubectl get deployment,svc,ingress -l app.kubernetes.io/instance=web
kubectl get pods -l app.kubernetes.io/instance=web
```

### Step 4 — Test Ingress (Same as Chapter 24)

Ensure `/etc/hosts` maps `nginx.local` → `HERMES_PUBLIC_IP` and port 80 is open.

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://nginx.local/
```

Expected: **200**

### Step 5 — Upgrade With Values

Scale to 2 replicas via values file:

```bash
helm upgrade web infrastructure/helm/nginx-demo \
  -f infrastructure/helm/nginx-demo/values-lab-scale.yaml
helm history web
kubectl get pods -l app.kubernetes.io/instance=web
```

Or inline:

```bash
helm upgrade web infrastructure/helm/nginx-demo --set replicaCount=2
```

### Step 6 — Rollback

Return to revision 1 (initial install):

```bash
helm rollback web 1
helm history web
kubectl get deployment nginx-demo -o jsonpath='{.spec.replicas}{"\n"}'
```

Replicas should match the first revision (3 by default).

### Step 7 — Uninstall

```bash
helm uninstall web
kubectl get deployment,svc,ingress | grep nginx-demo || echo "Release removed"
```

Helm removes resources it created for that release.

---

## Hands-on Lab

### Lab 25: Package and Lifecycle

**Estimated Time:** 65 minutes

**Goal:** Install, upgrade, and rollback the nginx-demo chart on k3s.

**Steps:**

1. Install Helm 3; confirm `KUBECONFIG`
2. Remove conflicting manual nginx resources (prerequisites)
3. `helm install web infrastructure/helm/nginx-demo`
4. `curl http://nginx.local/` → 200
5. `helm upgrade` with `values-lab-scale.yaml` (2 replicas)
6. `helm rollback web 1`
7. `helm uninstall web`

**Optional:** Browse [Artifact Hub](https://artifacthub.io/) for community charts (e.g. Bitnami)—same mechanics, different chart source.

---

## Verification

- [ ] `helm version` shows v3
- [ ] `helm list` shows release after install
- [ ] Deployment + Service + Ingress created from chart
- [ ] Upgrade changed replica count; rollback restored prior revision
- [ ] `helm uninstall` removed release resources

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `cannot re-use a name` | Release name already exists | `helm uninstall web` or pick new name |
| `INSTALLATION FAILED` conflict | Old manual resources same names | Delete Ch 22–23 objects (prerequisites) |
| Ingress 404 | Host/DNS unchanged from Ch 24 | Check `/etc/hosts`, Traefik |
| Upgrade no-op | Same values | `helm diff upgrade` (plugin) or `--set replicaCount=1` to verify |
| `helm` cannot reach cluster | `KUBECONFIG` | Same fix as kubectl |

### Release Stuck

```bash
helm status web
helm history web
kubectl get events --sort-by=.lastTimestamp
```

---

## Review Questions

1. What is the difference between a chart and a release?
2. Where do environment-specific settings belong—templates or values?
3. How does `helm rollback` relate to revision numbers?
4. Why package Ch 22–23 into one chart instead of three `kubectl apply` files?
5. How will Helm install Hermes differently than installing nginx-demo?

---

## Key Takeaways

- **Helm packages systems** built from primitives you already know
- **Values** parameterize charts without editing templates per environment
- **Releases** are versioned—upgrade and rollback are first-class
- **nginx-demo** chart = Deployment + Service + Ingress from this book
- Next platform concerns: **configuration and secrets** before Hermes lands ([Chapter 32](../part-v-infrastructure/32-secrets-management.md) for production secret stores)

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Chart** | Helm package of templated Kubernetes manifests. |
| **Release** | Named installation of a chart in a cluster. |
| **values.yaml** | Default configuration for template variables. |
| **Revision** | Numbered release history entry for rollback. |
| **helm upgrade** | Apply a new chart version or values to a release. |

---

## Further Reading

- [Helm documentation](https://helm.sh/docs/)
- [Chart template guide](https://helm.sh/docs/chart_template_guide/)
- [Artifact Hub](https://artifacthub.io/) — community charts

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
Node Ready             ✓
First Pod scheduled    ✓
Deployments            ✓
Services               ✓
Ingress (HTTP)         ✓
Persistent K8s volumes ✓
Helm packaging         ✓

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

██████████████████░░░░ 85%
───────────────────────────────────────────────
```

Primitives are packaged. Next: secure and harden before application deploy.

---

## What's Next

[Chapter 27: Configuration (ConfigMaps & Secrets)](27-configuration-configmaps-secrets.md) — separate code from configuration and credentials before locking down access.

Production secret storage hardens further in [Chapter 32: Secrets Management](../part-v-infrastructure/32-secrets-management.md).

---

[← Chapter 25: Storage](25-kubernetes-storage.md) | [Next: Chapter 27 — Configuration →](27-configuration-configmaps-secrets.md)
