# Changelog

All meaningful revisions to *Building a Personal AI Cloud* are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Changed

- Editorial: local inference standardized on **llama.cpp** (`llama-server`)—removed Ollama as primary path; Ch 36 "Why not Ollama"; glossary, diagrams, references, labs index updated
- Appendices: Command Reference, Repository Walkthrough, Cost Estimates, Troubleshooting Guide — reference manual; glossary expanded
- Chapter 44: The Platform You Built — retrospective capstone
- Chapter 43: From Development to Production — production payoff; readiness assessment; environment promotion; synthesis (last technical chapter)
- Chapter 42: Extending Hermes — capability layer; tool contracts, registry, implementation, policy; extension checklist; platform-stable growth philosophy
- Chapter 41: Security, Governance, and Trust — tool gateway, agent_role policy, approval queue, audit trail; RBAC/NetworkPolicy manifests; platform security boundary principle
- Chapter 40: Operating Hermes in Production — operator shift; rolling deploy/rollback; backups/DR/SLOs/runbooks
- Chapter 39: Distributed Cognitive Execution — Hermes as OS for agents; coordinator pattern; state-based agent coordination
- Chapter 38: The Hermes Reasoning Loop — task-driven runtime; worker-owned loop; memory/inference/tools; durable state schema
- Chapter 37: GPU Instances — g5 + device plugin; llama-server-gpu; dual-path inference; heterogeneous compute
- Chapter 36: Model Serving — llama.cpp on k3s; hostPath /models; llama-server chart; worker wiring; bounded CPU cognition
- Chapter 35: Vector Databases — Qdrant semantic memory; three memory layers; RAG write/read paths; lab retrieval demo
- Chapter 34: Running Hermes — hermes-lab Helm stack; API/workers/model/Redis/Postgres; first system instantiation
- Chapter 33: Logging & Tracing — Loki + Promtail; LogQL; structured logs; OTel/Tempo concepts; observability triad complete
- Chapter 32: Monitoring — kube-prometheus-stack on k3s; Grafana; PrometheusRules; metrics-server vs Prometheus; HPA correlation
- Chapter 31: Secrets Management — AWS SM + ESO sync; IAM scoping; infra vs runtime credential domains; k3s lab auth
- Chapter 30: GitHub Actions — validate/plan/apply pipeline; `terraform.yml`; CI as control-plane actor; Ch 31 preview
- Chapter 29: Terraform — IaC narrative; network module codifies Ch 8; `environments/dev` lab; Part V begins; platform status network-as-code
- Chapter 28: Scaling — HPA, metrics-server, load lab; k3s single-node limits; platform status 94%
- Chapter 27: Security — RBAC read-only SA, NetworkPolicy deny/allow; k3s enforcement notes; platform status 91%
- Chapter 26: Configuration — ConfigMaps/Secrets injection lab; pre-Hermes config→security ordering; Ch 27–44 renumbered (+1)
- Chapter 24: Storage — PVC, local-path on k3s, persistence lab; platform status 82%
- Chapter 23: Ingress — Traefik on k3s, host routing, external curl; `ch23-nginx-ingress.yaml`; platform status 78%
- Chapter 22: Services — ClusterIP, DNS, Endpoints; `ch22-nginx-service.yaml`; platform status 75%
- Chapter 21: Deployments — desired state, self-healing, rollout intro; manifest in `infrastructure/kubernetes/`; platform status 72%
- Chapter 20: Pods — execution-only first workload; State Layer mapping; platform status 68%
- STYLE_GUIDE — cognitive governance: no new mental models after Ch 13; State Layer litmus test; execution-only chapter template
- Part VII Ch 43 reframed as capstone closure (*The Platform You Built*); SUMMARY project status (design vs execution)
- STYLE_GUIDE — narrative governance: one ontology shift per layer; post-Ch-13 hard boundary; exercise-don't-philosophize rule
- Chapter 13 — state-change awareness, Chapter 6 callback, Declarative Reality, State Layers, "The Boundary" closing
- Chapter 15 stub — observability framed as *How do I see what the platform is doing?*

