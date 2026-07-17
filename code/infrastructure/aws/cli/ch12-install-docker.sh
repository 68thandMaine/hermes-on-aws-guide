#!/usr/bin/env bash
# Chapter 12 — Install Docker Engine on hermes-controlplane-01 (run from laptop)
set -euo pipefail

source "${HOME}/hermes-platform/notes/controlplane.env"
KEY="${HOME}/.ssh/${HERMES_KEY_NAME}.pem"
HOST="ubuntu@${HERMES_PUBLIC_IP}"

ssh -i "$KEY" "$HOST" 'bash -s' <<'REMOTE'
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo mkdir -p /data/docker
sudo tee /etc/docker/daemon.json <<'JSON'
{
  "data-root": "/data/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

sudo systemctl enable docker
sudo systemctl restart docker
sudo usermod -aG docker ubuntu

echo "Docker installed. Log out and back in for group membership, or use newgrp docker."
REMOTE

echo "Run verification from Chapter 12 after reconnecting SSH."
