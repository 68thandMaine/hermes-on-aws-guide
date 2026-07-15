# AGENTS.md — Instructions for AI Assistants

This file orients AI coding agents working in **Building a Personal AI Cloud**.

## Project Summary

| | |
|---|---|
| **What** | Technical book (O'Reilly/Manning style) — hands-on cloud engineering |
| **Format** | Docusaurus site + Markdown chapters in `docs/` |
| **Goal** | Reader builds AWS → k3s infrastructure to run the **Hermes AI agent** in production |
| **Author** | Christopher Rudnicky |
| **Site** | https://crudnicky.github.io/agent-to-aws-guide/ |

## Non-Negotiables

1. **Hermes-centric** — The agent is the product. ULLR is optional integration context only.
2. **Why before how** — Explain mechanisms; don't dump command lists without context.
3. **Follow STYLE_GUIDE.md** — 14-section chapter template, RFC workflow, quality bar.
4. **Content lives in `docs/`** — Not `chapters/` (removed).
5. **Design before AWS** — Complete Chapter 6 before Part II provisioning.
6. **One ontology shift per layer** — Chapter 13 is the only platform ignition moment; later chapters exercise the control plane (see STYLE_GUIDE *Narrative Governance*).
7. **No new mental models after Ch 13** — Part IV+ chapters map to State Layers only; no new paradigms (see STYLE_GUIDE *Cognitive Governance*).
8. **Just-in-time Linux** — Do not block on Ch 3.4–3.7; teach commands when the platform needs them.
9. **Don't commit** unless the user explicitly asks.

## Read These First

| Priority | File | Why |
|----------|------|-----|
| 1 | `STYLE_GUIDE.md` | Voice, structure, Hermes rules, Docusaurus conventions |
| 2 | `SUMMARY.md` | TOC + what's draft vs planned |
| 3 | `.cursor/rules/` | Cursor-specific rules (auto-loaded in this repo) |
| 4 | `CONTRIBUTING.md` | PR/CI workflow |

## What's Done vs In Progress

### Infrastructure ✅

- Docusaurus 3 site with Mermaid, local search, GitHub Pages deploy
- 45-chapter scaffold across 7 parts + appendices
- CI: markdownlint, link validation, `npm run build`
- Phase 0 docs: README, STYLE_GUIDE, SUMMARY, CHANGELOG

### Content ✏️ (draft quality)

| Chapter | File | Notes |
|---------|------|-------|
| 1 | `docs/part-i-foundations/01-introduction.md` | Laptop vs Codespaces vs own cloud |
| 2 | `docs/part-i-foundations/02-how-computers-work.md` | CPU/RAM/storage/network mental model |
| 3 | `docs/part-i-foundations/03-linux.md` | Server-first Linux; Sections 3.1–3.3 written; 3.4–3.7 + labs remain |
| 4 | `docs/part-i-foundations/04-networking.md` | Full draft — OSI subset, TCP/UDP, DNS, CIDR, NAT, Lab 4 |
| 5 | `docs/part-i-foundations/05-virtualization.md` | Full draft — hypervisors, VMs vs containers, EC2/EBS/AMI, Lab 5 |
| 6 | `docs/part-i-foundations/06-designing-the-hermes-platform.md` | Platform design before AWS; Hermes/llama.cpp as separate services |
| 7 | `docs/part-ii-aws/07-provisioning-aws-account.md` | Full draft — account, MFA, billing alarm, hermes-admin, CLI |
| 8 | `docs/part-ii-aws/08-creating-network-for-hermes.md` | Full draft — Concept/Design/Implementation; VPC, IGW, subnet, routes |
| 9 | `docs/part-ii-aws/09-provisioning-hermes-server.md` | Full draft — hermes-controlplane-01, cloud-init, dual EBS, IaC artifacts |
| 10 | `docs/part-ii-aws/10-establishing-trust.md` | Full draft — trust boundaries, EDR-0003, SG + UFW + sshd |
| 11 | `docs/part-ii-aws/11-persistent-storage.md` | Full draft — three EBS tiers, snapshots, S3, restore test, EDR-0004 |
| 12 | `docs/part-ii-aws/12-building-the-application-platform.md` | Full draft — Docker platform, data-root on /data/docker, EDR-0005 |
| 13 | `docs/part-ii-aws/13-the-first-control-plane.md` | Full draft — k3s, EDR-0006 |
| 14 | `docs/part-ii-aws/14-routing-traffic-to-hermes.md` | Full draft — Route 53, cert-manager, Let's Encrypt, EDR-0009 |
| 15 | `docs/part-ii-aws/15-observing-hermes-platform.md` | Full draft — CloudWatch baseline, EDR-0007 |
| 16 | `docs/part-ii-aws/16-managing-platform-costs.md` | Full draft — budgets/tags, EDR-0008 |

### Content ⬜ (stubs only)

Most chapters in Parts III–VII (beyond drafted Part IV–VII chapters listed in SUMMARY) remain planned stubs. Do not assume undeclared chapters have content.

## Repository Map

```
docs/                 Book chapters (edit these)
infrastructure/       cloud-init, cli, edr, terraform (early IaC artifacts)
labs/                 Lab worksheets and assets
diagrams/             Diagram source files
scripts/ci/           Link validator
sidebars.ts           Navigation
docusaurus.config.ts  Site config
src/css/custom.css    Theme overrides
```

## Common Tasks

### Write or expand a chapter

1. Read `STYLE_GUIDE.md` section template
2. Edit the file under `docs/part-*/`
3. Use Hermes-centric framing where applicable
4. Add/update lab assets in `labs/chNN/`
5. Sync glossary → `docs/appendices/glossary.md`
6. Update `SUMMARY.md` status
7. Verify: `npm run build`

### Preview the site

```bash
npm install
npm start
# http://localhost:3000/agent-to-aws-guide/
```

### Cross-link between chapters

From `docs/part-i-foundations/03-linux.md` to EC2:

```markdown
[Chapter 9: Provisioning the Hermes Server](../part-ii-aws/09-provisioning-hermes-server.md)
```

## Platform Architecture (target end state)

```text
Internet → AWS (VPC, EC2 Ubuntu) → Docker → k3s
  → Hermes Agent + PostgreSQL + Redis
  → Agent Tools (weather, etc.) + llama.cpp (llama-server)
  → Production operations
```

## Defaults

- AWS home region: **`us-west-2`**
- EC2 OS: **Ubuntu Server LTS** (`ubuntu` user)
- Kubernetes: **k3s**
- IaC: **Terraform** (Part V)
- SSH keys: ED25519

## Cursor Rules

Detailed rules live in `.cursor/rules/`:

| Rule file | Scope |
|-----------|-------|
| `00-project-context.mdc` | Always applied — project overview |
| `01-chapter-writing.mdc` | `docs/**/*.md` |
| `02-docusaurus-and-ci.mdc` | Site config and CI |

When in doubt, re-read `STYLE_GUIDE.md` and check `SUMMARY.md` for current chapter status.
