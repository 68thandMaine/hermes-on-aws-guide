---
sidebar_position: 3
description: "Every directory in the repository, mapped to book chapters."
---

# Appendix: Repository Walkthrough

The [agent-to-aws-guide](https://github.com/crudnicky/agent-to-aws-guide) repository is the **companion artifact** for the book—not an afterthought. This appendix maps every major directory to the chapter that introduced it.

```text
agent-to-aws-guide/
├── docs/                    # Book content (Docusaurus)
├── code/infrastructure/          # IaC, manifests, Helm, Hermes contracts
├── resources/labs/                    # Local notes templates (your machine)
├── code/scripts/                 # Setup and CI helpers
├── .github/workflows/       # CI/CD pipelines
├── resources/diagrams/                # Architecture source files
└── code/site/static/        # Site assets
```

---

## `docs/` — The book

| Path | Contents |
|------|----------|
| `docs/preface/` | Preface |
| `docs/part-i-foundations/` | Chapters 1–6 — foundations and Hermes design |
| `docs/part-ii-aws/` | Chapters 7–16 — AWS and platform substrate |
| `docs/part-iii-containers/` | Chapters 17–19 — Docker, Compose, OCI depth |
| `docs/part-iv-kubernetes/` | Chapters 20–29 — Kubernetes objects and ops |
| `docs/part-v-infrastructure/` | Chapters 30–34 — Terraform, CI, secrets, observability |
| `docs/part-vi-ai/` | Chapters 35–39 — Hermes runtime and AI infra |
| `docs/part-vii-hermes/` | Chapters 40–45 — operate, govern, extend, production, capstone |
| `docs/appendices/` | Reference material (this section) |
| `docs/index.mdx` | Book home page |

Built output: `npm run build` → `build/` (do not edit by hand).

---

## `code/infrastructure/` — What you deploy

See also [`code/infrastructure/README.md`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/README.md).

### `code/infrastructure/aws/`

| Path | Purpose | Chapter |
|------|---------|---------|
| `cloud-init/hermes-controlplane-bootstrap.sh` | EC2 first-boot: mounts, Docker prep | 9 |
| `cli/ch09-provision-controlplane.sh` | Consolidated EC2 provision script | 9 |
| `cli/ch10-establish-trust-remote.sh` | sshd + UFW hardening on server | 10 |
| `cli/ch11-storage-backup-baseline.sh` | S3 backup baseline | 11 |
| `cli/ch12-install-docker.sh` | Docker CE on Ubuntu | 12 |
| `cli/ch13-install-k3s.sh` | k3s control plane install | 13 |
| `cli/ch32-create-hermes-api-secret.sh` | AWS Secrets Manager seed | 31 |
| `cli/ch35-*.sh` | Qdrant collection init + retrieval demo | 35 |
| `cli/ch36-*.sh` | Model path prep + inference verify | 36 |
| `cli/ch38-gpu-node-prep.sh` | NVIDIA driver on GPU node | 37 |
| `terraform/modules/network/` | VPC, subnet, IGW module | 29 |
| `terraform/modules/secrets/` | Secrets Manager resources | 31 |
| `terraform/environments/dev/` | Dev Terraform workspace | 29 |

### `code/infrastructure/kubernetes/`

Flat YAML manifests applied with `kubectl apply -f`:

| File pattern | Chapter |
|--------------|---------|
| `ch22-nginx-deployment.yaml` | 21 |
| `ch23-nginx-service.yaml` | 22 |
| `ch24-nginx-ingress.yaml` | 23 |
| `ch24-*-pvc.yaml`, `ch25-storage-demo-pod.yaml` | 24 |
| `ch26-*` ConfigMap/Secret demo | 26 |
| `ch27-rbac-*`, `ch27-networkpolicy-*` | 27 |
| `ch29-nginx-hpa.yaml` | 28 |
| `ch31-*` External Secrets Operator | 31 |
| `ch32-*` PrometheusRule, ServiceMonitor | 32 |
| `ch33-*` Structured log demo, OTel example | 33 |
| `ch37-*` GPU device plugin, smoke test | 37 |
| `ch41-*` Hermes worker RBAC, NetworkPolicy | 41 |

### `code/infrastructure/helm/`

| Chart / values | Chapter |
|----------------|---------|
| `nginx-demo/` | 25 — first Helm chart |
| `monitoring/values-k3s-lab.yaml` | 32 — kube-prometheus-stack |
| `logging/values-k3s-lab.yaml` | 33 — Loki |
| `tempo/values-k3s-lab.yaml` | 33 — tracing |
| `hermes-lab/` | 34 — Hermes system chart |
| `hermes-lab/values-with-llama.yaml` | 36 |
| `hermes-lab/values-production-rollout.yaml` | 40 |
| `hermes-lab/values-dual-inference.yaml` | 37 |
| `qdrant/values-k3s-lab.yaml` | 35 |
| `llama-server/` + `values-gpu.yaml` | 36–37 |

### `code/infrastructure/hermes/`

Runtime contracts and governance—not application source code:

| Artifact | Chapter |
|----------|---------|
| `task-schema.example.sql` | 38 — durable tasks + audit steps |
| `coordinator-decomposition.example.json` | 39 — ski-trip task tree |
| `tool-policy.example.yaml` | 41 — agent_role authorization |
| `governance-schema.example.sql` | 41 — approval queue |
| `resource-governance.example.yaml` | 41 — cognitive limits |
| `tool-registry.example.yaml` | 42 — capability registration |
| `extension-checklist.example.yaml` | 42 — merge gate |
| `agent-roles-extension.example.yaml` | 42 — new roles |
| `tools/github.create-issue.*` | 42 — tool contract + handler |
| `production-readiness.example.yaml` | 43 — go-live checklist |
| `environment-promotion.example.yaml` | 43 — dev/staging/prod |
| `slo.example.yaml` | 40 — SLO targets |
| `runbooks/high-cpu-model-server.md` | 40 — incident procedure |

### `code/infrastructure/edr/`

Engineering Decision Records — *why* major choices were made (SSH keys, storage tiers, k3s, containers).

---

## `resources/labs/` — Your local notes

Templates for **your machine**—never commit secrets:

| Path | Chapter |
|------|---------|
| `resources/labs/ch06/platform-design.md` | 6 |
| `resources/labs/ch08/network-resources.md` | 8 |
| `resources/labs/ch09/controlplane-notes.md` | 9 |

Operator notes also live in `~/hermes-platform/notes/` (created in Ch 7–9).

---

## `code/scripts/` and `.github/`

| Path | Purpose |
|------|---------|
| `code/scripts/setup/check-prerequisites.sh` | Ch 1 toolchain verification |
| `code/scripts/ci/validate-links.sh` | Link checking |
| `.github/workflows/terraform.yml` | Ch 31 — Terraform CI |
| `.github/workflows/book-ci.yml` | Docusaurus build on PR |

---

## `resources/diagrams/` and `code/site/static/`

| Path | Purpose |
|------|---------|
| `resources/diagrams/*.mmd` | Mermaid source for architecture figures |
| `code/site/static/img/` | Logo, favicon, social card for the book site |

---

## Site configuration

| File | Purpose |
|------|---------|
| `docusaurus.config.ts` | Site URL, theme, plugins |
| `sidebars.ts` | Left navigation (parts and chapters) |
| `SUMMARY.md` | Human-readable table of contents |
| `STYLE_GUIDE.md` | Authoring conventions |
| `CHANGELOG.md` | Book revision history |

---

## How artifacts flow to production

```text
docs/ (you read)
    ↓
code/infrastructure/ (you apply)
    ↓
Git commit → GitHub Actions → Terraform / Helm → k3s cluster
```

The book and the repo stay in sync: every major lab has a corresponding file under `code/infrastructure/` or `code/scripts/`.

---

[← Command Reference](command-reference.md) | [Cost Estimates →](cost-estimates.md)
