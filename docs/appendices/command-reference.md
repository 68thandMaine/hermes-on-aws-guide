---
sidebar_position: 2
description: "Every CLI command used in the book, organized by chapter."
---

# Appendix: Command Reference

Keep this appendix open while building Hermes. Commands are extracted from chapter labs and walkthroughs—grouped by chapter, with environment conventions first.

:::tip[Environment variables (use in Part II+)]

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-east-1
export KUBECONFIG=~/.kube/hermes-k3s.yaml
source ~/hermes-platform/notes/network-resources.env   # after Ch 8
source ~/hermes-platform/notes/controlplane.env        # after Ch 9
```

:::

## Quick index by CLI

| CLI | First appears | Peak chapters |
|-----|---------------|---------------|
| `aws` | 1, 7 | 7–11, 23, 29, 31 |
| `ssh` | 3 | 9–13, 23 |
| `docker` | 1, 12 | 12–13 |
| `kubectl` | 1, 13 | 20–43 |
| `helm` | 1, 25 | 25, 31–37, 40 |
| `terraform` | 1, 29 | 29–30 |
| `curl` | 3–4 | 22–23, 34–37, 40 |
| `psql` | 38 | 38 |
| `python3` | 42 | 42 (tool handler lab) |

## Repo helper scripts

| Script | Chapter |
|--------|---------|
| `./scripts/setup/check-prerequisites.sh` | 1 |
| `infrastructure/aws/cli/ch09-provision-controlplane.sh` | 9 |
| `infrastructure/aws/cli/ch10-establish-trust-remote.sh` | 10 |
| `infrastructure/aws/cli/ch11-storage-backup-baseline.sh` | 11 |
| `infrastructure/aws/cli/ch12-install-docker.sh` | 12 |
| `infrastructure/aws/cli/ch13-install-k3s.sh` | 13 |
| `infrastructure/aws/cli/ch31-create-hermes-api-secret.sh` | 31 |
| `infrastructure/aws/cli/ch35-init-hermes-memory-collection.sh` | 35 |
| `infrastructure/aws/cli/ch35-vector-retrieval-demo.sh` | 35 |
| `infrastructure/aws/cli/ch36-prepare-model-lab.sh` | 36 |
| `infrastructure/aws/cli/ch36-verify-llama-inference.sh` | 36 |
| `infrastructure/aws/cli/ch37-gpu-node-prep.sh` | 37 |

---

## Part I — Foundations

### Chapter 1 — Introduction

```bash
git clone <repo-url> && cd agent-to-aws-guide
./scripts/setup/check-prerequisites.sh
aws --version && terraform --version && docker --version && kubectl version --client
```

### Chapter 2 — How Computers Work

```bash
uname -a
lscpu                    # Linux; macOS: sysctl -n machdep.cpu.brand_string
free -h                  # Linux; macOS: vm_stat
df -h
ps aux | head -20
ps aux --sort=-%mem | head -5
```

### Chapter 3 — Linux

```bash
whoami && id && groups
chmod 600 ~/.ssh/personal-ai-cloud
ssh-keygen -t ed25519 -C "personal-ai-cloud" -f ~/.ssh/personal-ai-cloud
ssh-copy-id -i ~/.ssh/personal-ai-cloud.pub ubuntu@<SERVER_IP>
sudo ufw allow OpenSSH && sudo ufw enable
sudo systemctl status ssh
sudo journalctl -u nginx -n 30 --no-pager
ss -tlnp
curl -s https://checkip.amazonaws.com
```

### Chapter 4 — Networking

```bash
curl -s https://checkip.amazonaws.com
ip route                 # Linux; macOS: netstat -rn
traceroute ec2.us-east-1.amazonaws.com
dig +short ubuntu.com
ss -tlnp | head
```

---

## Part II — AWS & Platform

### Chapter 7 — AWS Account

```bash
aws configure --profile hermes
aws sts get-caller-identity --profile hermes
mkdir -p ~/hermes-platform/notes
```

### Chapter 8 — Network

```bash
# VPC, subnet, IGW, route table — see chapter for full create-* sequence
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --output table
aws ec2 describe-availability-zones --query 'AvailabilityZones[*].ZoneName'
source ~/hermes-platform/notes/network-resources.env
```

### Chapter 9 — EC2 Control Plane

```bash
bash infrastructure/aws/cli/ch09-provision-controlplane.sh
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
ssh -i ~/.ssh/hermes-controlplane-key.pem ubuntu@${PUBLIC_IP} 'cloud-init status --wait'
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"   # save cost when idle
```

### Chapter 10 — Trust

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')
aws ec2 authorize-security-group-ingress --group-id "$HERMES_SG_ID" --protocol tcp --port 22 --cidr "${MY_IP}/32"
ssh-keygen -R "$HERMES_PUBLIC_IP"
bash infrastructure/aws/cli/ch10-establish-trust-remote.sh
```

