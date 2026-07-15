# Table of Contents

> **Building a Personal AI Cloud**
> *From Laptop to Production Kubernetes*

45 chapters across 7 parts. Status reflects the RFC workflow defined in [STYLE_GUIDE.md](STYLE_GUIDE.md).

---

## Project Status (Design vs Execution)

| Area | Status |
|------|--------|
| Mental model (State Layers) | ✅ Locked |
| Narrative & cognitive governance | ✅ Locked |
| Infrastructure progression (AWS → k3s) | ✅ Locked (Ch 7–13 drafted) |
| Layer separation (Infrastructure / Platform / Applications) | ✅ Locked |
| **Book completion** | 🔬 In progress — **instantiation**, not redesign |

**Design work is essentially done.** Remaining chapters turn knobs on a machine already defined in Chapters 6–13—they do not introduce new models.

### Remaining work (three phases)

| Phase | Chapters | Delivers | Mode |
|-------|----------|----------|------|
| **1. Platform completeness** | Part IV 20–29 (+ secrets, basic observability in Part V) | Operate the control plane: Pods, Deployments, Services, Ingress, storage | Execution only |
| **2. Hermes payoff** | Part VI–VII 35–44 | Hermes, llama.cpp, PostgreSQL, Redis in-cluster; end-to-end request flow | Application layer on existing model |
| **3. Closure capstone** | Part VII 45 (or dedicated finale) | Full system running; re-derive State Layers from reality; Ch 6 → Ch 13 → now | Reflection, not new ideas |

**Finish line:** `laptop → ingress → Hermes → model → response`

