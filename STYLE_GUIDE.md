# Style Guide

> Architecture document for *Building a Personal AI Cloud*.
> Every chapter, diagram, and lab follows the rules defined here.

---

## Purpose

Consistency is what makes a technical book feel polished. This guide defines:

- Voice and tone
- Chapter structure (mandatory sections)
- Quality bar (four questions every chapter must answer)
- RFC-style writing workflow
- Diagram and lab conventions
- Status definitions

If a chapter deviates from this guide, it is not done.

---

## Platform Focus — Hermes-Centric

This book builds infrastructure to run **Hermes**—an AI agent platform—not a generic cloud tutorial.

| Rule | Detail |
|------|--------|
| **Lead with Hermes** | Architecture diagrams, labs, and chapter goals describe what the agent needs and how it runs |
| **ULLR is integration context** | ULLR may appear as a data backend Hermes calls; document *integration points*, not ULLR as the primary product |
| **Every capstone serves the agent** | Weather pipelines, CI/CD, scaling, and DR chapters answer: *how does this help Hermes operate in production?* |
| **Avoid ULLR-first framing** | Do not title chapters, labs, or Part VII sections around ULLR; use "Hermes agent," "agent tools," "agent data sources" |
| **Local inference = llama.cpp** | Deploy **llama-server** (llama.cpp HTTP API)—not Ollama. GGUF on `/models`, Helm chart in `infrastructure/helm/llama-server/`. See [Chapter 36](docs/part-vi-ai/36-model-serving.md). |

When engineering content that touches ULLR, ask:

1. What does **Hermes** need from this system?
2. How does the agent **discover, call, and trust** the integration?
3. What does the operator see when the agent fails—not when ULLR fails in isolation?

Part VII is **Hermes Agent Platform** (`docs/part-vii-hermes/`), not a separate data-platform track.

### Hermes-Centric Chapter Titles (Part II+)

Part II chapters are **not** generic AWS tutorials. Each title answers a concrete question about the Hermes platform:

| Bad (product-first) | Good (platform-first) |
|---------------------|------------------------|
| AWS Overview | Provisioning Your AWS Account |
| VPC | Creating the Network for Hermes |
| EC2 | Provisioning the Hermes Server |

Apply the same pattern in later parts when naming chapters.

### Why This Matters for Hermes

Every implementation chapter includes **at least one** Docusaurus admonition tying decisions to the platform:

```markdown
:::note Why this matters for Hermes

We're enabling MFA before creating infrastructure because this AWS account will eventually hold the entire Hermes platform...

:::
```

Place it in **Background** or **Theory**—where the reader understands *why* before *how*.

### Hermes Platform Status Dashboard

Implementation chapters (Part II onward) end with a **Hermes Platform Status** section showing cumulative progress. Use this template; update checkmarks and progress bar per chapter:

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account            ✓
Billing Alerts         ✓
MFA                    ✓
IAM Administrator      ✓

VPC                    ✓
Subnet                 ✓
Internet Gateway       ✓
Route Table            ✓

EC2                    ✓
Ubuntu                 ✓
Cloud-init             ✓

Docker                 ✗
k3s                    ✗
Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

█████░░░░░░░░░░░░░░░░ 28%
───────────────────────────────────────────────
```

Chapter 7 ~10%, Chapter 8 ~18%, Chapter 9 ~28%. Update checkmarks as components come online. Part VII ends at 100%.

### State Layers (Platform Chapters)

From [Chapter 13](docs/part-ii-aws/13-the-first-control-plane.md) onward, platform and application chapters may reference this stack when introducing a new concept—show **where in the stack** it lives:

```text
Human Intent
    ↓
Kubernetes API (desired state)
    ↓
Scheduler
    ↓
Containers
    ↓
