---
sidebar_position: 43
description: "Extending Hermes — tools, agent roles, and capabilities without changing the platform."
---

# Chapter 43: Extending Hermes

> Great systems are not defined by the features they have.
>
> They are defined by how safely they can gain new ones.

---

[Chapter 42](42-platform-governance.md) established **how to run Hermes responsibly**. **Chapter 43 is where the book becomes yours**: most AI guides end with "here's how agents work." This one ends with **how to build new capabilities without changing the platform**.

```text
Finished application:  add features → redeploy the monolith
Hermes platform:       add capabilities → register tools → assign roles → observe
```

Hermes can execute, reason, remember, coordinate, observe, secure, and recover. The question is no longer *can it solve this problem?* It is:

> **Can Hermes learn a new capability without redesigning itself?**

:::note[Extension philosophy]

A **capability** is something Hermes can do that it could not do yesterday. The platform stays stable. Only capabilities grow.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Add a new tool using a schema contract and worker implementation
- [ ] Register tools in the registry without changing the reasoning loop ([Ch 39](../part-vi-ai/39-ai-agent-architecture.md))
- [ ] Create new `agent_role` specializations and assign tools via policy ([Ch 42](42-platform-governance.md))
- [ ] Wire credentials through ESO—not prompts ([Ch 32](../part-v-infrastructure/32-secrets-management.md))
- [ ] Validate extensions with unit, integration, and end-to-end reasoning tests
- [ ] Deploy capability changes via ConfigMap + policy—not platform rebuild
- [ ] Version tools during migration without breaking running tasks

---

## Prerequisites

