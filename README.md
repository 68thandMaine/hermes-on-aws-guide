# Building a Personal AI Cloud

> *From Laptop to Production Kubernetes*

**Published docs:** [https://68thandMaine.github.io/hermes-on-aws-guide/](https://68thandMaine.github.io/hermes-on-aws-guide/)

---

## Why This Repository Exists

This book is a guided journey through designing, building, securing, and operating a **personal cloud development environment** capable of supporting modern software engineering and AI workloads.

It is not an AWS tutorial. It is not a Kubernetes cookbook. It is not a collection of notes.

It emphasizes understanding **why** technologies exist before teaching **how** to use them—and then has you apply every concept to a real environment you own and operate: a production-like platform running the **Hermes agent**, local AI models, and the infrastructure underneath them.

By the end, you will not have merely *learned* cloud concepts. You will have **built** a personal infrastructure manual—version-controlled, reproducible, and yours.

---

## Audience

This book is written for **software engineers with basic programming knowledge** who want to become proficient cloud engineers by building a real production-like environment.

| You are a good fit if… | This book is probably not for you if… |
|------------------------|---------------------------------------|
| You write code and want to understand infrastructure deeply | You have never used a terminal |
| You learn best by building, breaking, and fixing things | You want a quick certification cram guide |
| You want to run AI workloads on infrastructure you control | You are already operating multi-region Kubernetes at scale |
| You are comfortable with ambiguity and long-form learning | You want copy-paste solutions without explanation |

We assume you can write a script, use Git, and read documentation. We do **not** assume you have operated AWS, Kubernetes, or Terraform in production.

---

## What Makes This Different

Most technical books and tutorials teach you *how* to click through a console. This book teaches you:

1. **What problem** a technology solves
2. **Why** it was invented
3. **How** it works internally
4. **How** to use it in your own infrastructure

Every chapter must answer all four before it is marked done.

---

## The Journey

This book builds one coherent platform across seven parts:

```
Part I   Foundations        → Linux, networking, virtualization, Hermes platform design
Part II  AWS                → Provisioning infrastructure for Hermes (account → network → server)
Part III Containers         → Docker, Compose, OCI
Part IV  Kubernetes         → Pods through scaling and security
Part V   Infrastructure     → Terraform, CI/CD, secrets, observability
Part VI  AI Infrastructure  → Hermes, vectors, model serving, agents
Part VII Hermes Agent       → Deploy, tools, CI/CD, scale, recover
```

The arc is deliberate: **Laptop → AWS → Terraform → Docker → Kubernetes → Hermes Agent → Production.**

Nothing is throwaway. Every lab adds to the platform you keep.

---

## Architecture Documents

Before any chapter is written, three documents define the book:

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Why this repository exists (you are here) |
| [SUMMARY.md](SUMMARY.md) | Table of contents — the full chapter map |
| [STYLE_GUIDE.md](STYLE_GUIDE.md) | Voice, structure, quality bar, and RFC workflow |

Read these before contributing or writing.

---

## Repository Structure

```
├── README.md              # Project purpose and audience
├── SUMMARY.md             # Table of contents (45 chapters)
├── STYLE_GUIDE.md         # Writing rules and quality bar
├── CHANGELOG.md           # Meaningful revisions
├── LICENSE                # MIT License
├── docs/                  # Book chapters (Docusaurus content)
├── docusaurus.config.ts   # Site configuration
├── sidebars.ts            # Navigation sidebar
├── src/                   # Theme CSS and React components
├── static/                # Images and favicon
├── diagrams/              # Architecture and flow diagram sources
├── labs/                  # Lab assets, configs, starter files
├── glossary/              # Source glossary (sync to docs/appendices/)
├── references/            # Source bibliography (sync to docs/appendices/)
├── scripts/               # Helper and CI scripts
├── .cursor/rules/         # AI assistant rules (Cursor)
├── AGENTS.md              # AI orientation (any agent)
└── .github/workflows/     # Lint, link check, build, and deploy
```

---

## Local Development

Requires Node.js 20+.

```bash
npm install
npm start
```

Open [http://localhost:3000/agent-to-aws-guide/](http://localhost:3000/agent-to-aws-guide/) to preview the site.

Production build:

```bash
npm run build
npm run serve
```

---

## Writing Process

We do not write chapters in one pass. Each chapter follows an **RFC-style workflow**:

1. Produce an outline
2. Review the outline
3. Expand every section
4. Add diagrams
5. Add labs
6. Add troubleshooting
7. Add references
8. Edit for clarity
9. Mark the chapter **done**

See [STYLE_GUIDE.md](STYLE_GUIDE.md) for the full process and chapter template.

---

## Development Workflow

This repository is maintained like a software project:

- **`main` is protected** — changes land via pull request
- **One branch per chapter** — e.g. `chapter-07-ec2`
- **One PR per completed chapter** — even if you are the only reviewer
- **[CHANGELOG.md](CHANGELOG.md)** tracks meaningful revisions
- **CI** validates Markdown formatting, internal links, and the Docusaurus build on every PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch naming, PR conventions, and review checklist.

---

## How to Read This Book

Chapters are numbered and designed to be read in order. Labs are mandatory—not optional exercises. If you skip a lab, the next chapter assumes resources and knowledge you do not have.

Start with the [Guides landing page](https://68thandMaine.github.io/hermes-on-aws-guide/) or [SUMMARY.md](SUMMARY.md) for the full table of contents.

Estimated total time to complete all labs: **120–180 hours** (depending on prior experience).

---

## Prerequisites

- A computer running macOS or Linux (Windows via WSL2 is supported)
- Basic programming and command-line comfort
- An AWS account (free tier is sufficient to start)
- Willingness to break things, read error messages, and fix them

Verify local tools:

```bash
./scripts/setup/check-prerequisites.sh
```

---

## Contributing

This book is open source. Errors, clarifications, diagrams, and lab improvements are welcome via issues and pull requests.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [STYLE_GUIDE.md](STYLE_GUIDE.md).

---

## License

This work is licensed under the [MIT License](LICENSE).

---

## Author

**Christopher Rudnicky**