Linux Kernel
```

Use it when a reader might confuse "SSH into the server" with "operate the control plane." Not every chapter needs the full diagram—a one-line reference ("this lives at the API layer") is enough.

This is the **primary abstraction lens** for the rest of the book. Do not introduce parallel mental models in later parts—map new concepts (Ingress, Helm, Hermes tools, MCP servers) onto this stack instead.

### Just-in-Time Linux

Do **not** front-load exhaustive Linux content before the reader provisions infrastructure. [Chapter 3](docs/part-i-foundations/03-linux.md) Sections 3.1–3.3 provide baseline context; remaining topics (`apt`, `journalctl`, `systemctl`, `ufw`) are taught **when the Hermes platform needs them**—typically in Part II (SSH, security) and Part III–IV (services, logs).

Experienced engineers learn commands in context. This book follows that model.

### Guided Build — Three Layers (Implementation Chapters)

Part II+ is a **guided build**, not documentation. The reader should **never click a button until they understand why that button exists.**

Every implementation chapter maps to three layers:

| Layer | Question | Typical sections |
|-------|----------|------------------|
| **1. Concept** | What problem are we solving? | Background, opening Theory |
| **2. Design** | Why are we solving it this way? | Architecture, design tradeoffs in Theory |
| **3. Implementation** | What exact steps build it? | Walkthrough, Hands-on Lab, Verification |

Do not open the AWS console in **Walkthrough** until **Background**, **Theory**, and **Architecture** have answered *why* each resource will exist. Screenshot-driven steps without concept age poorly; mental models transfer across AWS UI changes.

### AWS Resource Naming Convention

Name every resource as if you will have many someday—even when you only create one:

| Resource | Example name | Pattern |
|----------|--------------|---------|
| VPC | `hermes-vpc` | `hermes-{purpose}` |
| Subnet | `hermes-public-use1a` | `hermes-{visibility}-{region-az}` |
| Internet Gateway | `hermes-igw` | `hermes-{type}` |
| Route table | `hermes-public-rt` | `hermes-{visibility}-rt` |
| Security group | `hermes-controlplane-sg` | `hermes-{role}-sg` |
| EC2 instance | `hermes-controlplane-01` | `hermes-{role}-{nn}` |

Use your home region's AZ suffix (`use1a` for `us-east-1a`, `usw2a` for `us-west-2a`, etc.). Consistent names make later scaling, Terraform, and debugging far easier.

### Infrastructure Artifacts (Early IaC)

Every **implementation chapter** (Part II+) adds reproducible artifacts under `infrastructure/`:

```text
infrastructure/
└── aws/
    ├── cloud-init/     # EC2 user-data — first-boot bootstrap
    ├── cli/              # AWS CLI commands / chapter scripts
    └── terraform/        # Reserved for Part V (may start empty)
```

| After chapter | Reader should have |
|---------------|-------------------|
| 9 | `cloud-init/hermes-controlplane-bootstrap.sh`, `cli/ch09-provision-controlplane.sh` |
| 28+ | Terraform modules mirroring manual resources |

Manual steps are not throwaway—they are the specification Terraform will codify. Never commit private keys (`.pem`) or secrets.

### Engineering Decision Records (EDR)

Implementation chapters end with an **Engineering Decision Record** in `infrastructure/edr/`:

```markdown
## Engineering Decision Record

