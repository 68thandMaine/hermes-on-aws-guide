# Contributing

Thank you for improving *Building a Personal AI Cloud*.

Read [STYLE_GUIDE.md](STYLE_GUIDE.md) before writing or reviewing anything. AI assistants should also read [AGENTS.md](AGENTS.md) and `.cursor/rules/`. It defines chapter structure, voice, quality bar, and the RFC workflow.

---

## Ways to Contribute

- **Report errors** — incorrect commands, outdated AWS behavior, broken links
- **Suggest clarifications** — sections that assume too much or explain too little
- **Add diagrams** — Mermaid or ASCII art that makes concepts clearer
- **Improve labs** — verification steps, troubleshooting from real failures
- **Fix typos** — always welcome

---

## Development Workflow

This repository is maintained like a software project.

### Branching

| Rule | Detail |
|------|--------|
| Protect `main` | All changes land via pull request |
| One branch per chapter | `chapter-NN-slug` — e.g. `chapter-09-provisioning-hermes-server` |
| One PR per chapter | Even if you are the only reviewer |
| Keep branches short-lived | Merge or close within a few weeks |

```bash
git checkout main
git pull
git checkout -b chapter-01-introduction
# ... work ...
git push -u origin chapter-01-introduction
gh pr create
```

### Commits

- One chapter per PR
- Message format: `chNN: brief description`
- Examples: `ch09: add EC2 Nitro theory section`, `ch09: fix lab verification commands`

### Pull Request Template

```markdown
## Chapter
- [ ] Chapter N: Title

## RFC Progress
- [ ] Step 1–2: Outline reviewed
- [ ] Step 3: All sections expanded
- [ ] Step 4: Diagrams added
- [ ] Step 5: Lab tested
- [ ] Step 6: Troubleshooting from real failures
- [ ] Step 7: References and glossary synced
- [ ] Step 8: Clarity edit
- [ ] Step 9: SUMMARY.md status updated

## Quality Bar
- [ ] What problem does this solve?
- [ ] Why was this technology invented?
- [ ] How does it work internally?
- [ ] How do I use it in my own infrastructure?

## Lab Tested
- [ ] Yes — clean environment, commands verified
- [ ] N/A — no lab in this chapter

## CI
- [ ] Markdown lint passes
- [ ] Internal links validate
- [ ] `npm run build` succeeds (no broken links or anchors)
```

---

## Chapter Structure

Chapters live under `docs/` in part folders (e.g. `docs/part-ii-aws/09-provisioning-hermes-server.md`). Edit the file that matches [SUMMARY.md](SUMMARY.md).

Every chapter must include all sections defined in [STYLE_GUIDE.md](STYLE_GUIDE.md):

1. Learning Objectives
2. Prerequisites
3. Estimated Time
4. Background
5. Theory
6. Architecture
7. Walkthrough
8. Hands-on Lab
9. Verification
10. Troubleshooting
11. Review Questions
12. Key Takeaways
13. Glossary Additions
14. Further Reading

Do not remove, rename, or reorder sections.

---

## Diagrams

- Prefer Mermaid for flows (GitHub renders natively)
- Use ASCII art for network topology (≤ 80 columns wide)
- Store reusable sources in `diagrams/` and update [docs/appendices/diagrams.md](docs/appendices/diagrams.md)

---

## CI

Every PR runs:

1. **Markdown lint** — formatting and style rules (`.markdownlint.json`)
2. **Internal link validation** — `scripts/ci/validate-links.sh`
3. **Docusaurus build** — `npm ci && npm run build`

Preview the site locally:

```bash
npm install
npm start
```

Fix CI failures before requesting review.

---

## Code of Conduct

Critique the content, not the author or other contributors. This book exists to help people learn.
