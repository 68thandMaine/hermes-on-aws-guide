#!/usr/bin/env bash
# Chapter 13 — Install k3s on hermes-controlplane-01 (run from laptop)
set -euo pipefail

source "${HOME}/hermes-platform/notes/controlplane.env"
KEY="${HOME}/.ssh/${HERMES_KEY_NAME}.pem"
HOST="ubuntu@${HERMES_PUBLIC_IP}"

ssh -i "$KEY" "$HOST" 'bash -s' <<'REMOTE'
set -euxo pipefail

# Single-node k3s server — control plane + worker on hermes-controlplane-01
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" sh -

sudo systemctl enable k3s
sudo systemctl status k3s --no-pager

sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
REMOTE

mkdir -p "${HOME}/.kube"
scp -i "$KEY" "${HOST}:/etc/rancher/k3s/k3s.yaml" "${HOME}/.kube/hermes-k3s.yaml"
sed -i.bak "s/127.0.0.1/${HERMES_PUBLIC_IP}/" "${HOME}/.kube/hermes-k3s.yaml" 2>/dev/null || \
  sed -i '' "s/127.0.0.1/${HERMES_PUBLIC_IP}/" "${HOME}/.kube/hermes-k3s.yaml"

echo "export KUBECONFIG=${HOME}/.kube/hermes-k3s.yaml" >> "${HOME}/hermes-platform/notes/platform.env"
echo "k3s installed. kubectl: KUBECONFIG=~/.kube/hermes-k3s.yaml kubectl get nodes"
