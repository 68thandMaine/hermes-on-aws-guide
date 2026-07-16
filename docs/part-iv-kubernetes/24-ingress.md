---
sidebar_position: 24
description: "Route HTTP from your laptop into the cluster via Ingress."
---

# Chapter 24: Ingress

> Services make workloads reachable inside the cluster.
>
> Ingress makes them reachable from the outside world.

---

[Chapter 23](23-services.md) gave nginx a stable **in-cluster** address: `nginx-service`.

That is not enough for the finish line from [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md):

```text
laptop → ingress → Hermes → model → response
```

Until now, external access meant **`kubectl port-forward`**—a debug tunnel, not production entry.

**Ingress** is the HTTP routing layer: rules at the API, implemented by an **Ingress controller**, forwarding to **Services** (not Pod IPs).

```text
Chapter 23   Service   →  stable internal identity
Chapter 24   Ingress   →  external HTTP entry
```

On your k3s cluster, **Traefik** is already the Ingress controller—it installed with [Chapter 13](../part-ii-aws/13-the-first-control-plane.md). You declare rules; Traefik enforces them.

:::note[Why this matters for Hermes]

Ingress becomes the front door to the AI stack: `https://hermes.example.com` → Hermes Service → workers → llama.cpp. This chapter uses `nginx.local` on HTTP; [Chapter 14](../part-ii-aws/14-routing-traffic-to-hermes.md) adds Route 53 and TLS.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain Ingress vs Service responsibilities
- [ ] Identify the Ingress controller (Traefik) on k3s
- [ ] Apply host-based Ingress rules to `nginx-service`
- [ ] Trace request flow: laptop → Traefik → Service → Pod
- [ ] Open port 80 safely on the Hermes security group for the lab
- [ ] Replace port-forward with real HTTP routing for external tests
- [ ] Map Ingress to **State Layers**

---

## Prerequisites

- [Chapter 23: Services](23-services.md) — `nginx-service` and `nginx-deployment` Running
- `KUBECONFIG` and `controlplane.env`

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
source ~/hermes-platform/notes/controlplane.env

kubectl get svc nginx-service
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

---

## Estimated Time

**75 minutes** — 20 minutes reading, 55 minutes hands-on (includes security group update).

---

## Background

### The Gap After Services

ClusterIP Services are **internal**. Options for external access:

| Approach | Role in this book |
|----------|-------------------|
| `kubectl port-forward` | Debug only (Ch 21–22) |
| **NodePort** | Low-level; bypasses routing rules |
| **LoadBalancer per Service** | Cloud LB per app—expensive, noisy |
| **Ingress** | **One HTTP entry, many routes** |

Ingress answers: *How does HTTP from my laptop reach the right Service?*

### Ingress Resource vs Ingress Controller

Kubernetes stores **rules**. Something must **implement** them:

```text
Ingress resource (YAML rules)
        ↓
Ingress Controller (Traefik on k3s)
        ↓
Service → Pods
```

**Two parts.** Without a controller, Ingress objects do nothing. k3s ships Traefik in `kube-system`.

### State Layer Mapping

```text
Human Intent          ← Ingress manifest: host + path → service
Kubernetes API        ← Ingress object
Ingress Controller    ← Traefik (watches API, configures proxy)
Service               ← nginx-service:80
Containers            ← nginx Pods
Linux Kernel          ← processes + node networking (ports 80/443)
```

---

## Theory

### Full Request Chain

```text
Browser / curl (laptop)
      ↓
HERMES_PUBLIC_IP:80  (host: nginx.local)
      ↓
Traefik (Ingress Controller on node)
      ↓
Ingress rule: nginx.local / → nginx-service:80
      ↓
kube-proxy → Pod (any healthy replica)
      ↓
nginx process
```

Every layer is the stack you have been assembling since Chapter 21.

### Ingress vs Service

| Layer | Responsibility |
|-------|----------------|
| **Service** | Stable **internal** routing to Pods |
| **Ingress** | **External HTTP** routing to Services |

Complementary—not competing.

### Routing Dimensions (Preview)

| Style | Example | Hermes later |
|-------|---------|--------------|
| Host-based | `nginx.local` → nginx | `hermes.example.com` → Hermes API |
| Path-based | `/api` → api-svc, `/` → web-svc | `/v1/chat` → Hermes |

This lab uses **host-based** routing on HTTP. Path rules use the same object type.

---

## Architecture

### k3s + Traefik on EC2

```text
Internet
   ↓
AWS Security Group (port 80 from your IP)
   ↓
hermes-controlplane-01:80
   ↓
Traefik (k3s bundled)
   ↓
Ingress nginx-ingress
   ↓
nginx-service (ClusterIP)
   ↓
nginx-deployment Pods
```

k3s **ServiceLB** (klipper-lb) binds Traefik to ports 80/443 on the node. You must allow **80/tcp** in the EC2 security group for this lab.

---

## Walkthrough

### Step 1 — Verify Traefik

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

Traefik should be **Running**. Note Traefik’s Service ports (typically 80/443).

### Step 2 — Allow HTTP on the Security Group

From your laptop (temporary lab rule—tighten later):

```bash
export AWS_PROFILE=hermes
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id "$HERMES_SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr "${MY_IP}/32" \
  2>/dev/null || echo "Rule may already exist"
```

If `HERMES_SG_ID` is not in `controlplane.env`, read it from your [Chapter 8](../part-ii-aws/08-creating-network-for-hermes.md) notes.

On the node, UFW (if enabled in [Chapter 10](../part-ii-aws/10-establishing-trust.md)) must allow 80:

```bash
ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem ubuntu@${HERMES_PUBLIC_IP} \
  'sudo ufw status | grep -E "80|Status"'
```

