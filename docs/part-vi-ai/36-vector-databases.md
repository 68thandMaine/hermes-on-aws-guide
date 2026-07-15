---
sidebar_position: 36
description: "Semantic memory — Qdrant vector storage and retrieval-augmented flow for Hermes."
---

# Chapter 36: Vector Databases

> If logs are memory of what happened,
>
> and metrics are memory of how it behaved,
>
> then vectors are memory of meaning.

---

[Chapter 35](35-running-hermes.md) made Hermes **execute**—API, workers, model, Redis, PostgreSQL. The system is alive but still lacks **semantic memory across time**:

- Past interactions are not searchable by meaning
- Tool outputs are not retrievable by similarity
- Hermes cannot generalize across prior context

This chapter introduces the **third intelligence memory layer**: vector storage for retrieval-augmented reasoning.

```text
Before:  Hermes remembers state (Postgres) and coordination (Redis)
After:   Hermes remembers meaning (Qdrant) — semantic continuity
```

No new mental model—retrieval is another **State Layer**: write embeddings on process, read neighbors on query, inject into prompt context.

:::note[Why this is a system-type upgrade]

You are not adding "a database." You are introducing **semantic state** into an already running distributed system. Hermes transitions from execution system → **memory-aware execution system**.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain embeddings and similarity search as retrieval primitives
- [ ] Distinguish PostgreSQL, Redis, and vector storage roles in Hermes
- [ ] Deploy Qdrant on k3s in the `hermes` namespace
- [ ] Create a collection and run upsert + search via REST
- [ ] Describe write path and read path (RAG flow) for Hermes
- [ ] Identify failure modes: embedding drift, stale memory, retrieval hallucination
- [ ] Apply bounded semantic memory constraints on single-node k3s

---

## Prerequisites

- [Chapter 35: Running Hermes](35-running-hermes.md) — `hermes-lab` stack running
- [Chapter 25](../part-iv-kubernetes/25-kubernetes-storage.md) — `local-path` PVCs
- [Chapter 26](../part-iv-kubernetes/26-helm.md) — Helm
- `curl`, port-forward access

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
kubectl get pods -n hermes
```

---

## Estimated Time

**90 minutes** — 30 minutes reading, 60 minutes Qdrant deploy + collection + retrieval lab.

---

## Background

### Three Intelligence Memory Layers

Hermes now has **three distinct memory layers**—do not collapse them:

| Layer | Component | Memory type | Example |
|-------|-----------|-------------|---------|
| **Structured state** | PostgreSQL ([Ch 35](35-running-hermes.md)) | Rows, schemas, transactions | User ID, session config, tool run records |
| **Ephemeral coordination** | Redis ([Ch 35](35-running-hermes.md)) | Queues, cache, pub/sub | Task queue depth, rate limits |
| **Semantic memory** | Qdrant (this chapter) | Vector similarity | "Prior weather discussions near Seattle" |

```text
PostgreSQL  →  what the system knows (structured)
Redis       →  what the system is doing right now (ephemeral)
Qdrant      →  what past interactions meant (semantic)
```

### The Problem

Hermes can execute and observe—but without vectors:

> **No semantic continuity across time**

Requirements for an agent platform ([Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md)):

- Long-term memory
- Contextual retrieval
- Tool output reuse
- Reasoning continuity across sessions

### What a Vector Database Is

```text
text  →  embedding model  →  vector (float array in high-dimensional space)
query →  embedding         →  nearest neighbors  →  relevant memories
```

Storage is not the text—it is the **position in semantic space**. Retrieval is **similarity search** (cosine, dot product, Euclidean)—not SQL `WHERE`.

### Monitoring vs Logging vs Vectors (Ch 33–34 bridge)

| Signal | Remembers |
|--------|-----------|
| Metrics | How the system behaved |
| Logs | What events occurred |
| Vectors | What content **meant** |

---

## Architecture

### System Addition

```text
                ┌──────────────┐
                │  Hermes API  │
                └──────┬───────┘
                       ↓
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
   PostgreSQL      Redis         Qdrant
 (structured)   (coordination)  (semantic)
