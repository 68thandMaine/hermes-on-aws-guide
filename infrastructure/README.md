# Infrastructure as Code — Hermes Platform

Every Part II+ implementation chapter adds artifacts here. Manual steps become reproducible scripts today; Terraform modules in Part V.

```
infrastructure/
├── aws/
│   ├── cloud-init/     # EC2 user-data — servers configure themselves
│   ├── cli/            # AWS CLI commands and chapter scripts
│   └── terraform/      # Part V — modules + environments (Ch 29+)
├── kubernetes/         # Manifests for Part IV+ (apply with kubectl)
├── hermes/             # Task model + runtime contracts (Part VI+)
└── helm/               # Helm charts (Part IV Ch 25+)
    ├── nginx-demo/     # Packages Deployment + Service + Ingress
    ├── monitoring/     # kube-prometheus-stack values (Ch 32)
    ├── logging/        # Loki stack values (Ch 33)
    ├── tempo/          # Tempo values — optional tracing (Ch 33)
    ├── hermes-lab/     # Hermes system instantiation (Ch 34)
    ├── qdrant/         # Qdrant values — semantic memory (Ch 35)
    └── llama-server/   # llama.cpp inference (Ch 36)
```

## Conventions

- **cloud-init** scripts are idempotent where possible and logged to `/var/log/hermes-bootstrap.log`
- **cli** scripts require `AWS_PROFILE=hermes` and sourced notes from `~/hermes-platform/notes/`
- **Never commit** private keys (`.pem`) or secrets

## Chapter index

| Chapter | Artifacts |
|---------|-----------|
| 8 | CLI commands in chapter prose; network IDs in local notes |
| 9 | `cloud-init/hermes-controlplane-bootstrap.sh`, `cli/ch09-provision-controlplane.sh` |
| 10 | `cli/ch10-establish-trust-remote.sh`, `edr/EDR-0003-key-based-ssh.md` |
| 11 | `cli/ch11-storage-backup-baseline.sh`, `edr/EDR-0004-separate-storage-tiers.md` |
| 12 | `cli/ch12-install-docker.sh`, `edr/EDR-0005-containers-as-deployment-unit.md` |
| 13 | `cli/ch13-install-k3s.sh`, `edr/EDR-0006-single-node-k3s-control-plane.md` |
| 14 | `cli/ch14-routing-baseline.sh`, `edr/EDR-0009-public-https-entrypoint.md` |
| 15 | `cli/ch15-cloudwatch-baseline.sh`, `edr/EDR-0007-aws-cloudwatch-baseline.md` |
| 16 | `cli/ch16-cost-baseline.sh`, `edr/EDR-0008-cost-governance-baseline.md` |
| 21 | `kubernetes/ch21-nginx-deployment.yaml` |
| 22 | `kubernetes/ch22-nginx-service.yaml` |
| 23 | `kubernetes/ch23-nginx-ingress.yaml` |
| 24 | `kubernetes/ch24-app-data-pvc.yaml`, `kubernetes/ch24-storage-demo-pod.yaml` |
| 25 | `helm/nginx-demo/` chart |
| 26 | `kubernetes/ch26-app-config-configmap.yaml`, `ch26-app-secret.yaml`, `ch26-config-demo-pod.yaml` |
| 27 | `kubernetes/ch27-rbac-hermes-reader.yaml`, `ch27-networkpolicy-nginx.yaml` |
| 28 | `kubernetes/ch28-nginx-hpa.yaml` |
| 29 | `terraform/modules/network/`, `terraform/environments/dev/` |
| 30 | `.github/workflows/terraform.yml` |
| 31 | `cli/ch31-create-hermes-api-secret.sh`, `terraform/modules/secrets/`, `kubernetes/ch31-*` |
| 32 | `helm/monitoring/values-k3s-lab.yaml`, `kubernetes/ch32-*` |
| 33 | `helm/logging/values-k3s-lab.yaml`, `helm/tempo/values-k3s-lab.yaml`, `kubernetes/ch33-*` |
| 34 | `helm/hermes-lab/` chart |
| 35 | `helm/qdrant/values-k3s-lab.yaml`, `cli/ch35-init-hermes-memory-collection.sh`, `cli/ch35-vector-retrieval-demo.sh` |
| 36 | `helm/llama-server/`, `helm/hermes-lab/values-with-llama.yaml`, `cli/ch36-*` |
| 37 | `helm/llama-server/values-gpu.yaml`, `helm/hermes-lab/values-dual-inference.yaml`, `kubernetes/ch37-*`, `cli/ch37-gpu-node-prep.sh` |
| 38 | `hermes/task-schema.example.sql` |
| 39 | `hermes/coordinator-decomposition.example.json` |
| 40 | `helm/hermes-lab/values-production-rollout.yaml`, `hermes/runbooks/`, `hermes/slo.example.yaml` |
