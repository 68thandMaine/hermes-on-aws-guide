#!/usr/bin/env bash
# Chapter 38 — GPU node prep checklist for k3s + Hermes (run on GPU EC2 + operator laptop)
set -euo pipefail

NODE_NAME="${NODE_NAME:-}"
LABEL_KEY="${LABEL_KEY:-accelerator}"
LABEL_VALUE="${LABEL_VALUE:-nvidia}"

echo "=== Chapter 38 GPU node prep ==="
echo
echo "1. AWS: launch g5.xlarge (or g5.2xlarge) in same VPC as control plane"
echo "2. On GPU instance (Ubuntu): install NVIDIA driver + nvidia-container-toolkit"
echo "   https://docs.k3s.io/advanced#nvidia-gpu-support"
echo "3. Join node to k3s cluster (agent role) or use GPU as dedicated inference node"
echo "4. Verify on GPU node:"
echo "   nvidia-smi"
echo "5. Install NVIDIA device plugin:"
echo "   kubectl apply -f code/infrastructure/kubernetes/ch38-nvidia-device-plugin.yaml"
echo "6. Label GPU node:"
echo "   kubectl label node <gpu-node-name> ${LABEL_KEY}=${LABEL_VALUE} --overwrite"
echo

if [[ -n "$NODE_NAME" ]]; then
  kubectl label node "$NODE_NAME" "${LABEL_KEY}=${LABEL_VALUE}" --overwrite
  echo "Labeled node $NODE_NAME"
fi

echo
echo "Verify allocatable GPUs:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu 2>/dev/null || \
  kubectl describe nodes | grep -A2 nvidia.com/gpu || echo "(device plugin not ready yet)"
