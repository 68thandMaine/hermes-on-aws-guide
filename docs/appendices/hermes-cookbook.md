---
sidebar_position: 6
description: "Real-world Hermes Agent usage scenarios — briefings, bots, PR review, rentals, and more."
---

<!-- markdownlint-disable MD013 -->

# Appendix: Hermes Cookbook

What people actually **do** with
[Hermes Agent](https://github.com/NousResearch/hermes-agent) — the self-improving agent from
[Nous Research](https://nousresearch.com) — once it is running somewhere durable.

This appendix is a **scenario cookbook**, not an install guide. Each section is a job someone
uses Hermes for: morning briefings, team chat bots, PR watchers, rental hunts, and similar
patterns drawn from the official
[User Stories & Use Cases](https://hermes-agent.nousresearch.com/docs/user-stories) and
[guides](https://hermes-agent.nousresearch.com/docs/guides/tips).

:::note[Hermes in this book]

**Hermes** means [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent).
This book builds the AWS → Docker → k3s **home** so the agent can run always-on with durable
state and optional local inference ([llama.cpp](../part-vi-ai/37-model-serving.md)).
You are not inventing a custom agent framework.

Parts VI–VII include lab topologies (`hermes-lab` stubs) that teach Kubernetes assembly.
Real-world usage below targets the upstream agent: CLI, messaging gateway, cron, skills, and MCP.

:::

## Before you try these

1. Install and chat once —
   [Quickstart](https://hermes-agent.nousresearch.com/docs/getting-started/quickstart).
2. Prefer an always-on host for gateway/cron (this book’s EC2 path:
   [Chapter 9](../part-ii-aws/09-provisioning-hermes-server.md) onward).
3. For messaging bots, use allowlists or DM pairing — never open terminal access to the world
   ([Security](https://hermes-agent.nousresearch.com/docs/user-guide/security)).

---

## Scenario index

| # | Scenario | Hermes pieces |
|---|----------|---------------|
| S1 | [Morning briefing](#s1--morning-briefing) | Cron, web search, gateway |
| S2 | [Team messaging assistant](#s2--team-messaging-assistant) | Gateway, pairing, SOUL/AGENTS |
| S3 | [Automated PR reviewer](#s3--automated-pr-reviewer) | Cron, `gh`, skills, memory |
| S4 | [Website / repo change monitor](#s4--website--repo-change-monitor) | Cron, scripts, `[SILENT]` |
| S5 | [Personal task OS](#s5--personal-task-os) | Memory, skills, messaging |
| S6 | [Research digest agent](#s6--research-digest-agent) | Cron, multi-channel delivery |
| S7 | [Content research cron](#s7--content-research-cron) | Skills + weekly cron |
| S8 | [Build-and-deploy from chat](#s8--build-and-deploy-from-chat) | Terminal, browser, notify |
| S9 | [Always-on home agent](#s9--always-on-home-agent) | Gateway on durable host |
| S10 | [Self-hosted inference](#s10--self-hosted-inference--privacy) | Custom endpoint, llama.cpp |
| S11 | [Rental criteria scanner](#s11--rental-criteria-scanner) | Cron, skill, APIs/MCP/browser |

---

## S1 — Morning briefing

**Story.** Every weekday at 8am you want a short digest of topics you care about (AI news,
open models, your industry) delivered to Telegram or Discord — not another tab to refresh.

**Why Hermes.** Cron jobs run in a fresh session on a gateway that stays up when your laptop
sleeps. Web search + summarization + delivery are one self-contained prompt.

**Shape.**

- Messaging gateway with a home channel (`/sethome`)
- Cron schedule (`0 8 * * 1-5`)
- Explicit prompt (topics, format, tone) — no “do my usual briefing”

**Try it.**

```text
Every weekday at 8am, search for the latest news about AI agents and open-source LLMs.
Summarize the top 3 stories with headlines, two-sentence summaries, and links.
Friendly professional tone. Deliver to telegram.
```

Test the prompt in an interactive `hermes` session before scheduling.

**On your AWS home.** Run the gateway as a service on EC2 so briefings fire while you are offline.

**Go deeper.**
[Daily Briefing Bot](https://hermes-agent.nousresearch.com/docs/guides/daily-briefing-bot) ·
[Automate with Cron](https://hermes-agent.nousresearch.com/docs/guides/automate-with-cron)

---

## S2 — Team messaging assistant

**Story.** Your team DMs one bot for code help, research, debugging, and standups. Each person
keeps their own session; only approved users can talk to it.

**Why Hermes.** One gateway process spans Telegram/Discord/Slack; DM pairing adds people without
restarting; `SOUL.md` and `AGENTS.md` give the bot a stable voice and stack context.

**Shape.**

- Gateway on a VPS/EC2 (not a laptop)
- Allowlist or `hermes pairing approve`
- Optional personality + project context files
- Optional weekday standup cron into a team channel

**Try it.**

```bash
hermes gateway setup    # pick Telegram, paste bot token, set your user ID
hermes gateway install  # keep it running
```

In chat: set home with `/sethome`. Approve teammates with pairing codes instead of editing
env files for every ID.

**On your AWS home.** This is the primary “personal AI cloud” pattern: SSH for ops, Telegram
for daily use ([Chapter 10](../part-ii-aws/10-establishing-trust.md) trust boundary).

**Go deeper.**
[Team Telegram Assistant](https://hermes-agent.nousresearch.com/docs/guides/team-telegram-assistant)

---

## S3 — Automated PR reviewer

**Story.** PRs pile up faster than humans review them. Hermes polls repos on a schedule, reads
diffs with `gh`, and sends a structured verdict to Telegram — or comments on GitHub.

**Why Hermes.** Skills keep review guidelines consistent across cron runs; memory holds your
stack conventions; cron needs no public webhook.

**Shape.**

- Authenticated `gh` on the host
- `code-review` skill (`SKILL.md` with severity format)
- Cron every few hours with repo list baked into the prompt
- Optional: post with `gh pr review`

**Try it.**

```text
Remember: backend uses FastAPI + SQLAlchemy only — no raw SQL.
All endpoints need type annotations and Pydantic models.
```

Then schedule a job that lists open PRs, diffs recent ones, and reviews with the skill attached
([PR Review guide](https://hermes-agent.nousresearch.com/docs/guides/github-pr-review-agent)).

**On your AWS home.** Keep `gh` auth and the gateway on EC2; secrets stay on the server, not on
every laptop.

**Go deeper.**
[GitHub PR Review Agent](https://hermes-agent.nousresearch.com/docs/guides/github-pr-review-agent)

---

## S4 — Website / repo change monitor

**Story.** You care when a pricing page, status page, or GitHub repo actually **changes** — not
hourly “still the same” noise.

**Why Hermes.** A small script does fetch/diff; the agent only reasons when something changed.
Respond with `[SILENT]` to suppress delivery on quiet runs.

**Shape.**

- Cron + `--script` that prints `CHANGE DETECTED` or `NO_CHANGE`
- Prompt: summarize only on change; otherwise `[SILENT]`
- Same pattern for `gh issue list` / `gh pr list` windows

**Try it.**

```text
If the script output says CHANGE DETECTED, summarize what changed and why it matters.
If it says NO_CHANGE, respond with only [SILENT].
```

**On your AWS home.** Persist script state files under `~/.hermes` on EBS so hashes survive
reboot ([Chapter 11](../part-ii-aws/11-persistent-storage.md)).

**Go deeper.**
[Automate with Cron — website monitor](https://hermes-agent.nousresearch.com/docs/guides/automate-with-cron)

---

## S5 — Personal task OS

**Story.** You talk to Hermes in Signal or Telegram and expect it to keep tasks in Obsidian,
cross-check Apple Calendar, and remember how *you* want work organized.

**Why Hermes.** Memory + skills turn one-off instructions into durable workflows; messaging
means you are not glued to a CLI.

**Shape.**

- Gateway on an always-on host
- Skills for Obsidian / calendar integrations you enable
- Explicit “remember this workflow” turns that write memory
- Cron for reminders delivered to your home channel

**Try it.**

```text
From now on manage tasks in Obsidian and cross-check Apple Calendar.
When I say "log Thursday", use the journaling skill and write to my vault.
Confirm the workflow, then remember it.
```

**On your AWS home.** The agent’s memory and skills live with the host — back up `~/.hermes`
like any stateful service.

**Go deeper.**
[Memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory) ·
[Work with Skills](https://hermes-agent.nousresearch.com/docs/guides/work-with-skills) ·
User Stories → Personal Assistant

---

## S6 — Research digest agent

**Story.** Hermes watches a niche (AI agents, security, your market), writes briefs, suggests
content angles, and delivers daily via Discord, Slack, Notion, email, or local markdown.

**Why Hermes.** Skills improve over time; cron + multi-delivery turns research into a feed you
actually read.

**Shape.**

- Standing research criteria in a skill or self-contained cron prompt
- Optional delegation for parallel topic scans
- Delivery to the channels you already use

**Try it.**

```text
Watch the AI/agent space daily. Pick useful signals, write a brief under 400 words,
suggest one content angle, and note what I should ignore. Deliver to discord.
```

**On your AWS home.** Same always-on gateway as S1; scale prompts carefully to control API
cost ([Chapter 16](../part-ii-aws/16-managing-platform-costs.md)).

**Go deeper.** User Stories → Research ·
[Delegation patterns](https://hermes-agent.nousresearch.com/docs/guides/delegation-patterns)

---

## S7 — Content research cron

**Story.** Creators ask Hermes to research trending tools, invent a reusable skill, and
schedule a Monday job that feeds the next video or post.

**Why Hermes.** Skills capture *how* you research; cron reuses it without re-explaining every
week.

**Shape.**

- One interactive session that creates a skill (e.g. `youtube-video-research`)
- Weekly cron that loads that skill
- Delivery to Telegram or local files

**Try it.**

```text
Research the top trending AI tools right now and pick the top three for an interesting tutorial.
Create a skill from your approach called youtube-video-research.
Set up a weekly job every Monday at 9:00 AM using that skill.
```

**On your AWS home.** Skills stored under `~/.hermes/skills` travel with the EC2 volume —
version them if the workflow matters.

**Go deeper.** User Stories → Content Creation ·
[Creating Skills](https://hermes-agent.nousresearch.com/docs/developer-guide/creating-skills)

---

## S8 — Build-and-deploy from chat

**Story.** Someone asks Hermes to research them, build a landing page, SSH to a VPS, upload
it, and text when done — end-to-end from a messaging chat.

**Why Hermes.** Terminal + browser + messaging in one agent loop; the host has the SSH keys
and deploy path.

**Shape.**

- Terminal backend (prefer Docker sandbox for untrusted work)
- Clear deploy target and approval for risky commands
- Notify on the same chat when finished

**Try it.**

```text
Search the web for my public profiles, draft a simple static landing page from what you find,
deploy it to the path we use on this host over SSH, and message me when the URL is live.
Ask before any destructive command.
```

**On your AWS home.** Hermes on EC2 already has a network path to other hosts you trust; keep
deploy keys scoped.

**Go deeper.** User Stories → Personal Assistant ·
[Security](https://hermes-agent.nousresearch.com/docs/user-guide/security)

---

## S9 — Always-on home agent

**Story.** Claude or ChatGPT handles deep chat on the laptop; Hermes runs 24/7 on a mini PC,
Pi, or VPS for email, browsing, forms, calendar, and cron — the “real world” loop.

**Why Hermes.** The agent is designed to live on a $5 VPS or home box and talk to you from
Telegram while it works remotely.

**Shape.**

- Gateway installed as a system/user service
- Messaging as the primary UI
- Laptop optional (SSH / tunnel for dashboard only)

**Try it.**

```bash
hermes gateway install
# Linux servers that must survive reboot:
sudo hermes gateway install --system
hermes gateway status
```

**On your AWS home.** Chapters 7–13 exist so this box is yours: VPC, EC2, trust, persistence,
then Docker/k3s when you outgrow a single process.

**Go deeper.**
[Messaging overview](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) ·
User Stories → Personal Assistant

---

## S10 — Self-hosted inference + privacy

**Story.** You want Hermes without shipping every prompt to a cloud API: local or cluster
models, optional local search (e.g. SearXNG), private memory on disk you control.

**Why Hermes.** Providers are swappable — including a **custom OpenAI-compatible endpoint**.
Models need ≥64K context for serious tool use.

**Shape.**

- `hermes model` → custom endpoint → `llama-server` (or other OpenAI-compatible server)
- Optional local search MCP/container shared by agents
- Secrets and sessions stay on your host

**Try it.**

```bash
hermes model
# Choose Custom endpoint → base URL of llama-server (e.g. http://127.0.0.1:8080/v1)
# Confirm context length ≥ 65536
```

**On your AWS home.** This book’s default local path is llama.cpp on k3s
([Chapter 37](../part-vi-ai/37-model-serving.md)); Hermes calls it as a separate service —
same split as [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md).

**Go deeper.**
[Providers](https://hermes-agent.nousresearch.com/docs/integrations/providers) ·
[Local LLMs on Mac](https://hermes-agent.nousresearch.com/docs/guides/local-llm-on-mac)

---

## S11 — Rental criteria scanner

**Story.** You are hunting a rental: city or neighborhoods, max rent, beds/baths, pets,
parking, laundry, commute budget, move-in date. Refreshing listing sites by hand is noisy.
Hermes scans sources you allow on a schedule and only notifies you when a **new** listing
matches.

**Why Hermes.** Cron + a skill that encodes *your* criteria beats sticky browser tabs.
Seen-listing state stops repeat spam; `[SILENT]` keeps quiet hours quiet.

**Shape.**

- Skill (e.g. `rental-hunt`) with criteria + output format
- Cron every few hours with a **self-contained** prompt
- Data path preference: official/public APIs or feeds → MCP servers you run → browser/web
  tools on search URLs you configure
- Seen-ID state file under `~/.hermes` (or script-managed JSON)
- Delivery to Telegram/Discord; `[SILENT]` when nothing new matches

**Try it — criteria block (bake into skill or cron prompt).**

```text
Criteria (all must match unless marked nice-to-have):
- Metro: Portland, OR — prefer SE / close-in Eastside
- Max rent: $2200/mo (utilities not required)
- Min beds: 2 · Min baths: 1
- Pets: one cat OK
- Must: in-unit or on-site laundry
- Nice: parking, dishwasher
- Available by: 2026-09-01
- Skip: short-term / Airbnb-style, listings older than 14 days
```

**Try it — cron-shaped prompt.**

```text
Scan the listing sources configured for this job (API, MCP, or the search URLs in the rental-hunt skill).
Normalize each candidate: id, url, rent, beds, baths, pets, neighborhood, available date.
Compare ids to ~/.hermes/data/rental-seen.json (create if missing).
Keep only NEW listings that match the criteria in the rental-hunt skill.
For each match: one paragraph + link + why it fits.
Update rental-seen.json with new ids.
If none match, respond with only [SILENT].
Do not contact landlords or submit applications.
```

**Optional MCP sketch** (allowlist read-only tools):

```yaml
mcp_servers:
  rentals:
    command: "uvx"
    args: ["your-rentals-mcp"]   # example — use a server you trust
    tools:
      include: [search_listings, get_listing]
      prompts: false
      resources: false
```

**Optional script-first pattern.** A Python script fetches/normalizes listings (API or feed);
cron attaches `--script` and the agent only judges fit — same idea as S4.

**On your AWS home.** Gateway + cron on EC2 keep scanning while your laptop is closed; persist
`rental-seen.json` on EBS with the rest of `~/.hermes`.

:::warning[Guardrails]

- Respect site Terms of Service and robots rules. Prefer official APIs or an MCP you operate
  over brittle scrapes.
- Rate-limit requests; do not hammer listing sites.
- Do not auto-email or message landlords unless you deliberately design that step with human
  approval.
- Update the skill when your criteria change — cron prompts have no memory of last week’s chat.

:::

**Go deeper.**
[Automate with Cron](https://hermes-agent.nousresearch.com/docs/guides/automate-with-cron) ·
[Use MCP with Hermes](https://hermes-agent.nousresearch.com/docs/guides/use-mcp-with-hermes) ·
S4 change monitor

---

## What this book’s platform enables

| Platform piece | Why these scenarios care |
|----------------|--------------------------|
| EC2 + trust ([Ch 9–10](../part-ii-aws/09-provisioning-hermes-server.md)) | Always-on gateway; SSH for ops; messaging for daily use |
| Persistent volumes ([Ch 11](../part-ii-aws/11-persistent-storage.md)) | Memory, skills, cron state, seen-listing files survive reboot |
| Docker / k3s ([Ch 12–13](../part-ii-aws/12-building-the-application-platform.md)) | Sandboxed terminal; later multi-service home |
| llama.cpp ([Ch 37](../part-vi-ai/37-model-serving.md)) | Private/custom endpoint for S10 |

The cookbook shows **jobs**. Parts II–VII show **the machine those jobs run on**.

---

## Further reading

| Resource | Link |
|----------|------|
| Hermes Agent docs | [Docs home](https://hermes-agent.nousresearch.com/docs) |
| User Stories & Use Cases | [User stories](https://hermes-agent.nousresearch.com/docs/user-stories) |
| Learning Path | [Learning path](https://hermes-agent.nousresearch.com/docs/getting-started/learning-path) |
| GitHub repository | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) |
| Tips & Best Practices | [Tips](https://hermes-agent.nousresearch.com/docs/guides/tips) |