### Chapter 11 — Storage

```bash
bash infrastructure/aws/cli/ch11-storage-backup-baseline.sh
aws ec2 create-snapshot --volume-id "$MODELS_VOL" --description "hermes-models"
aws s3 cp manifest.txt "s3://${BUCKET}/manifests/ch11-baseline.txt"
ssh -i "$KEY" ubuntu@${HERMES_PUBLIC_IP} 'df -h / /models /data'
```

### Chapter 12 — Docker

```bash
bash infrastructure/aws/cli/ch12-install-docker.sh
docker run --rm hello-world
sudo systemctl is-active docker
```

### Chapter 13 — k3s

```bash
bash infrastructure/aws/cli/ch13-install-k3s.sh
scp -i "$KEY" ubuntu@${HERMES_PUBLIC_IP}:/etc/rancher/k3s/k3s.yaml ~/.kube/hermes-k3s.yaml
sed -i.bak "s/127.0.0.1/${HERMES_PUBLIC_IP}/" ~/.kube/hermes-k3s.yaml
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get nodes && kubectl get pods -A
```

---

## Part IV — Kubernetes

### Chapters 20–24 — Core objects

```bash
kubectl run hello-pod --image=nginx --restart=Never
kubectl apply -f infrastructure/kubernetes/ch21-nginx-deployment.yaml
kubectl scale deployment nginx-deployment --replicas=3
kubectl rollout status deployment/nginx-deployment
kubectl apply -f infrastructure/kubernetes/ch22-nginx-service.yaml
kubectl exec curl-test -- curl -s http://nginx-service/
kubectl apply -f infrastructure/kubernetes/ch23-nginx-ingress.yaml
curl -v -H "Host: nginx.local" http://<NODE_IP>/
kubectl apply -f infrastructure/kubernetes/ch24-app-data-pvc.yaml
kubectl get pvc && kubectl get storageclass
```

### Chapter 25 — Helm

```bash
helm install web infrastructure/helm/nginx-demo
helm upgrade web infrastructure/helm/nginx-demo --set replicaCount=2
helm history web && helm rollback web 1
helm uninstall web
```

### Chapter 26 — Config

```bash
kubectl apply -f infrastructure/kubernetes/ch26-app-config-configmap.yaml
kubectl apply -f infrastructure/kubernetes/ch26-app-secret.yaml
kubectl apply -f infrastructure/kubernetes/ch26-config-demo-pod.yaml
kubectl logs config-demo
```

### Chapter 27 — Security

```bash
kubectl apply -f infrastructure/kubernetes/ch27-rbac-hermes-reader.yaml
kubectl auth can-i list pods --as=system:serviceaccount:default:hermes-reader
kubectl apply -f infrastructure/kubernetes/ch27-networkpolicy-nginx.yaml
```

### Chapter 28 — Scaling

```bash
kubectl top nodes && kubectl top pods
kubectl apply -f infrastructure/kubernetes/ch28-nginx-hpa.yaml
kubectl get hpa nginx-deployment -w
```

---

## Part V — Infrastructure

### Chapter 29 — Terraform

```bash
cd infrastructure/aws/terraform/environments/dev
terraform init && terraform plan && terraform apply
terraform output && terraform destroy
```

### Chapter 31 — Secrets

```bash
AWS_PROFILE=hermes ./infrastructure/aws/cli/ch31-create-hermes-api-secret.sh
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
kubectl apply -f infrastructure/kubernetes/ch31-cluster-secret-store.yaml
kubectl apply -f infrastructure/kubernetes/ch31-external-secret-hermes-api.yaml
kubectl describe externalsecret hermes-api-secret
```

### Chapter 32 — Monitoring

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f infrastructure/helm/monitoring/values-k3s-lab.yaml
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
kubectl apply -f infrastructure/kubernetes/ch32-prometheusrule-hermes-lab.yaml
```

### Chapter 33 — Logging

```bash
helm upgrade --install logging grafana/loki-stack -n logging --create-namespace \
  -f infrastructure/helm/logging/values-k3s-lab.yaml