**[EDR-NNNN: Title](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-NNNN-slug.md)**
```

Each EDR captures **Context**, **Decision**, **Consequences**, and **Alternatives considered**—mirroring ADRs used in production teams. By the end of the book, readers have infrastructure *and* a documented history of why it was built that way.

### Platform Layering (Infrastructure → Platform → Applications)

The book follows three layers—do not deploy Hermes until the platform layer is operational:

| Layer | Chapters (approx.) | Delivers |
|-------|-------------------|----------|
| **Infrastructure** | Part II 7–11 | AWS account, network, EC2, trust, persistence |
| **Platform** | Part II Ch 12–13 + Part IV | Docker runtime, k3s control plane, Kubernetes core objects |
| **Applications** | Part VI–VII | Hermes, llama.cpp, PostgreSQL, Redis |

**Reading order after Chapter 12:** Install k3s ([Chapter 13](docs/part-ii-aws/13-the-first-control-plane.md)), then learn Pods, Deployments, Services, Ingress, and storage in Part IV with **generic examples** before Part VI Hermes deploys. Part II chapters 14–16 (DNS, observability, cost) are optional AWS polish—return anytime. Part III (Docker/OCI depth) complements hands-on work but does not block Kubernetes.

### Narrative Governance: One Ontology Shift Per Layer

The book encodes a layered mental model. **Do not inflate the narrative**—only one **ontology shift** (a “everything changed” moment) per major layer. After the ignition point, chapters **exercise and refine**; they do not re-stage the same emotional beat.

| Layer | Ignition chapter | Shift (once) | What follows |
|-------|------------------|--------------|--------------|
| **Infrastructure** | Ch 7–11 | Stability—a trustworthy foundation on AWS | Refinement: network, trust, storage |
| **Runtime (prep)** | Ch 12 | Portability—containers as deployment unit | Preparation only; not the platform threshold |
| **Platform** | **Ch 13 only** | **Control plane emergence**—machine → scheduler with state | Part IV: exercise the API; optional Ch 14–16: AWS visibility/manipulation |
| **Kubernetes objects** | Part IV (≈ Ch 20+) | Declarative programming model (already introduced in Ch 13)—**apply it** | Pods, Deployments, Services: manipulation, not new philosophy |
| **Applications** | Part VI–VII | Hermes on the model—**deploy**, do not re-justify Kubernetes | Operations, tools, scaling |

**Hard rules for authors:**

1. **Chapter 13 is the only “system becomes a platform” moment.** No later chapter may replicate State 1 → State 2 → State 3 or another “snap into place” arc.
2. **Part IV chapters must not try to feel like Chapter 13.** Teach object types by *using* the live control plane. Reference **State Layers**; do not re-introduce declarative reality as a revelation.
3. **Hermes deploy chapters must not re-justify Kubernetes.** Assume the reader operates a system; show manifests, Services, and Ingress for Hermes components.
4. **After Chapter 13, close every platform chapter mindset with execution verbs:** see, declare, schedule, expose, persist—not discover, realize, or transform.

**Hard boundary statement** (Chapter 13 closing; do not repeat elsewhere as a “turning point”):

> From this point forward, we are no longer configuring a machine. We are operating a system.

Post-Ch-13 chapters answer operational questions, for example:

| Question type | Example chapter | Tone |
|---------------|-----------------|------|
| Visibility | Ch 15 — *How do I see what the platform is doing?* | Exercise |
| Manipulation | Part IV Pods/Deployments | Exercise |
| Expansion | Ingress, storage, Hermes stack | Exercise |
| AWS edge polish | Ch 14 DNS/TLS, Ch 16 cost | Refinement—not new frameworks |

**Primary abstraction lens** (reuse, do not replace): **State Layers** — Intent → API → Scheduler → Runtime → Kernel. LLM routing, MCP tools, and agent orchestration later map onto this stack; they do not introduce parallel mental models.

### Cognitive Governance: No New Mental Models After Chapter 13

**Narrative governance** limits emotional inflation (one ontology shift per layer). **Cognitive governance** limits *explanation* inflation—the temptation to keep introducing “new paradigms.”

After Chapter 13, the book separates:

| Type | When | Example |
|------|------|---------|
| **Conceptual events** | Ch 13 only (and earlier layer ignitions) | Machine → scheduler with state |
| **Operational learning** | Ch 20+ | Schedule a Pod; read logs; watch restart |

The reader already paid the cognitive cost of a new mental model at Chapter 13. **Do not spend that currency again.**

**Allowed after Chapter 13:**

- Reuse the **State Layers** stack
- Extend Kubernetes primitives (Pod → Deployment → Service → Ingress)
- Map new systems onto existing abstractions (*where in the chain does this live?*)

**Not allowed after Chapter 13:**

- New diagrams of “how reality works”
- New philosophical pivots (“this changes everything again”)
- New “this is actually the real abstraction” moments
- Service mesh, observability, or Hermes framed as separate epistemologies

**Litmus test:**

> **All future chapters must be reducible to a State Layer mapping without introducing new abstraction layers.**

If a chapter cannot be expressed as:

```text
X maps to Intent / API / Scheduler / Container / Kernel
```

—it is over-scoped. Split it, or cut the conceptual preamble.

**Reader feeling after Ch 13:** *“Oh—this is just how I place something into the system I already saw become real.”* Not: *“Kubernetes introduces another new way of thinking.”*

The book is now a **controlled expansion of a single mental model** across increasing complexity—not a tutorial series of repeated paradigm announcements.

#### Execution-Only Chapters (Part IV+ template)

Use this template for Part IV object chapters (starting with [Chapter 20: Pods](docs/part-iv-kubernetes/20-pods.md)):

| Allowed content | Disallowed content |
|-----------------|-------------------|
| Map container → Pod (or object → layer) | “Pods are the fundamental unit of computation” (revolutionary framing) |
| Show scheduling, logs, restart, failure/recovery | “This changes everything again” |
| `kubectl` exercises on the live cluster from Ch 13 | Re-explaining why Kubernetes exists |
| State Layer mapping for every new object | New ontology arcs or State 1→2→3 patterns |

**Chapter 20 framing:**

- Chapter 13: *“We now have a scheduler.”*
- Chapter 20: *“We now use the scheduler.”*

### Book Completion: Design Done, Execution Remains

The hard problems—structure, pedagogy, sequencing, abstraction layers—are **complete**. What remains is **instantiation**: making the system from Chapters 6–13 actually run at full depth.

| Done | Not done yet |
|------|----------------|
| State Layers mental model | Part IV: Pods through storage (operate the control plane) |
| One ontology shift per layer | Part VI–VII: Hermes, llama.cpp, PostgreSQL, Redis in-cluster |
| AWS → k3s progression (Ch 7–13) | End-to-end request: `laptop → ingress → Hermes → model → response` |
| Cognitive & narrative governance | Capstone closure: re-derive State Layers from a running system; Ch 6 → Ch 13 → now |

**Remaining chapters are not new ideas.** They progressively turn knobs on a machine whose design already exists. Map every chapter to State Layers; do not reopen architecture.

**Capstone chapter** (Part VII finale, e.g. Ch 43): show the full platform running; walk the State Layer stack against real components; confirm *this is what we built*—without introducing future work as the emotional ending.

> You’ve already built the *thinking model of Hermes*. The rest is just making it run.

---

## Docusaurus Publishing

The book is published with [Docusaurus](https://docusaurus.io/). Chapter Markdown lives under `docs/`; the site builds to `build/` and deploys to GitHub Pages.

| Task | Command / location |
|------|-------------------|
| Preview locally | `npm start` → [http://localhost:3000/agent-to-aws-guide/](http://localhost:3000/agent-to-aws-guide/) |
| Production build | `npm run build` |
| Add chapter to sidebar | Edit `sidebars.ts` (usually already listed in [SUMMARY.md](SUMMARY.md)) |
| Site config | `docusaurus.config.ts` |
| Theme CSS | `src/css/custom.css` |

### Chapter Frontmatter

Every file under `docs/` starts with YAML frontmatter:

```yaml
---
sidebar_position: 3
description: "One-line summary for SEO and search."
---
```

- `sidebar_position` — order within a part (optional if using `sidebars.ts` explicit order)
- `description` — shown in search results and meta tags

Do not put the H1 title in frontmatter—use `# Chapter N: Title` as the first heading.

