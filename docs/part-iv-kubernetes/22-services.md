---
sidebar_position: 22
description: "Stable cluster networking over Pods that come and go."
---

# Chapter 22: Services

> A Pod IP dies with the Pod. A Service is how anything else finds your workload.

---

[Chapter 21](21-deployments.md) keeps three nginx Pods running. Each Pod gets its **own IP**. When the Deployment replaces a Pod during self-healing or rollout, that IP disappears.

Clients cannot memorize Pod IPs. They need a **stable name and address** that always routes to whichever Pods match right now.

A **Service** is that abstraction—declared at the API layer, implemented by cluster networking (kube-proxy on k3s).

```text
Chapter 20   Pod         →  runs the process
Chapter 21   Deployment  →  keeps N Pods running
Chapter 22   Service     →  stable way to reach those Pods
```

You are not learning a new model. You are **adding a network handle** to the stack you already operate.

:::note Why this matters for Hermes

Hermes will call llama.cpp over a **Service DNS name**—not a Pod IP. PostgreSQL and Redis get Services too. The path `Hermes → llama.cpp Service → Pod` is the in-cluster half of `laptop → ingress → Hermes → model → response`.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why Pod IPs are unstable and why Services exist
- [ ] Create a ClusterIP Service that selects Pods by label
- [ ] Inspect Service, Endpoints, and backing Pods together
- [ ] Reach a Service from another Pod using cluster DNS
- [ ] Contrast `port-forward` to a Pod (Ch 20) vs routing through a Service
- [ ] Map Services to **State Layers**

---

## Prerequisites

- [Chapter 21: Deployments](21-deployments.md) — `nginx-deployment` with `app: nginx` labels and Running Pods
- `KUBECONFIG` configured

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get deployment nginx-deployment
kubectl get pods -l app=nginx
```

If the Deployment is missing, apply [ch21-nginx-deployment.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch21-nginx-deployment.yaml) first.

---

## Estimated Time

**60 minutes** — 15 minutes reading, 45 minutes hands-on.

---

## Background

### Unstable Compute, Stable Network

| Object | Identity | Lifetime |
|--------|----------|----------|
| **Pod** | IP assigned at schedule time | Dies with Pod |
| **Service** | Cluster IP + DNS name | Lives until you delete the Service |

When you deleted a Pod in Chapter 21, the Deployment created a replacement with a **new IP**. Anything that cached the old IP broke.

A Service sits in front of the Pod set:

```text
Client (another Pod, or Ingress later)
        ↓
   nginx-service:80          ← stable DNS + virtual IP
        ↓
   Endpoints (Pod IPs)       ← updates automatically
        ↓
   Pod / Pod / Pod           ← replicas from Deployment
```

### State Layer Mapping

```text
Human Intent          ← Service manifest: selector + ports
Kubernetes API        ← Service + Endpoints objects
Scheduler             ← (Pods already scheduled by Deployment)
Containers            ← nginx processes reached via kube-proxy routing
Linux Kernel          ← network namespaces, iptables/ipvs rules
```

The Service object is **API-layer desired state** for networking—same reconciliation pattern as Deployments, different resource type.

---

## Theory

### Selectors and Endpoints

A Service finds Pods with a **label selector**:

```yaml
selector:
  app: nginx
```

Kubernetes maintains an **Endpoints** object (or EndpointSlice) listing current Pod IPs that match. When Pods change, Endpoints update—clients keep using `nginx-service`.

### Cluster DNS

Inside the cluster, CoreDNS resolves:

```text
nginx-service                      # same namespace (default)
nginx-service.default.svc.cluster.local   # fully qualified
```

Port **80** on the Service forwards to **targetPort** on selected Pods (also 80 here).

### Service Types (This Chapter vs Later)

| Type | Scope | When |
|------|-------|------|
| **ClusterIP** | In-cluster only | **This chapter** — Pod-to-Pod |
| **NodePort** | Host port on node | Debugging; rare in production |
| **LoadBalancer** | Cloud LB | AWS polish ([Chapter 14](../part-ii-aws/14-routing-traffic-to-hermes.md)) |
| **Ingress** | HTTP routing | [Chapter 23](23-ingress.md) — `laptop → cluster` |

Start with **ClusterIP**. External access comes after in-cluster routing works.

---

## Architecture

### Before and After Service

```text
Before (Ch 21 only):
  curl → 10.42.0.17:80   ← Pod IP; breaks on restart

After (Ch 22):
  curl → nginx-service:80 → kube-proxy → any healthy Pod
```

Hermes will never hard-code llama.cpp Pod IPs—it will use a Service name.

---

## Walkthrough

### Step 1 — Create the Service

**[infrastructure/kubernetes/ch22-nginx-service.yaml](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch22-nginx-service.yaml)**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply:

```bash
kubectl apply -f infrastructure/kubernetes/ch22-nginx-service.yaml
```

Alternative (imperative, same result):

```bash
kubectl expose deployment nginx-deployment --port=80 --target-port=80 --name=nginx-service
```

Prefer the manifest—declarative state you can commit.

### Step 2 — Inspect Service and Endpoints

```bash
kubectl get svc nginx-service
kubectl get endpoints nginx-service
kubectl get pods -l app=nginx -o wide
```

Expected:

- Service **CLUSTER-IP** (e.g. `10.43.x.x`) on port 80
- Endpoints list **three** Pod IPs (matches replica count)
- Those IPs match `kubectl get pods -l app=nginx`

If Endpoints are empty, selector labels do not match Pod template labels—fix `app: nginx` on both sides.

### Step 3 — Reach the Service from Another Pod

Create a temporary client Pod:

```bash
kubectl run curl-test \
  --restart=Never \
  --image=curlimages/curl:8.5.0 \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/curl-test --timeout=60s
