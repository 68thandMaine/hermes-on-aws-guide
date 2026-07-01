---
sidebar_position: 38
description: "The Hermes reasoning loop — task-driven orchestration of memory, inference, tools, and persistence."
---

# Chapter 38: The Hermes Reasoning Loop

> A model generates tokens.
>
> A system generates outcomes.

---

By [Chapter 37](37-gpu-instances.md) you have every **subsystem** required for intelligence:

- Kubernetes executes workloads
- PostgreSQL stores durable state
- Redis coordinates async execution
- Qdrant stores semantic memory
- llama.cpp performs local inference (CPU and optional GPU)
- Monitoring and logging expose behavior ([Chapters 32–33](../part-v-infrastructure/32-monitoring.md))

None of that explains how Hermes **solves a task**.

This chapter defines the **Hermes runtime**—the execution model you have been building toward since [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md). It is not a survey of ReAct, LangGraph, or AutoGPT. Those frameworks implement *similar* patterns; Hermes implements **its own loop** on **your platform**.

```text
Generic agent guide:  "call the LLM in a loop with tools"
Hermes:               task → worker → state + memory + inference + tools → outcome
```

The reasoning loop is **not the LLM**. It is orchestration of **state, memory, inference, tools, and persistence**.

:::note[Cognitive governance]

No new ontology shift—this chapter **names and wires** what Parts II–VI already built. The unit of cognition is the **task**, not the token.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why a language model is one component—not the intelligent system
- [ ] Trace Hermes execution from request to task completion
- [ ] Describe how PostgreSQL, Redis, Qdrant, and llama-server participate in one cycle
- [ ] Articulate why workers mediate tools (models never touch infrastructure)
- [ ] Map failure recovery to durable task state and Kubernetes restarts
- [ ] Follow a reasoning cycle through metrics, logs, and traces
- [ ] State Hermes design principles that survive model swaps

---

## Prerequisites

- [Chapters 34–37](34-running-hermes.md) — Hermes lab stack, Qdrant, llama-server, optional GPU path
- [Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md) — ConfigMaps/Secrets in prompts
- [Chapters 32–33](../part-v-infrastructure/32-monitoring.md) — observability substrate

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n hermes
```

---

## Estimated Time

**75 minutes** — 45 minutes reading, 30 minutes tracing a task through the stack (conceptual + schema lab).

---

## Background

### The Problem

You can deploy, remember, reason, and accelerate—but **no single diagram** tied them into one behavior:

> How does a user question become a completed outcome?

Framework tutorials often start with `while True: llm.chat()`. Hermes starts with a **durable task** and a **worker responsible for the full cycle**.

### The Unit of Cognition

The smallest execution unit inside Hermes is **not a token**. It is not a single `/completion` call.

It is a **task**.

| Task property | Purpose |
|---------------|---------|
| **Objective** | What "done" means |
| **Context** | Structured + semantic inputs |
| **Tools** | What the worker may invoke |
| **State** | Progress across iterations |
| **Completion criteria** | When to stop the loop |

Everything Hermes does begins with a task.

### Models vs Platform

| Layer | Role |
|-------|------|
| **llama-server** | Proposes text, plans, tool calls (parsed by worker) |
| **Worker** | Owns the loop; validates; executes; persists |
| **API** | Ingests requests; creates tasks; returns status/results |
| **Stores** | Survive process death |

> **Models generate proposals, not authority.**

---

## Architecture

### High-Level Execution

```text
User Request
      │
      ▼
 Ingress (Traefik)
      │
      ▼
 Hermes API — task created → PostgreSQL
      │
      ▼
 Redis — pending queue / claim lock
      │
      ▼
 Worker claims task
      │
      ▼
 Context collection
      ├──────────────┐
      ▼              ▼
 PostgreSQL      Qdrant search
 (structured)    (semantic)
      │              │
      └──────┬───────┘
             ▼
      Prompt assembly (deterministic)
             │
             ▼
      Model inference (llama-server / GPU path)
             │
             ▼
      Tool required? ──No──► update state → done?
             │
            Yes
             ▼
      Worker executes tool → persist → loop