### Cross-Links Between Chapters

Use relative paths between docs files:

```markdown
[Chapter 9: Provisioning the Hermes Server](../part-ii-aws/09-provisioning-hermes-server.md)
```

For links within the same chapter, use heading anchors that match Docusaurus slugified IDs (run `npm run build` to catch broken anchors):

```markdown
[Section 3.3](#section-33--processes-services-and-systemd)
```

When in doubt, use an explicit heading ID:

```markdown
### Section 3.3 — Processes and systemd {#section-33}
```

### What Docusaurus Replaces

| Old (GitHub-only) | New (Docusaurus) |
|-------------------|------------------|
| `chapters/*.md` | `docs/part-*/NN-slug.md` |
| Manual `[← Prev \| Next →]` footers | Sidebar navigation + optional pagination |
| GitHub native Mermaid | `@docusaurus/theme-mermaid` (enabled) |
| `SUMMARY.md` as sole TOC | `SUMMARY.md` + `sidebars.ts` + live site search |

Keep `SUMMARY.md` updated for RFC status tracking. Keep `sidebars.ts` in sync when adding chapters.

---

## Voice and Tone

| Rule | Example |
|------|---------|
| Second person — address the reader as **you** | "You will create a VPC" not "One creates a VPC" |
| Present tense for instructions | "Run `terraform apply`" not "Ran terraform apply" |
| Active voice | "AWS evaluates the policy" not "The policy is evaluated" |
| Explain **why** before **how** | Theory and Background precede Walkthrough |
| No filler | Cut "simply", "just", "obviously", "easy" |
| Precise, not verbose | One clear sentence beats three vague ones |
| Honest about tradeoffs | Say when something is hard, expensive, or slow |