```

Hermes API env wiring (updated in `hermes-lab` chart):

```yaml
- name: QDRANT_HOST
  value: hermes-qdrant
- name: QDRANT_PORT
  value: "6333"
```

### Write Path

```text
User interaction / tool output
        ↓
Text chunk + metadata (payload)
        ↓
Embedding model → vector
        ↓
Upsert into Qdrant collection `hermes-memory`
```

### Read Path (Retrieval-Augmented Generation)

```text
User query
        ↓
Query embedding
        ↓
Vector search (top-k)
        ↓
Relevant memory payloads
        ↓
Inject into prompt / context
        ↓
Model generates response
```

Retrieval becomes **runtime behavior**, not offline indexing.

### Embedding Dimensions (Lab vs Production)

| Environment | Vector size | Notes |
|-------------|-------------|-------|
| **This lab** | 4 | Visible in demo scripts; not for production |
| **Typical local** | 384 | Small sentence-transformer models |
| **Production API** | 1536+ | OpenAI / large embedding models |

Collection must match embedding model output size—**embedding drift** if you change models without re-indexing.

---

## Walkthrough

### Step 1 — Deploy Qdrant

```bash
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo update

helm upgrade --install hermes-qdrant qdrant/qdrant \
  -n hermes \
  -f infrastructure/helm/qdrant/values-k3s-lab.yaml
```

Verify:

```bash
kubectl get pods,svc -n hermes -l app.kubernetes.io/name=qdrant
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=qdrant -n hermes --timeout=120s
```

Internal URL: `http://hermes-qdrant:6333`

### Step 2 — Port-Forward and Health Check

```bash
kubectl port-forward -n hermes svc/hermes-qdrant 6333:6333 &
curl -s http://127.0.0.1:6333/ | head
```

### Step 3 — Create Collection

Lab uses **4 dimensions** for readable demo vectors; production uses model-native size (384–1536).

```bash
chmod +x infrastructure/aws/cli/ch36-init-hermes-memory-collection.sh
./infrastructure/aws/cli/ch36-init-hermes-memory-collection.sh
```

Equivalent API:

```bash
curl -X PUT 'http://127.0.0.1:6333/collections/hermes-memory' \
  -H 'Content-Type: application/json' \
  -d '{"vectors": {"size": 4, "distance": "Cosine"}}'
```

### Step 4 — Write Sample Memories

```bash
chmod +x infrastructure/aws/cli/ch36-vector-retrieval-demo.sh
./infrastructure/aws/cli/ch36-vector-retrieval-demo.sh
```

Upserts three payload-tagged points (weather vs finance). Search with a weather-like query vector returns nearest neighbors—**semantic recall without keyword match**.

### Step 5 — Upgrade Hermes API Wiring

Re-deploy `hermes-lab` so API Pods receive Qdrant env vars:

```bash
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes
kubectl exec -n hermes deploy/hermes-api -- env | grep QDRANT
```

Stub API echoes env today; production Hermes will call Qdrant on read/write paths.

### Step 6 — Retrieval in the Hermes Flow

Conceptual integration (Part VI/VII):

1. **Ingest** — after tool call or turn completion, embed summary → upsert with `{source, session_id, timestamp}`
2. **Query** — on new user message, embed query → search top-k → merge into prompt
3. **Bound** — retention policy: max vectors per user, TTL, or periodic compaction

### Step 7 — Observability

**Logs** ([Chapter 34](../part-v-infrastructure/34-logging.md)):

```logql
{namespace="hermes"} |= "qdrant" or {namespace="hermes"} | json | event="retrieval"
```

**Metrics** — Qdrant exposes `/metrics` for Prometheus ([Chapter 33](../part-v-infrastructure/33-monitoring.md)); watch memory usage as collection grows.

---

## Hands-on Lab

### Lab 35: Semantic Memory

**Estimated Time:** 60 minutes

