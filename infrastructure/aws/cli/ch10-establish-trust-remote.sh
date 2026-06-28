#!/usr/bin/env bash
# Apply Chapter 10 trust hardening on hermes-controlplane-01 via SSH.
# Review before running. Requires controlplane.env and working key auth.
set -euo pipefail

: "${HERMES_PUBLIC_IP:?source controlplane.env}"
: "${HERMES_KEY_NAME:?source controlplane.env}"

KEY_PATH="${HOME}/.ssh/${HERMES_KEY_NAME}.pem"
SSH="ssh -i ${KEY_PATH} -o StrictHostKeyChecking=accept-new ubuntu@${HERMES_PUBLIC_IP}"

$SSH 'sudo tee /etc/ssh/sshd_config.d/99-hermes-trust.conf' <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
EOF

$SSH 'sudo sshd -t && sudo systemctl reload sshd'

$SSH 'sudo ufw default deny incoming; sudo ufw default allow outgoing; sudo ufw allow 22/tcp; sudo ufw --force enable'

$SSH 'sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades || true'

echo "Trust hardening applied. Run verification from Chapter 10."