```

This loop—not the model—is the heart of Hermes.

### Memory Layers in the Loop

| Store | When used | Example |
|-------|-----------|---------|
| **PostgreSQL** | Task record, steps, tool outputs, session config | `hermes_tasks`, `hermes_task_steps` |
| **Redis** | Claim locks, short-lived coordination | One worker per task |
| **Qdrant** | Semantic recall for prompt | Top-k prior interactions |
| **Secrets Manager → K8s Secret** | Tool API keys | Injected at runtime ([Ch 31](../part-v-infrastructure/31-secrets-management.md)) |

### Inference Routing ([Chapter 37](37-gpu-instances.md))

Workers choose path by policy—not magic:

```text
if task.priority == interactive OR estimated_tokens > threshold:
    POST llama-server-gpu:8080/completion
else:
    POST llama-server:8080/completion
```

Same loop; different compute substrate.

---

## Walkthrough

### Step 1 — Request Ingestion

Request reaches Hermes API (Ingress → `hermes-api`).

Example objective:

```text
Summarize yesterday's ski conditions at Mt. Hood Meadows and recommend equipment.
```

The API **does not** immediately call llama-server.

It creates a task:

```json
{
  "objective": "Summarize ski conditions...",
  "owner_id": "user-42",
  "priority": 1,
  "status": "pending"
}
```

Persisted to PostgreSQL—see [`infrastructure/hermes/task-schema.example.sql`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/task-schema.example.sql).

Lab: apply schema inside postgres Pod:

```bash
kubectl cp infrastructure/hermes/task-schema.example.sql \
  hermes/$(kubectl get pod -n hermes -l app=hermes-postgres -o jsonpath='{.items[0].metadata.name}'):/tmp/
kubectl exec -n hermes deploy/hermes-postgres -- \
  psql -U hermes -d hermes -f /tmp/task-schema.example.sql
