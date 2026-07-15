---
sidebar_position: 40
description: "Distributed cognitive execution — Hermes as an operating system for agents."
---

# Chapter 40: Distributed Cognitive Execution

> Intelligence does not emerge because one model becomes larger.
>
> It emerges because specialized systems learn to cooperate.

---

[Chapter 39](../part-vi-ai/39-ai-agent-architecture.md) defined the **reasoning loop** for a single task. That loop is complete—but large objectives do not belong in one monolithic prompt.

At this point the reader should internalize:

> **Hermes is not an agent. Hermes is an operating system for agents.**

An agent is a **task** running the same Hermes runtime with a specialized objective. The platform schedules cognition; Kubernetes schedules processes. If tomorrow's reasoning frameworks change, **the platform still stands**.

```text
Agent framework guide:  "build a multi-agent crew in Python"
Hermes:                 durable tasks + shared state + disposable workers
```

This chapter introduces **distributed cognitive execution**—not as a buzzword, but as decomposition of work across independent reasoning processes coordinated through **durable state**.

:::note[No new ontology]

Same loop as Ch 39. Same stores. Same workers. **More tasks** with `parent_task_id`, `agent_role`, and a coordinator that decomposes—not a different runtime.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why large objectives decompose into specialized tasks—not bigger prompts
- [ ] Describe Hermes as an OS for agents (tasks + shared substrate)
- [ ] Map coordinator → subtask → summary flow to PostgreSQL and Redis
- [ ] Contrast agent communication (via state) with API-to-API calls
- [ ] Explain failure isolation between parallel workers
- [ ] Correlate distributed cognition in Grafana/Loki using `root_request_id`
- [ ] Articulate design principles for horizontal cognitive scaling

---

## Prerequisites

- [Chapter 39](../part-vi-ai/39-ai-agent-architecture.md) — single-task reasoning loop
- [Chapters 34–37](../part-vi-ai/35-running-hermes.md) — Hermes lab stack
- Task schema applied ([`task-schema.example.sql`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/task-schema.example.sql))

---

## Estimated Time

**60 minutes** — 40 minutes reading, 20 minutes decomposition lab.

---

## Background

### The Problem

Single-loop Hermes handles:

```text
Summarize yesterday's ski conditions at Mt. Hood Meadows.
```

It strains under:

```text
Plan a three-day ski trip to Mt. Hood with weather analysis, lodging,
equipment recommendations, avalanche conditions, and transportation planning.
```

One worker *could* do everything in one context window. It **should not**:

- Context explodes; retrieval quality drops
- Tool failures block unrelated domains
- Latency stacks serially
- Observability blurs into one opaque trace

### Why Decomposition Wins

Large tasks divide by **domain**, not by "more agents" branding:

| Domain | Subtask objective |
|--------|-------------------|
| Weather | Forecast analysis |
| Snow | Surface / avalanche conditions |
| Equipment | Gear recommendations |
| Routing | Transportation |
| Finance | Budget |
| Summary | Synthesize sub-results |

Each subtask runs the **identical Ch 39 loop**. Only `objective`, `agent_role`, and tool allowlists differ.

### Hermes Is the OS

| OS concept | Hermes equivalent |
|------------|-------------------|
| Process | Worker Pod executing one task |
| Program | Reasoning loop + prompt template for `agent_role` |
| Scheduler | Coordinator + Redis queue + K8s |
| Filesystem | PostgreSQL + Qdrant (shared) |
| IPC | Durable rows in `hermes_tasks` / `hermes_task_steps`—not direct worker-to-worker RPC |

There are no "special" agent binaries—only **different tasks**.

---

## Architecture

### Coordinator Pattern

```text
               User Request
                    │
                    ▼
             Hermes API
                    │
                    ▼
          Coordinator Task (root)
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
  weather task   routing task  equipment task
  (same loop)    (same loop)   (same loop)
      │             │             │
      └───────┬─────┴─────┬───────┘
              ▼
        summary task
              │
              ▼
         Final Response
```

Coordinator responsibilities:

1. Create `root_request_id` for correlation
2. Decompose user objective into subtasks ([`coordinator-decomposition.example.json`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/coordinator-decomposition.example.json))
3. Insert child rows with `parent_task_id`
4. Poll/wait for children `status: completed`
5. Spawn summary task when dependencies satisfied
6. Return synthesized result to API client

### Shared Memory (Not Fragmented)

Every agent reads/writes the **same**:

- PostgreSQL — task tree, results, audit steps
- Redis — claims and coordination
- Qdrant — semantic recall ([Ch 36](../part-vi-ai/36-vector-databases.md))

No per-agent database. Knowledge stays **federated in platform state**—contributions are rows, not silos.

### Communication Through State

Agents do **not** call each other.

```text
Weather worker completes
        ↓
Writes result_json → PostgreSQL (task row)
        ↓
Coordinator / summary worker reads completed siblings
        ↓
Summary task begins with structured inputs
```

Benefits:

- **Replayability** — re-run summary from stored sub-results
- **Observability** — each task has `task_id`, `trace_id`
- **Fault tolerance** — travel task crash does not kill weather task

### Kubernetes View

From kube's perspective: **Worker Pods**. No magic.

```text
Kubernetes schedules processes.
Hermes schedules cognition.
```

