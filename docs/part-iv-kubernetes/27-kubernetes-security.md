---
sidebar_position: 27
description: "RBAC and NetworkPolicy — intentional restriction of capability on k3s."
---

# Chapter 27: Security (RBAC & Network Policies)

> In Kubernetes, everything is allowed by default.
>
> Security is what you remove.

---

[Chapter 26](26-configuration-configmaps-secrets.md) externalized configuration and secrets. Now you **restrict capability**: who may call the API, and which Pods may talk to each other.

This is not a new paradigm—it is **capability reduction** on the stack you already operate.

```text
Chapter 26   Config/Secret  →  what the system knows
Chapter 27   RBAC + NetworkPolicy →  who may act and who may connect
```

:::note[Why this matters for Hermes]

Hermes is multi-component: API, workers, llama.cpp, PostgreSQL, tools. Not every Pod should list Secrets, reach the database, or call inference directly. RBAC limits API actions; NetworkPolicy limits east-west traffic.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain RBAC: Role, RoleBinding, ServiceAccount
- [ ] Test permissions with `kubectl auth can-i`
- [ ] Apply a read-only Role for a ServiceAccount
- [ ] Describe what NetworkPolicy controls vs RBAC
- [ ] Apply default-deny and allow-list ingress policies
- [ ] Reason about k3s NetworkPolicy enforcement limits

---

## Prerequisites

- [Chapter 26: Configuration](26-configuration-configmaps-secrets.md)
- nginx workload with label `app: nginx` (Ch 21–25 or `nginx-demo` Helm release)
- `KUBECONFIG` → k3s cluster

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -l app=nginx
```

---

## Estimated Time

**75 minutes** — 25 minutes reading, 50 minutes hands-on.

---

## Background

### The Problem

After Helm and ConfigMaps, the cluster still defaults to **permissive**:

- Workloads can often reach any Service DNS name
- ServiceAccounts may have broad API access unless restricted
- Secrets in the same namespace may be readable by over-privileged Pods

Security adds **intentional limitation**:

```text
RBAC           →  who can call the Kubernetes API
NetworkPolicy  →  which Pods may exchange traffic
```

Different layers—both required for Hermes.

### State Layer Mapping

| Layer | Security control |
|-------|------------------|
| Human / CI | Your IAM + kubeconfig (outside cluster) |
| **API** | **RBAC** — allow/deny verbs on resources |
| **Pod network** | **NetworkPolicy** — allow/deny traffic |
| Container / kernel | Process isolation (namespaces, cgroups) |

---

## Theory

### RBAC Objects

| Object | Scope | Purpose |
|--------|-------|---------|
| **Role** | Namespace | Permissions in one namespace |
| **ClusterRole** | Cluster | Permissions cluster-wide |
| **RoleBinding** | Namespace | Links Role → user or ServiceAccount |
| **ClusterRoleBinding** | Cluster | Links ClusterRole → subject |

Example verbs: `get`, `list`, `create`, `delete` on resources like `pods`, `secrets`, `deployments`.

### ServiceAccounts

Every Pod runs as a **ServiceAccount** (default: `default` in namespace). RBAC binds to that identity:

```text
Pod → ServiceAccount → RoleBinding → Role → allowed API verbs
```

### NetworkPolicy

Without policies on many clusters: **all Pods can reach all Pods** (via Services/cluster DNS).

NetworkPolicy selects Pods and defines allowed **Ingress** and/or **Egress** traffic.

Typical pattern:

1. **Default deny** ingress for sensitive Pods
2. **Allow list** only required sources (label selectors)

### RBAC vs NetworkPolicy

| | RBAC | NetworkPolicy |
|---|------|---------------|
| Controls | Kubernetes API | Pod-to-Pod / Pod-to-Service traffic |
| Example | Can this SA `list secrets`? | Can frontend reach nginx:80? |
| Hermes use | Worker cannot delete Deployments | API tier cannot reach PostgreSQL directly |

### k3s Reality

**RBAC** is fully enforced on k3s.

**NetworkPolicy** requires CNI support. Default k3s uses Flannel; **policy enforcement may be limited** until you adopt a policy-capable CNI (e.g. Calico) or enable policy support in your k3s build. You still **declare** policies now—production hardening closes the gap later.

---

## Architecture

### Hermes Capability Boundaries (Preview)

| Component | RBAC (API) | Network (east-west) |
|-----------|------------|---------------------|
| Hermes API | Read Services, own ConfigMaps | Reach workers + llama.cpp Service only |
| llama.cpp | Minimal / none | Accept from Hermes only |
| PostgreSQL | None | Accept from Hermes only |
| Tool runners | Scoped job APIs | Egress to approved endpoints only |

Chapter 27 practices the mechanics on nginx—not Hermes yet.

---

## Walkthrough

### Part A — RBAC

#### Step 1 — Apply Read-Only Role for `hermes-reader`

**[ch27-rbac-hermes-reader.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch27-rbac-hermes-reader.yaml)**

```bash
kubectl apply -f infrastructure/kubernetes/ch27-rbac-hermes-reader.yaml
kubectl get sa hermes-reader
kubectl describe role pod-reader
```

Creates:

- ServiceAccount `hermes-reader`
- Role `pod-reader` — `get`, `list` on Pods in `default`
- RoleBinding linking them

#### Step 2 — Test Permissions

As the ServiceAccount:

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:hermes-reader

kubectl auth can-i delete pods \
  --as=system:serviceaccount:default:hermes-reader

kubectl auth can-i list secrets \
  --as=system:serviceaccount:default:hermes-reader
```

Expected:

- `list pods` → **yes**
- `delete pods` → **no**
- `list secrets` → **no**

Your admin kubeconfig still has full access—that is correct for platform ops.