Allow if needed: `sudo ufw allow 80/tcp`.

### Step 3 — Apply Ingress Rules

**[infrastructure/kubernetes/ch24-nginx-ingress.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch24-nginx-ingress.yaml)**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  ingressClassName: traefik
  rules:
    - host: nginx.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

Apply:

```bash
kubectl apply -f infrastructure/kubernetes/ch24-nginx-ingress.yaml
kubectl get ingress nginx-ingress
```

Address column may show the node IP or stay empty on some setups—routing still works via Traefik on port 80.

Describe for details:

```bash
kubectl describe ingress nginx-ingress
```

### Step 4 — Map Hostname on Your Laptop

Add to `/etc/hosts` (macOS/Linux: edit with sudo):

```text
HERMES_PUBLIC_IP nginx.local
```

Replace `HERMES_PUBLIC_IP` with your Elastic IP from `controlplane.env`.

### Step 5 — Test from Outside the Cluster

From your laptop—not port-forward:

```bash
curl -v http://nginx.local/
```

Expected: HTTP **200** and nginx welcome HTML.

You crossed the boundary: **external client → Ingress → Service → Pod**.

### Step 6 — Scale Backend; Routing Stays Stable

```bash
kubectl scale deployment nginx-deployment --replicas=4
kubectl get pods -l app=nginx
curl -s -o /dev/null -w "%{http_code}\n" http://nginx.local/
```

Still **200**—Ingress targets the Service; the Deployment manages Pod count.

Scale back:

```bash
kubectl scale deployment nginx-deployment --replicas=3
```

### Step 7 — Path-Based Routing (Optional Sketch)

Same Ingress can add paths for future services:

```yaml
# Illustration only — not applied in this lab
- path: /api
  pathType: Prefix
  backend:
    service:
      name: api-service
      port:
        number: 8080
```

Hermes and llama.cpp will use host + path rules on one Traefik entry point.

---

## Hands-on Lab

### Lab 24: External HTTP Entry

**Estimated Time:** 55 minutes

**Goal:** Reach nginx through Ingress from your laptop without port-forward.

**Steps:**

1. Verify Traefik Running; `nginx-service` has Endpoints
2. Open SG port 80 from your IP
3. Apply `ch24-nginx-ingress.yaml`
4. Add `nginx.local` to `/etc/hosts`
5. `curl http://nginx.local/` → 200
6. Scale Deployment to 4; confirm curl still 200
7. Trace the full chain in your notes (State Layers)

---

## Verification

- [ ] Traefik pod Running in `kube-system`
- [ ] Ingress `nginx-ingress` exists with host `nginx.local`
- [ ] `curl http://nginx.local/` from laptop returns **200** without port-forward
- [ ] Scaling nginx Deployment does not break Ingress
- [ ] You can draw Ingress → Service → Pod flow from memory

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Connection timeout | SG or UFW blocks 80 | Add SG rule; `ufw allow 80/tcp` |
| **404** from Traefik | Wrong host header | Use `http://nginx.local/`; check `/etc/hosts` |
| **404** / no backend | Service name/port mismatch | `kubectl describe ingress`; verify `nginx-service:80` |
| **502/503** | No healthy Endpoints | `kubectl get endpoints nginx-service` |
| Works with port-forward, not Ingress | Ingress not applied or Traefik down | `kubectl get ingress,pods -n kube-system` |
| `ingressClassName: traefik` ignored | Wrong class name | `kubectl get ingressclass` — use listed name |

### Other Controllers (Reference)

| Controller | When |
|------------|------|
| **Traefik** | **k3s default** — this chapter |
| NGINX Ingress | Common on self-managed clusters |
| AWS Load Balancer Controller | EKS + ALB ([Chapter 14](../part-ii-aws/14-routing-traffic-to-hermes.md)) |

Do not install a second controller on k3s unless you disable Traefik—one entry point per cluster.

---

## Review Questions

1. What implements Ingress rules on your cluster?
2. Why does Ingress route to Services, not Pods?
3. What replaces port-forward for laptop → workload HTTP?
4. What must open on AWS for port 80 to reach Traefik?
5. Where does Ingress sit in State Layers relative to Services?

---

## Key Takeaways

- **Ingress** = external HTTP routing; **Service** = internal stable routing
- **Traefik** on k3s watches Ingress resources and proxies traffic
- Full chain: laptop → SG → Traefik → Ingress rule → Service → Pod
- Host-based routing (`nginx.local`) previews Hermes production hostnames
- TLS and public DNS move to [Chapter 14](../part-ii-aws/14-routing-traffic-to-hermes.md); persistence to [Chapter 25](25-kubernetes-storage.md)

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Ingress** | API object defining HTTP routing rules into the cluster. |
| **Ingress Controller** | Component that implements Ingress rules (Traefik on k3s). |
| **ingressClassName** | Links an Ingress resource to a controller (`traefik`). |
| **Traefik** | Reverse proxy bundled with k3s as the default Ingress controller. |
| **host-based routing** | Route by HTTP `Host` header (e.g. `nginx.local`). |

---

## Further Reading

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [k3s networking / Traefik](https://docs.k3s.io/networking)
- [Traefik documentation](https://doc.traefik.io/traefik/)

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

Persistent K8s volumes ✗

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

████████████████░░░░░░ 78%
───────────────────────────────────────────────
```

External HTTP entry works. Next: state that survives Pod restarts.

---

## What's Next

[Chapter 25: Storage](25-kubernetes-storage.md) — PostgreSQL and model data need persistence inside a dynamic cluster.

---

[← Chapter 23: Services](23-services.md) | [Next: Chapter 25 — Storage →](25-kubernetes-storage.md)