### Added

- Chapter 13: The First Control Plane — k3s install, server→scheduler narrative, EDR-0006, platform status 65%
- `infrastructure/aws/cli/ch13-install-k3s.sh` — single-node k3s server + laptop kubeconfig
- Chapter 12: Building the Application Platform — Docker, server→platform narrative, EDR-0005
- STYLE_GUIDE — platform layering (Infrastructure → Platform → Applications); k8s before Hermes
- Chapter 9 updated — three EBS volumes (`hermes-root`, `hermes-models`, `hermes-data`); mounts `/models`, `/data`
- Engineering Decision Records (`infrastructure/edr/`) — recurring pattern for implementation chapters
- `infrastructure/` tree — cloud-init, cli, terraform placeholder (early IaC mindset)
- STYLE_GUIDE — guided build three layers, AWS `hermes-*` naming convention
- Part II restructure — Hermes-centric chapter titles; logical order (network before server); renamed files
- STYLE_GUIDE — "Why this matters for Hermes" admonition, platform status template, just-in-time Linux
- Chapter 3 — just-in-time Linux note; Sections 3.4–3.7 deferred until platform needs them
- Lab 6: `labs/ch06/platform-design.md`
- Diagram: `diagrams/hermes-platform-services.mmd`
- Chapter 1: Introduction — full draft framing laptop vs Codespaces vs own cloud
- Chapter 2: How Computers Actually Work — CPU/RAM/storage/network mental model
- Chapter 3: Linux — Section 3.3 processes, daemons, systemd (Docker/K8s bridge)
- Chapter 3: Linux — Section 3.2 users, groups, permissions (octal, sudo, AWS context)
- Phase 0 architecture documents: `README.md`, `SUMMARY.md`, `STYLE_GUIDE.md`
- Expanded table of contents — 43 chapters across 7 parts
- RFC-style chapter workflow and four-question quality bar
- `CHANGELOG.md` for tracking revisions
- CI workflow: Markdown lint and internal link validation
- Software-project workflow: branch-per-chapter, PR-per-chapter conventions in `CONTRIBUTING.md`

### Changed

- Part II renumbered — Ch 13 k3s (The First Control Plane); DNS/observability/cost moved to Ch 14–16 (optional polish)
- Part II renamed **AWS & Platform** — k3s is first platform chapter that produces behavior
- **Part II Hermes-centric titles** — e.g. "Provisioning Your AWS Account" not "AWS Foundation"; reordered (network Ch 8 before server Ch 9)
- Chapter 7 reframed as **Provisioning Your AWS Account** — first meaningful AWS work for Hermes
- Chapter 3 reframed as **server-first Linux** for the Hermes EC2 server
- Updated `SUMMARY.md`, `sidebars.ts`, `docs/index.mdx`, `AGENTS.md`, cursor rules
- **Hermes-centric platform focus** — Part VII renamed to Hermes Agent Platform; ULLR reframed as optional agent integration
- AI assistant rules: `.cursor/rules/`, `AGENTS.md`
- Migrated book from flat `chapters/` Markdown to **Docusaurus** (`docs/`, `sidebars.ts`, GitHub Pages)
- Local preview via `npm start`; CI runs `npm run build` on every PR
- `README.md` reframed around purpose, audience, and why-before-how
- `SUMMARY.md` restructured from 19 to 43 chapters
- `CONTRIBUTING.md` aligned with `STYLE_GUIDE.md`

### Removed

- `docs/part-i-foundations/06-containers.md` — container fundamentals covered in Part III (Ch 16–18)
- Legacy `chapters/` directory (content now in `docs/`)

---

## [0.1.0] — 2026-06-27

### Added

- Initial repository scaffold
- 19 chapter placeholder files (legacy structure)
- `LICENSE` (MIT), `CONTRIBUTING.md`, glossary, references, diagrams, labs index
- `scripts/setup/check-prerequisites.sh`

[Unreleased]: https://github.com/crudnicky/agent-to-aws-guide/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/crudnicky/agent-to-aws-guide/releases/tag/v0.1.0