```

### Step 2 — Worker Acquisition

Workers poll or subscribe to pending work. Redis provides **lightweight exclusivity**:

```text
SET task:<uuid>:lock <worker-id> NX EX 300
```

One worker owns the task for the full reasoning cycle. If the Pod dies, lock expires; another worker resumes from **PostgreSQL state**—not from model memory.

### Step 3 — Context Collection

No reasoning yet—only assembly:

| Source | Data |
|--------|------|
| PostgreSQL | User preferences, prior task steps, structured facts |
| Qdrant | Similar past queries, tool outputs ([Ch 35](35-vector-databases.md)) |
| ConfigMap | Model parameters, feature flags ([Ch 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md)) |
| External APIs | Live weather (tool or pre-fetch) — Part VII |

### Step 4 — Prompt Construction

**Deterministic** template merge:

```text
[System instructions]
[Tool definitions — JSON schema]
[Retrieved Qdrant chunks]
[Task objective]
[Execution history from hermes_task_steps]
[Safety / policy constraints]
```

The prompt is the worker's snapshot of **world state** for this iteration.

### Step 5 — Model Inference

Worker POSTs to internal llama-server:

```json
{
  "prompt": "<assembled>",
  "n_predict": 512,
  "stream": false
}
```

Output is parsed as **proposal**:

- final answer text, or
- structured tool request (name + arguments)

Hermes does not treat raw model output as executed fact.

### Step 6 — Tool Execution

If the model requests a tool:

1. **Validate** — allowed tools, argument schema, rate limits
2. **Execute** — worker calls HTTP/MCP; model has no cluster credentials
3. **Capture** — result + latency + errors
4. **Persist** — `hermes_task_steps` row (`step_type: tool`)
5. **Continue** — append result to context; loop to Step 4

The model never invokes Kubernetes, AWS, or Secrets directly.

### Step 7 — State Update

Every iteration records:

```text
progress | retrieved_ids | tool_outputs | errors | status
```

Enables:

- UI progress polling
- retries without redoing successful tool calls
- audit for debugging

### Step 8 — Loop Continuation

Worker evaluates:

```text
Is the objective satisfied?
```

| Answer | Action |
|--------|--------|
| **No** | More retrieval, another tool, or another inference |
| **Yes** | `status: completed`, `result_json`, notify API/client |

Maximum iterations and timeouts are **platform policy**—not model self-regulation alone.

### Failure Recovery

Because state is durable:

| Failure | Recovery |
|---------|----------|
| Worker Pod crash | New Pod claims expired lock; reads `hermes_tasks` |
| Node loss | Kubernetes reschedules; task state in Postgres on PVC |
| Model timeout | Retry with `retry_count`; optional CPU fallback |
| Tool failure | Record error step; retry or fail task with message |

> **Intelligence survives individual processes.**

### Observability — Close the Loop

Each cycle emits ([Ch 32–33](../part-v-infrastructure/32-monitoring.md)):

| Signal | Example |
|--------|---------|
| **Metrics** | Task duration, inference latency, tool error rate |
| **Logs** | `{"event":"tool_call","task_id":"...","trace_id":"..."}` |
| **Traces** | Ingress → API → worker → llama-server → tool span |

Query lab workers today:

```logql
{namespace="hermes"} | json | event="worker_tick"
```

Production Hermes uses the same labels with `task_id` and `trace_id` on every step.

---

## Design Principles

Hermes architectural rules (platform-owned, model-agnostic):

1. **Models propose; workers execute.**
2. **Tasks are durable** — Postgres is source of truth for work.
3. **Memory is layered** — structured vs semantic vs ephemeral.
4. **Tools are mediated** — no model-to-infrastructure shortcuts.
5. **Inference is replaceable** — llama.cpp today; another engine tomorrow.
6. **State outlives processes** — Kubernetes restarts are not amnesia.
7. **Everything is observable** — no silent reasoning.

These rules let models evolve without rewriting the platform.

### How Earlier Chapters Pay Off

| Chapter | Role in the loop |
|---------|------------------|
| Linux (Ch 3) | Workers are processes with signals and logs |
| AWS (Part II) | Execution environment, EBS for models/data |
| Kubernetes (Part IV) | Schedule, restart, scale workers |
| Terraform + CI (Part V) | Reproduce the platform that runs the loop |
| Secrets (Ch 31) | Tool credentials without Git exposure |
| Monitoring + Logging (Ch 32–33) | See the loop under load |
| Postgres / Redis / Qdrant (Ch 34–35) | Active participants in context |
| llama.cpp (Ch 36–37) | One service in the graph—not "the AI" |

---

## Hands-on Lab

### Lab 38: Trace the Loop

**Estimated Time:** 30 minutes

**Goal:** Map one hypothetical task to concrete Hermes components.

**Steps:**

1. Apply `task-schema.example.sql` to lab Postgres
2. Insert a manual `pending` task row with your ski objective
3. List which Pods/Services each step touches (draw your own diagram)
4. Write the LogQL query you would use to find that `task_id`
5. Identify what survives if `hermes-workers` Deployment is deleted and recreated

---

## Verification

- [ ] You can explain task vs token vs model call
- [ ] You can draw the loop without looking at the chapter
- [ ] You can name which store holds task state vs semantic recall
- [ ] You can explain why workers own tool execution
- [ ] You can describe recovery after worker crash
- [ ] You understand Hermes vs generic "agent framework" positioning

---

## Review Questions

1. Why does the API create a task before calling the model?
2. What happens to in-flight work if a worker Pod is OOMKilled?
3. Why is prompt assembly deterministic on the worker?
4. How does Qdrant differ from PostgreSQL in the loop?
5. Which design principle prevents credential leakage to the model?

---

## Key Takeaways

- **The reasoning loop belongs to the platform, not the model**
- **Tasks** are the unit of cognition—durable, resumable, observable
- **Workers** own the full cycle; models participate
- **Three memory layers** each serve a distinct role in context assembly
- **Tool mediation** keeps infrastructure boundaries intact
- **Observability** makes the loop debuggable end-to-end
- Part VI ends here: you have a **complete cognitive architecture**; Part VII **implements** it in production

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Task** | Durable unit of work with objective, state, and completion criteria. |
| **Reasoning loop** | Worker-driven cycle of context → infer → tool → persist until done. |
| **Proposal** | Model output interpreted by worker—not auto-executed. |
| **Tool mediation** | Worker validates and runs tools; model never holds infra credentials. |

---

## Further Reading

- [Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md)
- [ReAct (reference only)](https://arxiv.org/abs/2210.03629) — pattern Hermes implements with platform-owned persistence
- [`infrastructure/hermes/task-schema.example.sql`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/task-schema.example.sql)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Substrate + inference        ✓
Reasoning loop (specified)   ✓
Production Hermes agent      ◐ (Part VII)
Tool pipelines               ◐ (Part VII)

End-to-end ski query         ◐ (Ch 40+)
───────────────────────────────────────────────
```

Part VI complete. Part VII: **run the loop in production**.

---

## What's Next

[Chapter 39: Distributed Cognitive Execution](../part-vii-hermes/39-distributed-cognitive-execution.md) — Hermes as OS for agents; coordinator + shared state.

---

[← Chapter 37: GPU Instances](37-gpu-instances.md) | [Next: Chapter 39 — Distributed Cognitive Execution →](../part-vii-hermes/39-distributed-cognitive-execution.md)
