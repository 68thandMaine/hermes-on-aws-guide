#!/usr/bin/env bash
# Chapter 35 — lab: upsert sample memories and run similarity search
# Prerequisite: hermes-memory collection exists (ch35-init-hermes-memory-collection.sh)
set -euo pipefail

QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
COLLECTION="${COLLECTION:-hermes-memory}"

echo "Upserting sample memory points..."

curl -sf -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points?wait=true" \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.9, 0.1, 0.0, 0.0],
        "payload": {"text": "User asked about Seattle weather", "source": "tool:weather"}
      },
      {
        "id": 2,
        "vector": [0.1, 0.9, 0.0, 0.0],
        "payload": {"text": "User asked about portfolio allocation", "source": "tool:finance"}
      },
      {
        "id": 3,
        "vector": [0.85, 0.12, 0.0, 0.0],
        "payload": {"text": "Prior rain forecast for Puget Sound", "source": "tool:weather"}
      }
    ]
  }'

echo
echo "Searching for neighbors of a weather-like query vector..."

curl -sf -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/search" \
  -H 'Content-Type: application/json' \
  -d '{
    "vector": [0.88, 0.1, 0.0, 0.0],
    "limit": 2,
    "with_payload": true
  }'

echo
echo "Done. Top results should favor weather-related payloads."
