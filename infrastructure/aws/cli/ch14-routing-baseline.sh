#!/usr/bin/env bash
# Chapter 14 — Route 53 A record + routing notes (run from laptop)
# Install cert-manager / ClusterIssuer / Ingress per chapter walkthrough.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-hermes}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
source "${HOME}/hermes-platform/notes/controlplane.env"

: "${HERMES_DOMAIN:?Set HERMES_DOMAIN=example.com}"
: "${HERMES_HOSTNAME:=hermes.${HERMES_DOMAIN}}"
: "${HERMES_PUBLIC_IP:?HERMES_PUBLIC_IP missing from controlplane.env}"
: "${HERMES_SG_ID:?HERMES_SG_ID missing from controlplane.env}"

echo "=== Resolve hosted zone for ${HERMES_DOMAIN} ==="
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${HERMES_DOMAIN}." \
  --query "HostedZones[?Name=='${HERMES_DOMAIN}.'].Id | [0]" \
  --output text | sed 's|/hostedzone/||')

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "None" ]]; then
  echo "No hosted zone for ${HERMES_DOMAIN}. Create one first:"
  echo "  aws route53 create-hosted-zone --name ${HERMES_DOMAIN} --caller-reference hermes-\$(date +%s)"
  exit 1
fi

echo "Hosted zone: ${ZONE_ID}"
echo "=== UPSERT A ${HERMES_HOSTNAME} → ${HERMES_PUBLIC_IP} ==="
TMP_BATCH=$(mktemp)
cat > "$TMP_BATCH" <<EOF
{
  "Comment": "Hermes control plane public hostname",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${HERMES_HOSTNAME}",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{"Value": "${HERMES_PUBLIC_IP}"}]
    }
  }]
}
EOF
aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "file://${TMP_BATCH}"
rm -f "$TMP_BATCH"

echo "=== Security Group 80/443 (0.0.0.0/0 for ACME + HTTPS; see EDR-0009) ==="
aws ec2 authorize-security-group-ingress \
  --group-id "$HERMES_SG_ID" \
  --ip-permissions \
    IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTP ACME and redirect"}]' \
    IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTPS Traefik"}]' \
  2>/dev/null || echo "SG rules may already exist"

NOTES="${HOME}/hermes-platform/notes/routing.env"
mkdir -p "$(dirname "$NOTES")"
{
  echo "export HERMES_DOMAIN=${HERMES_DOMAIN}"
  echo "export HERMES_HOSTNAME=${HERMES_HOSTNAME}"
  echo "export HERMES_HOSTED_ZONE_ID=${ZONE_ID}"
  echo "export HERMES_TLS_SECRET=hermes-https-tls"
  echo "export HERMES_CLUSTER_ISSUER=letsencrypt-prod"
} > "$NOTES"

echo "Wrote ${NOTES}"
echo "Next: install cert-manager and apply ClusterIssuer + TLS Ingress (Chapter 14 walkthrough)."
echo "Verify DNS: dig +short ${HERMES_HOSTNAME}"
