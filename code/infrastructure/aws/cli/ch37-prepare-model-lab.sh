#!/usr/bin/env bash
# Chapter 37 — prepare /models/model.gguf on the k3s node (run via SSH on control plane)
# Does not download automatically — documents safe lab paths.
set -euo pipefail

MODEL_LINK="${MODEL_LINK:-/models/model.gguf}"

echo "=== Hermes model lab prep (Chapter 37) ==="
echo
echo "llama-server expects: ${MODEL_LINK} on the k3s node (hostPath mount)."
echo "This should live on the hermes-models EBS volume from Chapter 11 (/models)."
echo
echo "Option A — symlink an existing GGUF:"
echo "  sudo ln -sf /models/qwen/your-model.Q4_K_M.gguf ${MODEL_LINK}"
echo
echo "Option B — copy a small lab model you downloaded to /models/:"
echo "  sudo cp /models/path/to/tiny.gguf ${MODEL_LINK}"
echo
echo "Verify on the node:"
echo "  ls -lh ${MODEL_LINK}"
echo "  file ${MODEL_LINK}"
echo
if [[ "${1:-}" == "--check" ]]; then
  if [[ -f "${MODEL_LINK}" ]]; then
    ls -lh "${MODEL_LINK}"
    echo "OK: model file present"
  else
    echo "MISSING: ${MODEL_LINK} — create before helm install llama-server"
    exit 1
  fi
fi