Some Pods happen to run `agent_role=weather`; others `equipment`. Scale weather workers with `kubectl scale` or HPA when forecast load spikes ([Chapter 29](../part-iv-kubernetes/29-scaling.md), [Chapter 44](44-from-development-to-production.md)).

---

## Walkthrough

### Step 1 — Extend Task Model

Schema additions (in `task-schema.example.sql`):

| Column | Purpose |
|--------|---------|
| `parent_task_id` | Links subtask to coordinator |
| `root_request_id` | Correlates entire user request |
| `agent_role` | `weather`, `summary`, etc. |

Re-apply schema if you completed Lab 38 before this chapter.

### Step 2 — Decomposition Spec

Review ski-trip example:

```bash
cat infrastructure/hermes/coordinator-decomposition.example.json
```

Coordinator translates JSON into `INSERT` rows—each with `status: pending`, shared `root_request_id`.

### Step 3 — Parallel Execution

Workers claim independent pending tasks via Redis ([Ch 39](../part-vi-ai/39-ai-agent-architecture.md)). Weather and routing run **concurrently** on different Pods.

Failure isolation:

| Event | Effect |
|-------|--------|
| Travel worker OOMKilled | Only travel task retries; weather result preserved |
| Summary started early | Coordinator waits until `depends_on_roles` complete |

### Step 4 — Summary Synthesis

Summary agent's prompt includes **structured sub-results** from Postgres—not re-querying all tools:

```text
[weather.result_json]
[snow.result_json]
...
[Synthesize trip plan per user objective]
```

One more inference pass; minimal new tool calls.

### Step 5 — Observability

Correlate in Grafana/Loki ([Ch 33–34](../part-v-infrastructure/33-monitoring.md)):

```logql
{namespace="hermes"} | json | root_request_id="req-ski-trip-2026-06"
```

Metrics: tasks completed per `agent_role`, p95 latency per role, coordinator wall time.

### Step 6 — Scaling Cognition

Instead of one enormous prompt:

```text
weather workers × 4   (parallel forecast regions)
equipment workers × 2
```

Hermes creates **more tasks**; Kubernetes scales **more Pods**. Same platform.

---

## Design Principles

1. **Tasks are independent** — parallel domains, isolated failure domains
2. **Agents are disposable** — Pods restart; state survives in Postgres
3. **State is shared** — one platform memory, not N agent databases
4. **Communication is durable** — Postgres rows, not in-memory agent chat
5. **Coordination is observable** — `root_request_id` ties traces together
6. **Scaling is horizontal** — more tasks + more workers, not bigger prompts
7. **Intelligence emerges from collaboration** — summary synthesizes; no super-agent

---

## Hands-on Lab

### Lab 39: Decompose a Request

**Estimated Time:** 20 minutes

**Goal:** Design task tree for ski-trip objective without implementing coordinator code.

**Steps:**

1. Read `coordinator-decomposition.example.json`
2. Draw task DAG on paper (which subtasks can run in parallel?)
3. For each `agent_role`, list which tools it may call (weather API vs maps vs none)
4. Write SQL `INSERT` stubs for coordinator + two parallel children
5. Describe what happens if `routing` fails but `weather` succeeds

---

## Verification

- [ ] You can state "Hermes is an OS for agents" in your own words
- [ ] You can explain why agents don't call each other directly
- [ ] You can map coordinator pattern to Postgres columns
- [ ] You understand failure isolation between subtasks
- [ ] You can name correlation fields for observability

---

## Review Questions

1. Why is Hermes not "one big agent"?
2. How is agent communication different from microservice RPC?
3. What does Kubernetes see vs what Hermes schedules?
4. Why share PostgreSQL/Qdrant instead of per-agent stores?
5. When would you add more workers vs one larger model?

---

## Key Takeaways

- **Hermes is a platform that executes many agents**—each agent is a task + role
- **Distributed cognitive execution** decomposes objectives without new runtime magic
- **Coordinator** creates task trees; **workers** run Ch 39 loops
- **Durable state** is the bus between agents
- **Kubernetes** scales processes; **Hermes** scales cognition
- Reasoning becomes **distributed**—the architectural boundary after single-loop Ch 39

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Coordinator** | Task/worker that decomposes objectives and aggregates results. |
| **Agent role** | Label (`weather`, `summary`) selecting prompt/tools for a task. |
| **root_request_id** | Correlation ID for all tasks in one user request. |
| **Distributed cognitive execution** | Multiple independent reasoning loops coordinated via shared state. |

---

## Further Reading

- [Chapter 39: The Hermes Reasoning Loop](../part-vi-ai/39-ai-agent-architecture.md)
- [`coordinator-decomposition.example.json`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/coordinator-decomposition.example.json)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Single-task reasoning loop    ✓
Distributed task model      ✓
Domain agents (weather…)    ◐ (Ch 41+)
Production operations       ◐ (Ch 42–43)

Capstone                    ◐ (Ch 45)
───────────────────────────────────────────────
```

```text
Infrastructure → … → Reasoning → Distributed Cognition
```

Part VII shifts to **operating** the platform in production scenarios.

---

## What's Next

[Chapter 41: Operating Hermes in Production](41-operating-hermes-in-production.md) — rolling deploys, backups, SLOs, runbooks; the operator shift.

---

[← Chapter 39: The Hermes Reasoning Loop](../part-vi-ai/39-ai-agent-architecture.md) | [Next: Chapter 41 — Operating Hermes →](41-operating-hermes-in-production.md)