See [Book Completion](STYLE_GUIDE.md#book-completion-design-done-execution-remains) in STYLE_GUIDE.

---

## Front Matter

| | Title | File | Status |
|---|-------|------|--------|
| — | [Preface](docs/preface/00-preface.md) | `00-preface.md` | 📋 Outline |

---

## Part I — Foundations

*Computer fundamentals, Linux for your Hermes server, networking, virtualization—then platform design before any AWS provisioning.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 1 | [Introduction](docs/part-i-foundations/01-introduction.md) | `01-introduction.md` | ✏️ Draft |
| 2 | [How Computers Actually Work](docs/part-i-foundations/02-how-computers-work.md) | `02-how-computers-work.md` | ✏️ Draft |
| 3 | [Linux](docs/part-i-foundations/03-linux.md) | `03-linux.md` | ✏️ Draft |
| 4 | [Networking](docs/part-i-foundations/04-networking.md) | `04-networking.md` | ✏️ Draft |
| 5 | [Virtualization](docs/part-i-foundations/05-virtualization.md) | `05-virtualization.md` | ✏️ Draft |
| 6 | [Designing the Hermes Platform](docs/part-i-foundations/06-designing-the-hermes-platform.md) | `06-designing-the-hermes-platform.md` | ✏️ Draft |

---

## Part II — AWS & Platform

*Infrastructure on AWS, then the application platform—Docker and k3s—before deploying Hermes.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 7 | [Provisioning Your AWS Account](docs/part-ii-aws/07-provisioning-aws-account.md) | `07-provisioning-aws-account.md` | ✏️ Draft |
| 8 | [Creating the Network for Hermes](docs/part-ii-aws/08-creating-network-for-hermes.md) | `08-creating-network-for-hermes.md` | ✏️ Draft |
| 9 | [Provisioning the Hermes Server](docs/part-ii-aws/09-provisioning-hermes-server.md) | `09-provisioning-hermes-server.md` | ✏️ Draft |
| 10 | [Establishing Trust](docs/part-ii-aws/10-establishing-trust.md) | `10-establishing-trust.md` | ✏️ Draft |
| 11 | [Persistent Storage for Models and Data](docs/part-ii-aws/11-persistent-storage.md) | `11-persistent-storage.md` | ✏️ Draft |
| 12 | [Building the Application Platform](docs/part-ii-aws/12-building-the-application-platform.md) | `12-building-the-application-platform.md` | ✏️ Draft |
| 13 | [The First Control Plane](docs/part-ii-aws/13-the-first-control-plane.md) | `13-the-first-control-plane.md` | ✏️ Draft |
| 14 | [Routing Traffic to Hermes](docs/part-ii-aws/14-routing-traffic-to-hermes.md) | `14-routing-traffic-to-hermes.md` | ✏️ Draft |
| 15 | [Observing the Hermes Platform](docs/part-ii-aws/15-observing-hermes-platform.md) | `15-observing-hermes-platform.md` | ✏️ Draft |
| 16 | [Managing Platform Costs](docs/part-ii-aws/16-managing-platform-costs.md) | `16-managing-platform-costs.md` | ✏️ Draft |

---

## Part III — Containers

*Docker, Compose, and the Open Container Initiative.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 17 | [Docker](docs/part-iii-containers/17-docker.md) | `17-docker.md` | 📋 Outline |
| 18 | [Docker Compose](docs/part-iii-containers/18-docker-compose.md) | `18-docker-compose.md` | ⬜ Planned |
| 19 | [OCI](docs/part-iii-containers/19-oci.md) | `19-oci.md` | ⬜ Planned |

---

## Part IV — Kubernetes

*From first principles through production operations.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 20 | [Why Kubernetes Exists](docs/part-iv-kubernetes/20-why-kubernetes-exists.md) | `20-why-kubernetes-exists.md` | 📋 Outline |
| 21 | [Pods](docs/part-iv-kubernetes/21-pods.md) | `21-pods.md` | ✏️ Draft |
| 22 | [Deployments](docs/part-iv-kubernetes/22-deployments.md) | `22-deployments.md` | ✏️ Draft |
| 23 | [Services](docs/part-iv-kubernetes/23-services.md) | `23-services.md` | ✏️ Draft |
| 24 | [Ingress](docs/part-iv-kubernetes/24-ingress.md) | `24-ingress.md` | ✏️ Draft |
| 25 | [Storage](docs/part-iv-kubernetes/25-kubernetes-storage.md) | `25-kubernetes-storage.md` | ✏️ Draft |
| 26 | [Helm](docs/part-iv-kubernetes/26-helm.md) | `26-helm.md` | ✏️ Draft |
| 27 | [Configuration (ConfigMaps & Secrets)](docs/part-iv-kubernetes/27-configuration-configmaps-secrets.md) | `27-configuration-configmaps-secrets.md` | ✏️ Draft |
| 28 | [Security](docs/part-iv-kubernetes/28-kubernetes-security.md) | `28-kubernetes-security.md` | ✏️ Draft |
| 29 | [Scaling](docs/part-iv-kubernetes/29-scaling.md) | `29-scaling.md` | ✏️ Draft |

---

## Part V — Infrastructure

*Terraform, CI/CD, secrets, and platform observability.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 30 | [Terraform](docs/part-v-infrastructure/30-terraform.md) | `30-terraform.md` | ✏️ Draft |
| 31 | [GitHub Actions](docs/part-v-infrastructure/31-github-actions.md) | `31-github-actions.md` | ✏️ Draft |
| 32 | [Secrets Management](docs/part-v-infrastructure/32-secrets-management.md) | `32-secrets-management.md` | ✏️ Draft |
| 33 | [Monitoring](docs/part-v-infrastructure/33-monitoring.md) | `33-monitoring.md` | ✏️ Draft |
| 34 | [Logging & Tracing](docs/part-v-infrastructure/34-logging.md) | `34-logging.md` | ✏️ Draft |

---

## Part VI — AI Infrastructure

*Hermes, vectors, model serving, GPUs, and agent architecture.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 35 | [Running Hermes](docs/part-vi-ai/35-running-hermes.md) | `35-running-hermes.md` | ✏️ Draft |
| 36 | [Vector Databases](docs/part-vi-ai/36-vector-databases.md) | `36-vector-databases.md` | ✏️ Draft |
| 37 | [Model Serving](docs/part-vi-ai/37-model-serving.md) | `37-model-serving.md` | ✏️ Draft |
| 38 | [GPU Instances](docs/part-vi-ai/38-gpu-instances.md) | `38-gpu-instances.md` | ✏️ Draft |
| 39 | [The Hermes Reasoning Loop](docs/part-vi-ai/39-ai-agent-architecture.md) | `39-ai-agent-architecture.md` | ✏️ Draft |

---

## Part VII — Hermes Agent Platform

*Operate, govern, extend, and promote the Hermes platform from lab to production.*

| # | Chapter | File | Status |
|---|---------|------|--------|
| 40 | [Distributed Cognitive Execution](docs/part-vii-hermes/40-distributed-cognitive-execution.md) | `40-distributed-cognitive-execution.md` | ✏️ Draft |
| 41 | [Operating Hermes in Production](docs/part-vii-hermes/41-operating-hermes-in-production.md) | `41-operating-hermes-in-production.md` | ✏️ Draft |
| 42 | [Security, Governance, and Trust](docs/part-vii-hermes/42-platform-governance.md) | `42-platform-governance.md` | ✏️ Draft |
| 43 | [Extending Hermes](docs/part-vii-hermes/43-extending-hermes.md) | `43-extending-hermes.md` | ✏️ Draft |
| 44 | [From Development to Production](docs/part-vii-hermes/44-from-development-to-production.md) | `44-from-development-to-production.md` | ✏️ Draft |
| 45 | [The Platform You Built](docs/part-vii-hermes/45-the-platform-you-built.md) | `45-the-platform-you-built.md` | ✏️ Draft |

---

## Appendices

| Appendix | Description | File |
|----------|-------------|------|
| A | [Glossary](docs/appendices/glossary.md) | `glossary.md` | ✏️ Draft |
| B | [Command Reference](docs/appendices/command-reference.md) | `command-reference.md` | ✏️ Draft |
| C | [Repository Walkthrough](docs/appendices/repository-walkthrough.md) | `repository-walkthrough.md` | ✏️ Draft |
| D | [AWS Cost Estimates](docs/appendices/cost-estimates.md) | `cost-estimates.md` | ✏️ Draft |
| E | [Troubleshooting Guide](docs/appendices/troubleshooting.md) | `troubleshooting.md` | ✏️ Draft |
| — | [References](docs/appendices/references.md) | `references.md` |
| — | [Diagram Index](docs/appendices/diagrams.md) | `diagrams.md` |
| — | [Lab Index](docs/appendices/labs.md) | `labs.md` |

---

## Reading Order

```
Part I    Foundations          Ch 1–6
Part II   AWS & Platform         Ch 7–16 (Ch 14–16 optional polish)
Part III  Containers             Ch 17–19 (depth; Ch 12 covers essentials)
Part IV   Kubernetes             Ch 20–29 (after Ch 13 k3s)
Part V    Infrastructure       Ch 30–34
Part VI   AI Infrastructure    Ch 35–39
Part VII  Hermes Agent         Ch 40–45
```

Chapters are sequential. Do not skip ahead unless you have equivalent experience with the prerequisite material.

---

## Status Legend

| Icon | RFC Step | Meaning |
|------|----------|---------|
| ⬜ Planned | — | Listed in TOC; outline not started |
| 📋 Outline | 1–2 | Outline written or legacy scaffold; needs RFC review |
| ✏️ Draft | 3 | Full prose; not lab-tested |
| 🔬 Lab tested | 5–6 | Lab and troubleshooting verified |
| ✅ Done | 9 | Quality bar met; ready for `main` |

---

## Legacy Scaffolds

Legacy scaffold files from the initial repository setup were removed during the Docusaurus migration. See git history for `chapters/LEGACY.md` and old filenames.

---

## Next Up

**Part VII and reference appendices drafted.** Next: lab-test chapters; expand command reference with full Ch 8–11 AWS sequences; flesh out Lab Index.

Suggested order: Config → Security → Scaling → Hermes stack → capstone (Ch 45).
