# Hermes runtime artifacts (Part VI+)

Execution model and persistence contracts for the Hermes agent platform.

## Chapter index

| Chapter | Artifact |
|---------|----------|
| 38 | [`task-schema.example.sql`](task-schema.example.sql) — durable task + step audit tables |
| 39 | [`coordinator-decomposition.example.json`](coordinator-decomposition.example.json) — ski-trip task tree |
| 40 | [`runbooks/high-cpu-model-server.md`](runbooks/high-cpu-model-server.md), [`slo.example.yaml`](slo.example.yaml) |
| 41 | [`tool-policy.example.yaml`](tool-policy.example.yaml), [`governance-schema.example.sql`](governance-schema.example.sql), [`resource-governance.example.yaml`](resource-governance.example.yaml); [`ch42-rbac-hermes-worker.yaml`](../kubernetes/ch42-rbac-hermes-worker.yaml), [`ch42-networkpolicy-hermes.yaml`](../kubernetes/ch42-networkpolicy-hermes.yaml) |
| 42 | [`tool-registry.example.yaml`](tool-registry.example.yaml), [`extension-checklist.example.yaml`](extension-checklist.example.yaml), [`agent-roles-extension.example.yaml`](agent-roles-extension.example.yaml), [`tools/github.create-issue.schema.json`](tools/github.create-issue.schema.json), [`tools/github.create-issue.example.py`](tools/github.create-issue.example.py) |
| 43 | [`production-readiness.example.yaml`](production-readiness.example.yaml), [`environment-promotion.example.yaml`](environment-promotion.example.yaml) |

## Reasoning loop (summary)

```text
Request → API creates task (Postgres)
       → Worker claims task (Redis lock)
       → Context (Postgres + Qdrant + Config/Secrets)
       → Prompt assembly → llama-server (CPU/GPU)
       → Tool? → worker executes → persist step
       → Loop until complete
```

The loop is **platform-owned**. The model proposes; workers execute.

See [Chapter 39](../../docs/part-vi-ai/39-ai-agent-architecture.md).
