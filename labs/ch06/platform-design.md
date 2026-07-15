# Lab 6 — Hermes Platform Design Worksheet

Complete after reading [Chapter 6](../../docs/part-i-foundations/06-designing-the-hermes-platform.md).

## Platform components

| Component    | Purpose (one sentence) | Separate service? | AWS / on-node | Chapter |
| ------------ | ---------------------- | ----------------- | ------------- | ------- |
| Hermes API   |                        | Yes               | AWS           |         |
| llama.cpp    |                        | Yes               | on-node       |         |
| PostgreSQL   |                        | Yes               | on-node       |         |
| Redis        |                        | Yes               | AWS           |         |
| Traefik      |                        | Yes               | on-node       |         |
| MCP Server A |                        | Yes               | AWS           |         |
| k3s          |                        | —                 | on-node       |         |
| Docker       |                        | —                 | on-node       |         |

## Request lifecycle (8 steps)

8.

## Compute choice

- **Instance type:**
- **Why:**
- **Estimated monthly cost (EC2 + EBS):**

## Security Group rules (day one)

| Port | Source | Purpose |
| ---- | ------ | ------- |
|      |        |         |
|      |        |         |
|      |        |         |

## Scaling trigger (future)

When would you add a GPU node or second instance?

---

**Check:** Hermes and llama.cpp are listed as separate rows—not merged.