**Goal:** Qdrant running; `hermes-memory` collection; similarity search returns relevant payloads.

**Steps:**

1. Install `hermes-qdrant` Helm release
2. Create `hermes-memory` collection
3. Run retrieval demo script; capture JSON search results
4. Upgrade `hermes-lab`; verify `QDRANT_HOST` in API Pod
5. Document three memory layers in `~/hermes-platform/notes/hermes-memory.md`
6. Optional: delete collection and recreate with `VECTOR_SIZE=384` to practice dimension discipline

---

## Verification

- [ ] Qdrant Pod Running; PVC bound (if persistence enabled)
- [ ] Collection `hermes-memory` exists
- [ ] Search returns weather payloads for weather-like query vector
- [ ] API Pods have `QDRANT_HOST=hermes-qdrant`
- [ ] You can explain Postgres vs Redis vs Qdrant
- [ ] You can draw write path and RAG read path

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Collection create fails | Qdrant not ready | Wait for Pod; check port-forward |
| Search dimension mismatch | Vector size ≠ collection | Recreate collection or fix embedding size |
| Empty search results | No points upserted | Run demo script; verify collection name |
| Qdrant OOM | Collection too large for RAM | Lower retention; reduce vector count; increase limits |
| Slow embed on CPU | Large model on single node | Smaller model; batch offline; GPU path later |

### Failure Modes

**Embedding drift** — Change embedding model without re-indexing. Vectors from old and new models are incompatible. Fix: version collections (`hermes-memory-v2`).

**Semantic overload** — Unbounded upserts degrade recall and exhaust disk. Fix: **bounded semantic memory**—TTL, max points per session, summarization before store.

**Retrieval hallucination** — Nearest neighbor ≠ correct context. Fix: score thresholds, metadata filters, reranking, human-in-loop for high-stakes tools.

**Stale memory injection** — Outdated vectors skew reasoning. Fix: timestamps in payload; decay or exclude old entries; explicit "forget" API.

---

## Review Questions

1. Why are vectors not a replacement for PostgreSQL?
2. What does cosine similarity approximate in semantic space?
3. Why must collection vector size match the embedding model?
4. Where does retrieval sit in the RAG read path?
5. Why use bounded semantic memory on k3s?

---

## Key Takeaways

- **Vector DB introduces semantic state** into a running distributed system
- **Three memory layers**: Postgres (structured), Redis (ephemeral), Qdrant (meaning)
- **Write path** embeds and stores; **read path** searches and augments prompts
- **Hermes gains semantic continuity**—recall by meaning, not only by ID
- **Retrieval is runtime behavior**—part of agent execution, not an offline batch job
- **Bounded memory** is required on single-node k3s—volume and CPU are finite

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Embedding** | Dense vector representation of text meaning from a model. |
| **Similarity search** | Finding nearest vectors to a query vector in embedding space. |
| **Collection** | Qdrant namespace for vectors of fixed dimension and distance metric. |
| **RAG** | Retrieval-Augmented Generation—inject retrieved context before model output. |
| **Payload** | Metadata stored with each vector (source text, session, tool name). |

---

## Further Reading

- [Qdrant documentation](https://qdrant.tech/documentation/)
- [Qdrant Helm chart](https://github.com/qdrant/qdrant-helm)
- [Chapter 35: Running Hermes](35-running-hermes.md)
- [Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

Hermes lab stack         ✓
PostgreSQL (state)       ✓
Redis (coordination)     ✓
Qdrant (semantic)        ✓

Real embeddings          ◐ (Part VI/VII)
RAG in Hermes API        ◐ (Part VII)

llama.cpp inference      ◐ (Ch 37)
───────────────────────────────────────────────
```

```text
Execution → Observation → Memory (state + meaning)
```

---

## What's Next

[Chapter 37: Model Serving](37-model-serving.md) — replace the model stub with llama.cpp inference; connect retrieval output to the model layer.

---

[← Chapter 35: Running Hermes](35-running-hermes.md) | [Next: Chapter 37 — Model Serving →](37-model-serving.md)
