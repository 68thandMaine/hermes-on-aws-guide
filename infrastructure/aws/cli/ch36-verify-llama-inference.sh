#!/usr/bin/env bash
# Chapter 36 — verify llama.cpp /completion from inside cluster or via port-forward
set -euo pipefail

NAMESPACE="${NAMESPACE:-hermes}"
SERVICE="${SERVICE:-llama-server}"
PORT="${PORT:-8080}"
PROMPT="${PROMPT:-Hello from Hermes lab. Reply in one short sentence.}"

echo "Checking llama-server pods..."
kubectl get pods -n "$NAMESPACE" -l app="$SERVICE"

echo "Port-forward ${SERVICE} (background)..."
kubectl port-forward -n "$NAMESPACE" "svc/${SERVICE}" "${PORT}:${PORT}" >/tmp/ch36-pf.log 2>&1 &
PF_PID=$!
sleep 3

cleanup() { kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

echo "Health:"
curl -sf "http://127.0.0.1:${PORT}/health" || echo "(health endpoint may appear after model load)"

echo
echo "Completion request..."
curl -sf "http://127.0.0.1:${PORT}/completion" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello from Hermes lab.","n_predict":48,"stream":false}' \
  | head -c 2000

echo
echo "Done."
