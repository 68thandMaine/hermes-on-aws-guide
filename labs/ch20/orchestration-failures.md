# Lab 20 — Orchestration Failures Worksheet

Complete after reading [Chapter 20](../../docs/part-iv-kubernetes/20-why-kubernetes-exists.md).

## Cluster check

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes
kubectl get pods -A
```

- Node Ready? ______
- How many namespaces with Pods? ______

## Failure → evidence

| Failure | Evidence from your cluster | State Layer |
|---------|----------------------------|-------------|
| Death (restart / desired count) | | |
| Placement (which node) | | |
| Discovery (stable Service name) | | |
| Exposure (Ingress / Traefik / LB) | | |

## One system Pod

- Namespace / name: ________________
- Intent (what should be true): ________________
- API object type (Pod / Deployment / …): ________________

## Check

- [ ] No application Pods created in this lab
- [ ] Ready for [Chapter 21: Pods](../../docs/part-iv-kubernetes/21-pods.md)