**We teach understanding, not clicking.** Console steps explain what happens underneath—not just which button to press.

---

## Quality Bar

Every chapter must answer these four questions before it is marked **done**:

| # | Question | Where It Lives |
|---|----------|----------------|
| 1 | **What problem does this solve?** | Background, Learning Objectives |
| 2 | **Why was this technology invented?** | Background, Theory |
| 3 | **How does it work internally?** | Theory, Architecture |
| 4 | **How do I use it in my own infrastructure?** | Walkthrough, Hands-on Lab |

If a chapter does not answer all four, it is **not finished**—regardless of word count.

---

## Chapter Structure

Every single chapter must contain these sections **in this order**:

```markdown
# Chapter N: Title

> One-line description of what this chapter covers.

---

## Learning Objectives

## Prerequisites

## Estimated Time

## Background

## Theory

## Architecture

## Walkthrough

## Hands-on Lab

## Verification

## Troubleshooting

## Review Questions

## Key Takeaways

## Glossary Additions

## Further Reading
```

Every. Single. Chapter.

### Section Definitions

| Section | Required Content |
|---------|------------------|
| **Learning Objectives** | 3–7 checkboxes. Observable outcomes: "You will be able to…" |
| **Prerequisites** | Chapters, tools, and AWS resources that must exist before starting |
| **Estimated Time** | Reading + lab time (e.g. "90 minutes — 30 reading, 60 lab") |
| **Background** | History, motivation, problem context. Answers *why this exists*. **Concept layer** for implementation chapters. |
| **Theory** | How it works internally. Mechanisms, not marketing. Includes **design tradeoffs** before implementation. |
| **Architecture** | Diagrams and design decisions for **your** environment. **Design layer** for implementation chapters. |
| **Walkthrough** | Step-by-step operations—**only after Concept and Design**. Console, CLI, and/or Terraform as applicable. **Implementation layer**. |
| **Hands-on Lab** | Goal, steps, verification, cleanup. Certification-guide format. |
| **Verification** | Commands and expected output to confirm success |
| **Troubleshooting** | Table: Problem → Cause → Fix. Real errors, not hypotheticals. |
| **Review Questions** | 5–8 self-assessment questions without answers inline |
| **Key Takeaways** | 3–5 bullet summary of the most important ideas |
| **Glossary Additions** | New terms introduced in this chapter (term + one-sentence definition) |
| **Further Reading** | Curated external links—primary docs preferred over blog posts |

### Sections That Do Not Apply

If a section genuinely does not apply (e.g., Walkthrough in a conceptual chapter with no commands), **keep the section header** and write:

```markdown
## Walkthrough

*Not applicable to this chapter.*

Brief explanation of why, and where the reader will encounter this instead.
```

Never delete a section. Never reorder sections.

### Walkthrough Subsections

When a chapter involves AWS or IaC, use these subsections inside **Walkthrough** as needed:

```markdown
## Walkthrough

### AWS Console
### CLI
### Terraform
```

Include only the subsections that apply. Omit empty subsections rather than leaving them blank.

---

## RFC Workflow

Each chapter is written like an RFC—not in one sitting.

| Step | Action | Output |
|------|--------|--------|
| 1 | Produce an outline | Section headers + 2–3 bullets per section |
| 2 | Review outline | Approval or revision notes |
| 3 | Expand every section | Full prose draft |
| 4 | Add diagrams | Architecture section + `diagrams/` source files |
| 5 | Add lab | Hands-on Lab with tested commands |
| 6 | Add troubleshooting | From actual failures during lab testing |
| 7 | Add references | Further Reading + Glossary Additions |
| 8 | Edit for clarity | Read aloud; cut jargon; verify four-question quality bar |
| 9 | Mark done | Update status in SUMMARY.md |

### Chapter Status