helm upgrade --install tempo grafana/tempo -n logging \
  -f infrastructure/helm/tempo/values-k3s-lab.yaml
```

---

## Part VI — AI Infrastructure

### Chapter 34 — Hermes lab

```bash
kubectl create namespace hermes
helm upgrade --install hermes-lab infrastructure/helm/hermes-lab \
  -n hermes -f infrastructure/helm/hermes-lab/values.yaml
curl -s -H "Host: hermes.local" "http://${NODE_IP}/"
kubectl logs -n hermes -l app.kubernetes.io/component=worker --tail=5
```

### Chapter 35 — Qdrant

```bash
helm upgrade --install hermes-qdrant qdrant/qdrant -n hermes \
  -f infrastructure/helm/qdrant/values-k3s-lab.yaml
./infrastructure/aws/cli/ch35-init-hermes-memory-collection.sh
./infrastructure/aws/cli/ch35-vector-retrieval-demo.sh
```

### Chapter 36 — Model serving

```bash
./infrastructure/aws/cli/ch36-prepare-model-lab.sh --check
helm upgrade --install llama-server infrastructure/helm/llama-server -n hermes \
  -f infrastructure/helm/llama-server/values.yaml
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml \
  -f infrastructure/helm/hermes-lab/values-with-llama.yaml
./infrastructure/aws/cli/ch36-verify-llama-inference.sh
```

### Chapter 37 — GPU

```bash
NODE_NAME=<node> ./infrastructure/aws/cli/ch37-gpu-node-prep.sh
kubectl apply -f infrastructure/kubernetes/ch37-nvidia-device-plugin.yaml
kubectl apply -f infrastructure/kubernetes/ch37-gpu-smoke-test-pod.yaml
helm upgrade --install llama-server-gpu infrastructure/helm/llama-server -n hermes \
  -f infrastructure/helm/llama-server/values-gpu.yaml
```

### Chapter 38 — Task schema

```bash
kubectl exec -n hermes deploy/hermes-postgres -- \
  psql -U hermes -d hermes -f /tmp/task-schema.example.sql
```

---

## Part VII — Hermes Platform

### Chapter 40 — Operations

```bash
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml \
  -f infrastructure/helm/hermes-lab/values-with-llama.yaml \
  -f infrastructure/helm/hermes-lab/values-production-rollout.yaml
kubectl rollout status deployment/hermes-api -n hermes
kubectl rollout undo deployment/hermes-api -n hermes
while true; do curl -sf -H "Host: hermes.local" http://$NODE_IP/ || echo FAIL; sleep 0.5; done
```

### Chapter 41 — Governance

```bash
kubectl create configmap hermes-tool-policy \
  --from-file=policy.yaml=infrastructure/hermes/tool-policy.example.yaml \
  -n hermes --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f infrastructure/kubernetes/ch41-rbac-hermes-worker.yaml
kubectl apply -f infrastructure/kubernetes/ch41-networkpolicy-hermes.yaml
kubectl auth can-i get secrets --as=system:serviceaccount:hermes:hermes-worker -n hermes
```

### Chapter 42 — Extensions

```bash
kubectl create configmap hermes-tool-registry \
  --from-file=registry.yaml=infrastructure/hermes/tool-registry.example.yaml \
  -n hermes --dry-run=client -o yaml | kubectl apply -f -
echo '{"owner":"org","repository":"hermes","title":"Lab"}' \
  | python3 infrastructure/hermes/tools/github.create-issue.example.py
```

### Chapter 43 — Production

```bash
kubectl get pods -n hermes
# Promotion: terraform plan/apply per environment; helm upgrade with env-specific -f chain
```

---

## Common kubectl patterns

```bash
kubectl get pods -A -o wide
kubectl describe pod <name> -n <ns>
kubectl logs <pod> -n <ns> --tail=50
kubectl exec -it <pod> -n <ns> -- sh
kubectl rollout restart deployment/<name> -n <ns>
kubectl port-forward -n <ns> svc/<service> <local>:<remote>
```

## Common helm patterns

```bash
helm template <release> <chart> -n <ns> -f values.yaml    # dry render
helm upgrade --install <release> <chart> -n <ns> -f values.yaml
helm get values <release> -n <ns>
helm uninstall <release> -n <ns>
```

---

[← Glossary](glossary.md) | [Repository Walkthrough →](repository-walkthrough.md)