#### Step 3 — Pod Using the ServiceAccount

```bash
kubectl run rbac-demo \
  --restart=Never \
  --serviceaccount=hermes-reader \
  --image=bitnami/kubectl:1.30 \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/rbac-demo --timeout=120s
kubectl exec rbac-demo -- kubectl get pods
kubectl exec rbac-demo -- kubectl delete pod rbac-demo 2>&1 || true
```

Inside the Pod: **list** works; **delete** fails—capability reduced.

Cleanup:

```bash
kubectl delete pod rbac-demo --ignore-not-found
```

---

### Part B — NetworkPolicy

#### Step 4 — Allow-List Ingress to nginx Pods

**[ch27-networkpolicy-nginx.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch27-networkpolicy-nginx.yaml)**

Once a NetworkPolicy selects Pods, **unlisted ingress is denied** for those Pods.

```bash
kubectl apply -f infrastructure/kubernetes/ch27-networkpolicy-nginx.yaml
kubectl get networkpolicy nginx-allow-frontend-only
```

Only Pods with label `access: frontend` may reach `app: nginx` on TCP/80.

#### Step 5 — Test Isolation

Ensure nginx Service exists (`nginx-service` or `nginx-demo-service`).

**Blocked client** (no `access: frontend` label):

```bash
kubectl run curl-blocked --restart=Never --image=curlimages/curl:8.5.0 \
  --command -- curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 5 \
  http://nginx-service.default.svc.cluster.local/ || echo "failed"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/curl-blocked --timeout=60s 2>/dev/null || \
  kubectl wait --for=condition=Ready pod/curl-blocked --timeout=60s
kubectl logs curl-blocked 2>/dev/null; kubectl delete pod curl-blocked --ignore-not-found
```

**Allowed client**:

```bash
kubectl run curl-allowed --restart=Never --image=curlimages/curl:8.5.0 \
  --labels="access=frontend" \
  --command -- curl -s -o /dev/null -w "%{http_code}\n" \
  http://nginx-service.default.svc.cluster.local/
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/curl-allowed --timeout=60s 2>/dev/null || sleep 5
kubectl logs curl-allowed
kubectl delete pod curl-allowed --ignore-not-found
```

**If NetworkPolicy is enforced:** blocked → timeout/`000`; allowed → `200`.

**If both return 200:** policies are declared but not enforced by your CNI—see Troubleshooting. RBAC results still validate the chapter.

#### Step 6 — Cleanup Policies (Optional)

```bash
kubectl delete networkpolicy nginx-allow-frontend-only
kubectl delete -f infrastructure/kubernetes/ch27-rbac-hermes-reader.yaml
```

---

## Hands-on Lab

### Lab 27: Capability Reduction

**Estimated Time:** 50 minutes

**Goal:** RBAC read-only SA; NetworkPolicy deny/allow on nginx.

**Steps:**

1. Apply RBAC manifest; verify `can-i` yes/no matrix
2. Run `rbac-demo` Pod; confirm list works, delete denied
3. Apply NetworkPolicy manifest
4. Test curl from blocked vs `access=frontend` Pod
5. Document which Hermes components need API vs network restrictions

---

## Verification

- [ ] `hermes-reader` ServiceAccount bound to `pod-reader` Role
- [ ] `can-i list pods` → yes; `delete pods` → no for that SA
- [ ] NetworkPolicy objects exist for `app: nginx`
- [ ] You can explain RBAC vs NetworkPolicy in one sentence each
- [ ] You know k3s may require policy-capable CNI for full enforcement

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `can-i` always yes | Wrong `--as` subject | Use full SA: `system:serviceaccount:default:hermes-reader` |
| Pod cannot use kubectl in cluster | RBAC too tight | Add needed verbs to Role |
| NetworkPolicy has no effect | Flannel without policy enforcement | Expected on some k3s installs; policies still document intent; add Calico later |
| Everything blocked including Traefik | Policy on nginx breaks Ingress | Allow Ingress controller namespace/labels in production rules |
| Locked out of cluster | Overly broad ClusterRoleBinding changes | Keep admin kubeconfig; test with `can-i` before applying |

### Do Not Over-Restrict System Namespaces

Avoid default-deny policies in `kube-system` without allowing DNS, Traefik, and control plane traffic—cluster breaks.

---

## Review Questions

1. What does RBAC control that NetworkPolicy does not?
2. What identity does a Pod use for API calls?
3. Why default-deny ingress before allow-list?
4. Which Hermes tier should reach PostgreSQL on the network?
5. Why is “secure by default” misleading in Kubernetes?

---

## Key Takeaways

- **Security = intentional limitation** — remove capability, do not add features
- **RBAC** — API permissions via Roles and ServiceAccounts
- **NetworkPolicy** — east-west traffic rules between Pods
- **Config → Security → Scaling** — protect configuration before load tuning
- Hermes deploys next with these boundaries in mind

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **RBAC** | Role-Based Access Control for Kubernetes API operations. |
| **ServiceAccount** | Identity Pods use when calling the Kubernetes API. |
| **NetworkPolicy** | Rules controlling Pod ingress/egress traffic. |
| **default deny** | Block all traffic in a direction until explicitly allowed. |

---

## Further Reading

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [k3s networking](https://docs.k3s.io/networking)

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
RBAC (lab)             ✓
NetworkPolicy (declared) ✓

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

████████████████████░░ 91%
───────────────────────────────────────────────
```

Kubernetes is a governed execution environment. Next: behavior under load.

---

## What's Next

[Chapter 28: Scaling](28-scaling.md) — control system behavior when demand increases.

---

[← Chapter 26: Configuration](26-configuration-configmaps-secrets.md) | [Next: Chapter 28 — Scaling →](28-scaling.md)