- Hermes reasoning loop ([Chapter 39](../part-vi-ai/39-ai-agent-architecture.md))
- Distributed agents ([Chapter 40](40-distributed-cognitive-execution.md))
- Governance + tool policy ([Chapter 42](42-platform-governance.md))
- Observability ([Chapters 33–34](../part-v-infrastructure/33-monitoring.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get configmap -n hermes
```

---

## Estimated Time

**90 minutes** — 35 minutes reading, 55 minutes GitHub tool extension lab.

---

## Background

### The Layer Stack

Throughout this book you separated concerns:

```text
Infrastructure   →  AWS, Terraform, k3s (Parts II, IV, V)
Platform         →  Hermes runtime: API, workers, Postgres, Redis, Qdrant, llama-server
Application      →  Coordinator + agent roles (Ch 40)
Capability       →  Tools Hermes can invoke (this chapter)
```

| Layer | Changes when you add GitHub? | Example artifact |
|-------|------------------------------|------------------|
| Infrastructure | No | Terraform modules unchanged |
| Platform | No | Same Deployments, same loop |
| Application | Maybe | New `agent_role: project` in coordinator |
| **Capability** | **Yes** | `github.create_issue` tool |

Kubernetes, PostgreSQL, Redis, Qdrant, llama.cpp, monitoring, logging, security, and the reasoning loop **do not change**. You add a contract, an implementation, a registry entry, and a policy line.

### What Stays Fixed

The Ch 39 loop is the platform kernel:

```text
Request → task (Postgres) → worker claims (Redis)
       → context (Postgres + Qdrant + Config)
       → infer (llama-server)
       → tool proposal → gateway (validate → authorize → execute)
       → persist step → loop until complete
```

Extensions plug into the **tool proposal → gateway** step only. The model never talks to GitHub. The worker does—after validation and authorization.

### The Extension Pipeline

Every capability follows the same lifecycle:

```text
Idea
   │
Tool contract (JSON Schema)
   │
Implementation (worker handler)
   │
Validation (tests)
   │
Registration (tool-registry ConfigMap)
   │
Authorization (tool-policy per agent_role)
   │
Deployment (ConfigMap apply / Helm upgrade)
   │
Observation (logs, metrics, traces, audit rows)
```

Because the process is repeatable, Hermes grows **predictably**—like loading a driver into an OS, not rewriting the kernel.

---

## Walkthrough

### Step 1 — Define the Capability

Suppose Hermes should open GitHub issues from a project-management workflow.

Do not ask the model to "figure out GitHub." Define a **tool contract**—the boundary between reasoning and execution.

Schema: [`github.create-issue.schema.json`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/tools/github.create-issue.schema.json)

```json
{
  "type": "object",
  "required": ["owner", "repository", "title"],
  "properties": {
    "owner": { "type": "string" },
    "repository": { "type": "string" },
    "title": { "type": "string", "maxLength": 256 },
    "body": { "type": "string" }
  },
  "additionalProperties": false
}
```

| Contract element | Platform mapping |
|------------------|------------------|
| Required fields | Worker rejects malformed proposals before any API call |
| `maxLength` | Resource governance ([Ch 42](42-platform-governance.md)) |
| `additionalProperties: false` | Prevents injection of unexpected parameters |

The prompt may describe *when* to create issues. The schema defines *what shape* is executable.

### Step 2 — Implement the Tool

Implementation lives in the **worker**, not the model Pod.

Example handler: [`github.create-issue.example.py`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/tools/github.create-issue.example.py)

Worker responsibilities:

| Responsibility | Where |
|----------------|-------|
| Authentication | `GITHUB_TOKEN` from `ExternalSecret` ([Ch 32](../part-v-infrastructure/32-secrets-management.md)) |
| HTTP call | Worker process only |
| Retries | Bounded per `tool-registry` entry |
| Error normalization | Stable JSON for the reasoning loop |
| Secret handling | Never log token; redact in `hermes_task_steps` |

```bash
# Lab smoke test (sandbox token)
export GITHUB_TOKEN="$(kubectl get secret hermes-github-token -n hermes -o jsonpath='{.data.token}' | base64 -d)"
echo '{"owner":"my-org","repository":"hermes","title":"Extension lab"}' \
  | python3 infrastructure/hermes/tools/github.create-issue.example.py
```

The language model **never** communicates with `api.github.com`.

### Step 3 — Register the Tool

Registration makes a tool **available** to workers. It does **not** grant permission—that is policy ([Ch 42](42-platform-governance.md)).

Registry: [`tool-registry.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/tool-registry.example.yaml)

```yaml
tools:
  github.create_issue:
    version: "1.0.0"
    schema: tools/github.create-issue.schema.json
    secretRef: hermes/github-token
    timeoutSeconds: 45
    observability:
      metricName: hermes_tool_github_create_issue_total
```

Deploy as ConfigMap (same pattern as tool policy):

```bash
kubectl create configmap hermes-tool-registry \
  --from-file=registry.yaml=infrastructure/hermes/tool-registry.example.yaml \
  -n hermes --dry-run=client -o yaml | kubectl apply -f -
```

| Registry field | Purpose |
|----------------|---------|
| `version` | Capability versioning (see Step 7) |
| `schema` | Path to JSON Schema for validation |
| `secretRef` | AWS Secrets Manager key synced by ESO |
| `timeoutSeconds` | Cognitive resource bound |
| `observability` | Links to Ch 33–34 pipelines |

### Step 4 — Assign Capabilities to Agent Roles

Not every agent should use every tool. Extend policy with new roles:

[`agent-roles-extension.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/agent-roles-extension.example.yaml)

```yaml
agentRoles:
  project:
    allowedTools:
      - github.create_issue
      - jira.create_issue
  research:
    allowedTools:
      - docs.search
      - qdrant.retrieve
```

| Agent | Tools | Risk profile |
|-------|-------|--------------|
| `weather` ([Ch 40](40-distributed-cognitive-execution.md)) | NOAA | Read-only external |
| `project` | GitHub, Jira | Write external systems |
| `summary` | none | Synthesis only |
| `admin` | k8s, postgres | Requires approval |

A coordinator task ([`coordinator-decomposition.example.json`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/coordinator-decomposition.example.json)) can add a `project` subtask without changing Kubernetes manifests—only policy and registry.

### Step 5 — Observe Execution

Extensions inherit the platform observability stack. Every invocation should emit:

| Signal | Artifact |
|--------|----------|
| Structured log | `{"event":"tool_executed","tool":"github.create_issue","authorization":"allowed"}` → Loki |
| Metric | `hermes_tool_github_create_issue_total{status="success"}` → Prometheus |
| Trace | `trace_id` span around HTTP call → Tempo |
| Audit row | `hermes_task_steps` with `step_type=tool`, redacted `payload_json` |

Connect denied attempts to alerts ([Ch 33](../part-v-infrastructure/33-monitoring.md))—a spike may indicate prompt injection probes ([Ch 42](42-platform-governance.md)).

### Step 6 — Test Before Production

| Layer | What you verify |
|-------|-----------------|
| Unit | Schema validation, handler mocks, error paths |
| Integration | Real sandbox API with ESO-injected token |
| Policy | `summary` role **cannot** call `github.create_issue` |
| E2E reasoning | Coordinator task → worker loop → issue created → step persisted |
| Kubernetes | ConfigMap mounted; worker SA unchanged ([Ch 42 RBAC](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/kubernetes/ch42-rbac-hermes-worker.yaml)) |

Use [`extension-checklist.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/extension-checklist.example.yaml) as a merge gate.

### Step 7 — Version Capabilities

Capabilities evolve. Do not replace in place during active traffic:

```text
noaa.forecast v1  ──► workers route by task metadata
noaa.forecast v2  ──► compare latency + quality (Ch 41 model upgrade pattern)
```

Register both versions in `tool-registry.example.yaml` under `versionedTools`. Deprecate v1 only after measurement—not on deploy day.

---

## Example: Personal Finance Domain

Extend Hermes into finance without touching the platform:

```text
New capabilities:
  budget.estimate
  investment.snapshot
  tax.document_summary

New agent_roles:
  finance (already in Ch 40 ski-trip example)
  tax

Unchanged:
  Kubernetes, Postgres, Redis, Qdrant, llama-server
  Monitoring, logging, security, reasoning loop
```

Add tools + schemas + policy lines. Optionally add Qdrant collections for tax document embeddings ([Ch 36](../part-vi-ai/36-vector-databases.md))—that is **data**, not architecture.

---

## Operational Checklist

Before enabling a capability in production, every answer must be **yes**:

| Question | Platform check |
|----------|----------------|
| Clear contract? | JSON Schema in `infrastructure/hermes/tools/` |
| Authenticated? | `secretRef` in registry + ESO `ExternalSecret` |
| Authorized? | `agent_role` entry in tool-policy |
| Observable? | Log event + metric + audit step |
| Failure recoverable? | Task retry + durable state (Ch 39) |
| Secrets protected? | Not in prompt, log, or Qdrant |
| Tested? | Checklist complete |

If any answer is **no**, the capability is not ready—regardless of how well the model performs in a demo.

---

## Design Principles

Hermes grows by rules, not ad hoc prompts:

1. **Extend through contracts** — schemas, not prose instructions
2. **Separate reasoning from execution** — model proposes; worker executes
3. **Reuse platform services** — Postgres, Redis, ESO, Prometheus
4. **Observe every capability** — extensions inherit Ch 33–34
5. **Test before deployment** — checklist as merge gate
6. **Govern before enabling** — register ≠ permit ([Ch 42](42-platform-governance.md))

These principles let you add NOAA, Jira, GitHub, AWS operations, or entirely new domains **without accumulating architectural debt**.

---

## Hands-on Lab

### Lab 42: Add a GitHub Capability

**Estimated Time:** 55 minutes

**Goal:** Register and authorize `github.create_issue` without changing Hermes Deployments.

**Steps:**

1. Review `github.create-issue.schema.json` and example handler
2. Create sandbox GitHub token in AWS Secrets Manager; add ESO `ExternalSecret` (pattern from [Ch 32](../part-v-infrastructure/32-secrets-management.md))
3. Apply `hermes-tool-registry` and `hermes-tool-policy` ConfigMaps including `project` role
4. Validate denial: simulate `summary` role calling `github.create_issue` — expect `authorization: denied` in logs
5. Validate allow: `project` role with valid params — expect audit row in `hermes_task_steps`
6. Complete `extension-checklist.example.yaml` for your lab
7. **Do not** change API or worker Deployment images — confirm capability is config-only

---

## Verification

- [ ] You can explain the four layers (infrastructure → capability)
- [ ] New tool has JSON Schema + registry entry + policy assignment
- [ ] Credentials flow ESO → env, not prompt
- [ ] Denied and allowed invocations are both auditable
- [ ] Capability deploy required no platform image change
- [ ] Extension checklist completed

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Tool "not found" | Missing registry ConfigMap mount | Mount `hermes-tool-registry` on worker |
| 401 from GitHub | Stale or missing ESO sync | `kubectl describe externalsecret`; refresh SM |
| Model hallucinates API calls | No schema validation | Reject proposals that fail JSON Schema |
| Tool works in dev, denied in prod | Policy not updated | Add tool to `agent_role` allowlist |
| Secrets in Loki | Handler logs request headers | Redact `Authorization` in log pipeline |
| Coordinator ignores new role | Decomposition JSON unchanged | Add subtask with `agent_role: project` |

---

## Review Questions

1. Why is a capability not the same as a platform change?
2. What is the difference between registration and authorization?
3. Why must the model never call external APIs directly?
4. How do extensions inherit security and observability?
5. When would you run two versions of the same tool?

---

## Key Takeaways

- **Chapter 43 is the ownership graduation**—Hermes becomes *your* platform
- **Hermes is a platform for capabilities**, not a collection of prompts
- **New functionality enters through tools and contracts**—the loop stays fixed
- **Platform stability enables rapid feature growth** without redeploying the kernel
- **Extensions inherit** security (Ch 42), observability (Ch 33–34), and operations (Ch 41)
- Most AI books stop at agents; **this book shows how to grow the OS**

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Capability** | A tool or workflow Hermes can execute via the gateway. |
| **Tool contract** | JSON Schema defining valid tool parameters. |
| **Tool registry** | ConfigMap catalog of available tools and metadata. |
| **Registration** | Making a tool known to workers (availability). |
| **Authorization** | Permitting a tool for a specific `agent_role` (permission). |

---

## Further Reading

- [Chapter 39: The Hermes Reasoning Loop](../part-vi-ai/39-ai-agent-architecture.md)
- [Chapter 40: Distributed Cognitive Execution](40-distributed-cognitive-execution.md)
- [Chapter 42: Security, Governance, and Trust](42-platform-governance.md)
- [`tool-registry.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/tool-registry.example.yaml)
- [`extension-checklist.example.yaml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/hermes/extension-checklist.example.yaml)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Platform built (Ch 1–41)         ✓
Extensible (Ch 43)             ✓

Production operating model (Ch 44)   ✓
Capstone (Ch 45)                   ◐
───────────────────────────────────────────────
```

```text
Infrastructure → Platform → Application → Capability
                                         ↑ you are here
```

Hermes is no longer a project you built once. It is a **platform you can grow**.

---

## What's Next

[Chapter 44: From Development to Production](44-from-development-to-production.md) — promote Hermes to production with evidence, not optimism. The payoff: **you could actually run this.**

---

[← Chapter 42: Security, Governance, and Trust](42-platform-governance.md) | [Next: Chapter 44 — Development to Production →](44-from-development-to-production.md)
