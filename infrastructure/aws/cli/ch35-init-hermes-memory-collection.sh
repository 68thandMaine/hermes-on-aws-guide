#!/usr/bin/env bash
# Chapter 35 — create hermes-memory collection in Qdrant
# Prerequisite: kubectl port-forward -n hermes svc/hermes-qdrant 6333:6333
set -euo pipefail

QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
COLLECTION="${COLLECTION:-hermes-memory}"
VECTOR_SIZE="${VECTOR_SIZE:-4}"

echo "Creating collection $COLLECTION (size=$VECTOR_SIZE, Cosine) at $QDRANT_URL"

curl -sf -X PUT "${QDRANT_URL}/collections/${COLLECTION}" \
  -H 'Content-Type: application/json' \
  -d "{
    \"vectors\": {
      \"size\": ${VECTOR_SIZE},
      \"distance\": \"Cosine\"
    }
  }"

echo
curl -sf "${QDRANT_URL}/collections/${COLLECTION}" | head -c 500
echo
echo "Done."
