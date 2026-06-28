# Engineering Decision Records (EDR)

Short documents capturing **why** the Hermes platform is built the way it is—not just **what** was built.

Inspired by [Architecture Decision Records (ADRs)](https://adr.github.io/), scoped to operational and infrastructure choices readers make in Part II+.

## Format

Each EDR includes:

- **Context** — situation and constraints
- **Decision** — what we chose
- **Consequences** — tradeoffs (positive and negative)
- **Alternatives considered** — what we rejected and why

## Index

| ID | Title | Chapter |
|----|-------|---------|
| EDR-0003 | [Key-based SSH; disable password/root login](EDR-0003-key-based-ssh.md) | 10 — Establishing Trust |
| EDR-0004 | [Separate OS, models, and application data](EDR-0004-separate-storage-tiers.md) | 11 — Persistent Storage |
| EDR-0005 | [Adopt containers as deployment unit](EDR-0005-containers-as-deployment-unit.md) | 12 — Building the Application Platform |
| EDR-0006 | [Single-node k3s as the Hermes control plane](EDR-0006-single-node-k3s-control-plane.md) | 13 — The First Control Plane |

Earlier chapters (7–9) predate formal EDR numbering; retroactive EDRs may be added for account isolation, single public subnet, and dual-volume layout.

## Usage

- One or more EDRs at the end of each **implementation chapter**
- Link from the chapter's **Engineering Decision Record** section
- When revisiting a decision (e.g., opening HTTPS), add a new EDR that supersedes or extends the old one
