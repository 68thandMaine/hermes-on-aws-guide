# Lab 6 — Hermes Platform Design Worksheet

Complete after reading [Chapter 6](../../docs/part-i-foundations/06-designing-the-hermes-platform.md).

## Platform components

| Component | Purpose (one sentence) | Separate service? | AWS / on-node | Chapter |
|-----------|------------------------|-------------------|---------------|---------|
| Hermes API | | Yes | | |
| llama.cpp | | Yes | | |
| PostgreSQL | | Yes | | |
| Redis | | Yes | | |
| Traefik | | Yes | | |
| MCP Server A | | Yes | | |
| k3s | | — | on-node | |
| Docker | | — | on-node | |

## Request lifecycle (8 steps)

1.
2.
3.
4.
5.
6.
7.
8.

## Compute choice

- **Instance type:**
- **Why:**
- **Estimated monthly cost (EC2 + EBS):**

## Security Group rules (day one)

| Port | Source | Purpose |
|------|--------|---------|
| | | |
| | | |
| | | |

## Scaling trigger (future)

When would you add a GPU node or second instance?

---

**Check:** Hermes and llama.cpp are listed as separate rows—not merged.
