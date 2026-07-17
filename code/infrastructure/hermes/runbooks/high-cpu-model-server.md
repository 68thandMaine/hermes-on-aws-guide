# Chapter 41 — example runbook (model server high CPU)
# See docs/part-vii-hermes/41-operating-hermes-in-production.md

## Alert: HighCPU on llama-server

**Symptoms:** Prometheus alert `NginxDemoHighCPU` pattern on `llama-server` pods; elevated p95 inference latency.

### Steps

1. **Confirm scope** — Grafana: `{namespace="hermes", app="llama-server"}` CPU and request rate.
2. **Check recent deploys** — `kubectl rollout history deployment/llama-server -n hermes`
3. **Inspect queue depth** — Redis pending tasks; worker logs for backlog.
4. **Scale** — If GPU/CPU headroom: increase replicas only when model supports parallel slots (`-np` in Ch 37).
5. **Rollback model** — If correlated with model tag change: restore previous `llama-server` image or GGUF symlink on node.
6. **Document** — Post incident note with `root_request_id` samples if user-facing.

### Escalation

- Node saturation → [Chapter 16](../../../../docs/part-ii-aws/16-managing-platform-costs.md) resize or Ch 38 GPU path.
- Data loss risk → pause writes; verify Postgres/Qdrant backups before destructive action.
