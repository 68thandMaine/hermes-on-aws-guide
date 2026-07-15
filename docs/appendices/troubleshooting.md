---
sidebar_position: 5
description: "Common failures across the stack — symptom, diagnosis, fix."
---

# Appendix: Troubleshooting Guide

Distilled from chapter troubleshooting tables and [`infrastructure/hermes/runbooks/`](https://github.com/crudnicky/agent-to-aws-guide/tree/main/infrastructure/hermes/runbooks). When an alert fires, start with **symptom** → **diagnostic command** → **fix** → **chapter** for depth.

:::tip[First checks (any layer)]

```bash
echo $AWS_PROFILE $KUBECONFIG
aws sts get-caller-identity
kubectl get nodes
kubectl get pods -A | grep -v Running
```

:::

---

## AWS, SSH, and EC2

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| `AccessDenied` on AWS CLI | Wrong profile/keys | `aws sts get-caller-identity --profile hermes` | Re-run `aws configure --profile hermes` | 7 |
| SSH timeout to EC2 | SG wrong IP or no public IP | Check SG port 22; verify EIP | Update SG to `MY_IP/32`; confirm EIP associated | 9, 10 |
| `Permission denied (publickey)` | Wrong key or permissions | `ls -l ~/.ssh/*.pem` | Use correct `.pem`, mode `600`, user `ubuntu` | 9, 3 |
| SSH fails after IP change | Stale SG rule | Describe SG ingress | `authorize-security-group-ingress` with new IP | 10 |
| Host key warning | Instance rebuilt | — | `ssh-keygen -R $HERMES_PUBLIC_IP` | 10 |
| Locked out after UFW | Port 22 not allowed first | Console access | `ufw allow OpenSSH` before `enable` | 3, 10 |
| `InsufficientInstanceCapacity` | AZ out of instance type | Launch error text | Retry AZ; temporary smaller type | 9 |
| `/models` not mounted | cloud-init incomplete | `cat /var/log/hermes-bootstrap.log` | Wait; fix volumes per Ch 11 | 9 |
| k3s install fails | Low RAM or port conflict | `free -h`; `ss -tlnp \| grep 6443` | Free memory; clear ports | 13 |
| kubectl connection refused | Wrong kubeconfig IP | Check server URL in kubeconfig | Replace `127.0.0.1` with public IP | 13 |
| S3 `BucketAlreadyExists` | Global name collision | — | Use `hermes-platform-backups-${ACCOUNT_ID}` | 11 |
| Reboot drops EBS mounts | Bad fstab | `cat /etc/fstab`; `sudo mount -a` | UUID + `nofail` in fstab | 11 |

---

## Docker

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| `permission denied` on docker.sock | Not in docker group | `groups ubuntu` | `usermod -aG docker ubuntu`; re-login | 12 |
| Docker won't start after edit | Invalid `daemon.json` | `journalctl -u docker -n 20` | Fix JSON syntax | 12 |
| hello-world pull timeout | No outbound HTTPS | Test curl to registry | Check SG, UFW, VPC route | 12 |

---

## Kubernetes (general)

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| Cannot reach API server | Wrong KUBECONFIG | `echo $KUBECONFIG` | `export KUBECONFIG=~/.kube/hermes-k3s.yaml` | 20 |
| Node NotReady | CNI starting | `kubectl get nodes`; k3s logs | Wait 2 min | 13 |
| Pod **Pending** | Image pull or scheduling | `kubectl describe pod` | Check Events; node resources | 20 |
| `ImagePullBackOff` | Bad tag or no egress | `kubectl describe pod` | Fix image; check network | 20, 34 |
| `CrashLoopBackOff` | Container exits | `kubectl logs <pod>` | Fix command/image | 20 |
| Deployment won't scale | Wrong replicas in spec | `kubectl get deploy -o yaml` | Re-apply manifest | 21 |
| Rollout stuck | Bad image on new RS | `kubectl rollout status` | Fix tag; `rollout undo` | 21, 40 |
| `kubectl top` fails | metrics-server not ready | `kubectl -n kube-system get pods` | Wait; check metrics-server logs | 28 |
| HPA shows `unknown` | No CPU requests | `kubectl describe hpa` | Add resource requests to Deployment | 28 |
| RBAC no effect | Wrong ServiceAccount | `kubectl get pod -o yaml` | Set `serviceAccountName` on Deployment | 27, 41 |

---

## Networking and Ingress

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| Endpoints `<none>` | Selector mismatch | Compare Svc selector vs Pod labels | Align labels | 22 |
| In-cluster curl fails | Pod not Ready | `kubectl get endpoints` | Wait for Ready | 22 |
| Ingress **404** | Wrong Host header | `curl -v -H "Host: hermes.local"` | Match Ingress host rule | 23, 34 |
| Ingress **502/503** | No healthy backends | `kubectl get endpoints` | Fix readiness; scale Deployment | 23 |
| External curl timeout | SG/UFW blocks 80 | SG rules; `ufw status` | Allow port 80 | 23 |
| NetworkPolicy no effect | k3s CNI limits | Test connectivity | Document intent; Calico for strict enforcement | 27 |
| All Hermes traffic blocked | Policy too strict | `kubectl get netpol -n hermes` | Allow Traefik namespace | 41 |
| Worker can't reach Redis | Egress policy | Pod labels | Fix `part-of` label selectors | 41 |

---

## Storage

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| PVC **Pending** | No StorageClass | `kubectl get sc` | Check local-path provisioner | 24 |
| Data lost after Pod delete | Deleted PVC | `kubectl get pvc` | Retain PVC; use `claimName` | 24 |
| Disk full on node | Root EBS filling | `df -h` on node | Expand/clean; Ch 11 layout | 24 |
| Backup useless | Never tested restore | — | Quarterly restore drill | 40 |

---

## Helm

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| `cannot re-use a name` | Release exists | `helm list -A` | `helm uninstall` or new name | 25 |
| Install conflict | Manual resources same name | `kubectl get all` | Delete conflicting objects | 25 |
| Upgrade no-op | Same values | `helm history` | Change a value; use `helm diff` | 25 |

---

## Terraform and CI

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| Terraform access denied | Wrong profile | `echo $AWS_PROFILE` | `export AWS_PROFILE=hermes` | 29 |
| CIDR overlap | Manual VPC exists | `terraform plan` | Change CIDR or import | 29 |
| State lock | Interrupted apply | Lock message | Clear only if no other apply | 29 |
| CI plan fails credentials | Missing GitHub Secrets | Actions log | Add AWS secrets to repo | 30 |
| Apply on wrong branch | Workflow `if` | Review workflow YAML | Apply only on `main` | 30 |

---

## Secrets

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| `CreateContainerConfigError` | Missing Secret/CM | `kubectl describe pod` | Create referenced Secret | 26 |
| Config change not visible | Pod not restarted | Pod age vs CM version | `rollout restart` or delete Pod | 26, 31 |
| ExternalSecret sync error | IAM or wrong key | `kubectl describe externalsecret` | Fix SM name; IAM policy | 31 |
| Pod has old secret | No restart after sync | Compare resource versions | `kubectl rollout restart` | 31 |
| Secrets in Loki | Logged at startup | Loki query | Redact; log names only | 33, 41 |

---

## Monitoring and logging

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| monitoring Pods Pending | Insufficient RAM | `kubectl describe pod -n monitoring` | Reduce limits; bigger instance | 32 |
| Grafana login fails | Wrong admin password | `kubectl get secret -n monitoring` | Decode grafana secret | 32 |
| Alerts not firing | Wrong `release` label on rule | `kubectl get prometheusrule -o yaml` | Match Helm release name | 32 |
| No logs in Loki | Promtail not ready | `kubectl logs -n logging -l app=promtail` | Wait; fix DaemonSet | 33 |
| Loki datasource error | Wrong URL in Grafana | Test from Grafana pod | `http://logging-loki.logging.svc:3100` | 33 |
| High CPU on llama-server | Load or bad deploy | Grafana; rollout history | Scale; rollback model — [runbook](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/runbooks/high-cpu-model-server.md) | 32, 40 |

---

## Hermes, inference, and AI

| Symptom | Likely cause | Diagnostic | Fix | Ch |
|---------|--------------|------------|-----|-----|
| Hermes Pods Pending | Node out of CPU/RAM | `kubectl describe pod -n hermes` | Lower replicas in values | 34 |
| Workers redis FAIL | Redis not up | `kubectl get pods -n hermes -l app=redis` | Wait for Redis Running | 34 |
| Postgres CrashLoop | PVC permissions | Postgres logs | Check `subPath`; recreate PVC | 34 |
| Qdrant collection fails | Pod not ready | Port-forward 6333; curl `/` | Wait for Qdrant | 35 |
| Empty vector search | No points indexed | Collection info API | Run upsert demo script | 35 |
| llama-server CrashLoop | Missing GGUF | `ls /models` on node | Run `ch37-prepare-model-lab.sh` | 36 |
| llama OOMKilled | Model too large | `kubectl describe pod` | Smaller quant; more RAM | 36, 40 |
| Workers can't reach llama | Wrong service DNS | `kubectl get svc -n hermes` | Use `llama-server:8080` in namespace | 36 |
| GPU Pod Pending | No GPU allocatable | `kubectl describe node` | Device plugin; driver; label node | 37 |
| GPU OOM | Model too large for VRAM | `nvidia-smi` | Smaller quant; g5.2xlarge | 37 |
| Model on wrong node | Missing nodeSelector | Pod spec | `accelerator=nvidia` selector | 37 |
| All curls fail mid-rollout | Single API replica | `kubectl get deploy -n hermes` | Use `values-production-rollout.yaml` | 40 |
| Tool not found | Registry not mounted | Worker volume mounts | Mount `hermes-tool-registry` CM | 42 |
| Tool denied unexpectedly | Policy not loaded | Worker logs | Mount `hermes-tool-policy` CM | 41 |
| Tool allowed when should deny | Policy not enforced | agent_role in logs | Fix allowlist; default deny | 41 |
| Approval stuck | Worker not polling | `hermes_approvals` status | Resume task after approval row | 41 |
| Prompt injection concern | — | `hermes_tool_denied_total` metric | Architecture: auth at gateway, not prompt | 41 |

---

## Diagnostic cheat sheet

| I need to… | Command |
|------------|---------|
| See why a Pod won't start | `kubectl describe pod <name> -n <ns>` |
| Follow logs | `kubectl logs -f <pod> -n <ns>` |
| Test in-cluster HTTP | `kubectl run curl --rm -it --image=curlimages/curl -- curl -v http://<svc>/` |
| Check rollout | `kubectl rollout status deploy/<name> -n <ns>` |
| Verify IAM | `aws sts get-caller-identity` |
| Verify secret sync | `kubectl describe externalsecret -n <ns>` |
| Check node pressure | `kubectl top nodes`; `df -h` on EC2 |
| Trace Hermes action | Query `hermes_task_steps` by `trace_id` | 41 |

---

[← Cost Estimates](cost-estimates.md) | [Glossary →](glossary.md)