```

Call the Service by **DNS name**:

```bash
kubectl exec curl-test -- curl -s -o /dev/null -w "%{http_code}\n" http://nginx-service/
```

Expected: `200`

Try the fully qualified name:

```bash
kubectl exec curl-test -- curl -s -o /dev/null -w "%{http_code}\n" \
  http://nginx-service.default.svc.cluster.local/
```

Clean up the client:

```bash
kubectl delete pod curl-test
```

You routed to nginx **without knowing any Pod IP**.

### Step 4 — Service Survives Pod Replacement

Delete one nginx Pod:

```bash
POD=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD"
```

Wait for replacement, then verify Service still works:

```bash
kubectl wait --for=condition=Available deployment/nginx-deployment --timeout=120s
kubectl run curl-once --restart=Never --image=curlimages/curl:8.5.0 \
  -- curl -s -o /dev/null -w "%{http_code}\n" http://nginx-service/
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/curl-once --timeout=60s
kubectl logs curl-once
kubectl delete pod curl-once
```

Still **200**—Service and DNS unchanged; Endpoints updated to the new Pod IP.

### Step 5 — Port-Forward vs Service

| Method | Use |
|--------|-----|
| `kubectl port-forward pod/...` | Debug one Pod from laptop (Ch 20) |
| `kubectl port-forward svc/nginx-service 8080:80` | Debug Service load balancing from laptop |
| `curl http://nginx-service/` from inside cluster | **Production pattern** for Pod-to-Pod |

External users will use **Ingress** (Chapter 23), not port-forward.

### Step 6 — Cleanup (Optional)

Remove Service only—Deployment stays:

```bash
kubectl delete service nginx-service
```

Re-apply anytime with the manifest.

---

## Hands-on Lab

### Lab 22: Service Discovery

**Estimated Time:** 45 minutes

**Goal:** Expose `nginx-deployment` via ClusterIP Service; verify DNS and Endpoints.

**Steps:**

1. Confirm three nginx Pods Running
2. Apply `ch22-nginx-service.yaml`
3. Verify Service IP and three Endpoints
4. `curl` from `curl-test` Pod → HTTP 200
5. Delete one nginx Pod; confirm Service still returns 200
6. Document Service placement in State Layers

---

## Verification

- [ ] `nginx-service` exists with type **ClusterIP**
- [ ] Endpoints show three Pod IPs matching `app: nginx`
- [ ] In-cluster curl to `http://nginx-service/` returns **200**
- [ ] After Pod delete/replace, Service still reachable
- [ ] You can explain why Hermes should call llama.cpp by Service name

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Endpoints `<none>` | Selector mismatch | Compare Service `selector` with Pod labels |
| curl **000** or timeout | curl Pod not Ready; DNS lag | Wait for Ready; check `kubectl get pods` |
| Connection refused | targetPort wrong | nginx listens on 80; match `targetPort: 80` |
| Only one Pod in Endpoints | Deployment scaled down | `kubectl get deployment nginx-deployment` |
| Works by IP, not DNS | CoreDNS issue | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |

### Common Mistakes

**“I port-forwarded to a Pod—why do I need a Service?”**  
Port-forward is laptop debugging. In-cluster workloads use Services and DNS.

**“Can I use the Service ClusterIP from my laptop?”**  
ClusterIP is reachable **inside the cluster** only. Laptop access needs port-forward, NodePort, or Ingress.

---

## Review Questions

1. Why do Pod IPs make poor stable addresses?
2. What object lists the current Pod IPs behind a Service?
3. What label selector does `nginx-service` use?
4. Where does a Service sit in State Layers?
5. How will Hermes reach llama.cpp without Pod IPs?

---

## Key Takeaways

- **Pods are ephemeral** at the network layer; **Services are stable** handles to Pod sets
- Selectors + Endpoints connect Service definitions to live Pods automatically
- **Cluster DNS** resolves Service names—use this for Pod-to-Pod traffic
- Chapter 20 port-forward ≠ in-cluster Service routing
- Next: [Ingress](23-ingress.md)—HTTP from outside the cluster to Services

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Service** | Stable network endpoint targeting Pods by label selector. |
| **ClusterIP** | Default Service type; virtual IP reachable only inside the cluster. |
| **Endpoints** | List of Pod IP:port pairs backing a Service. |
| **selector** | Label query linking Service to Pods. |
| **kube-proxy** | Node component implementing Service routing (iptables/ipvs). |

---

## Further Reading

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Chapter 21: Deployments](21-deployments.md)

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

Ingress                ✗

Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

███████████████░░░░░░░ 75%
───────────────────────────────────────────────
```

Stable in-cluster routing works. Next: HTTP from outside the cluster.

---

## What's Next

[Chapter 23: Ingress](23-ingress.md) — route `laptop → Hermes` (and later HTTPS) to Services instead of port-forward hacks.

---

[← Chapter 21: Deployments](21-deployments.md) | [Next: Chapter 23 — Ingress →](23-ingress.md)