| Status | Meaning |
|--------|---------|
| 📋 Outline | Step 1–2 complete |
| ✏️ Draft | Step 3 complete, not yet lab-tested |
| 🔬 Lab tested | Steps 5–6 complete |
| ✅ Done | All 9 steps complete; quality bar met |

Update [SUMMARY.md](SUMMARY.md) when status changes.

---

## Diagrams

| Type | Use For | Format |
|------|---------|--------|
| ASCII art | Network topology, layered stacks | `.txt` in `diagrams/` |
| Mermaid | Flows, sequences, decision trees | `.mmd` or fenced block in chapter |
| Tables | Comparisons, component choices | Markdown tables in chapter |

**Rules:**

- Every Architecture section has at least one diagram
- Keep ASCII width ≤ 80 characters
- Store reusable sources in `diagrams/` and update [docs/appendices/diagrams.md](docs/appendices/diagrams.md)
- GitHub renders Mermaid natively—prefer it for flows

---

## Labs

Labs follow this template:

```markdown
## Hands-on Lab

### Lab N: Title

**Estimated Time:** X minutes

**Goal:** One sentence.

**Prerequisites:** List chapters and resources.

**Steps:**

1. ...

**Verification:**

\`\`\`bash
command here
\`\`\`

**Expected output:**

Describe or show sample output.

**Troubleshooting:**

| Problem | Cause | Fix |
|---------|-------|-----|
| ... | ... | ... |

**Cleanup:**

What to tear down, what to keep for later chapters.
```

**Rules:**

- Test every command before marking the chapter done
- Never embed secrets—use environment variables, AWS profiles, or Kubernetes Secrets
- Lab assets live in `labs/chNN/`
- Document actual resource IDs in gitignored `labs/chNN/local/` files

---

## Glossary

- New terms go in the chapter's **Glossary Additions** section
- Also add them to [docs/appendices/glossary.md](docs/appendices/glossary.md) with chapter reference
- Define on first use in prose, then reinforce in Glossary Additions
- One or two sentences per definition—no essays

---

## Code and Commands

| Rule | Example |
|------|---------|
| Fenced code blocks with language tag | ` ```bash `, ` ```hcl `, ` ```yaml ` |
| Complete, runnable commands | No `...` omissions in lab steps |
| Placeholders in angle brackets or clearly marked | `<VPC_ID>`, `<account-id>` |
| Show expected output after verification commands | Reader knows what success looks like |
| Inline code for paths, commands, keys | `~/.aws/credentials` |

---

## Cross-References

- Link to previous chapters when assuming knowledge — e.g. "See [Chapter 8: Creating the Network for Hermes](docs/part-ii-aws/08-creating-network-for-hermes.md)"
- Link forward sparingly: " covered in Chapter 28"
- Navigation footer at end of every chapter:

```markdown
---

[← Chapter N-1](previous.md) | [Next: Chapter N+1 →](next.md)
```

---

## File Naming

```
docs/
├── preface/00-preface.md
├── part-i-foundations/
│   ├── 01-introduction.md
│   └── ...
├── part-ii-aws/
├── part-iii-containers/
├── part-iv-kubernetes/
├── part-v-infrastructure/
├── part-vi-ai/
├── part-vii-hermes/
└── appendices/
```

- Two-digit chapter number prefix within each part folder
- Lowercase kebab-case slug
- Match [SUMMARY.md](SUMMARY.md) exactly

---

## Commits and Pull Requests

- Branch: `chapter-NN-slug` (e.g. `chapter-09-provisioning-hermes-server`)
- One chapter per PR
- Commit message: `ch09: add EC2 theory and lab`
- PR description: which RFC steps are complete, quality-bar checklist, lab tested yes/no

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full PR template.

---

## What Good Looks Like

A finished chapter:

- [ ] All 14 sections present (or explicitly N/A with explanation)
- [ ] Answers all four quality-bar questions
- [ ] At least one diagram in Architecture
- [ ] Lab tested on a clean environment
- [ ] Troubleshooting entries from real failures
- [ ] Glossary Additions synced to `docs/appendices/glossary.md`
- [ ] Status updated in SUMMARY.md
- [ ] CI passes (Markdown lint, link validation, `npm run build`)
