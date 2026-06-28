#!/usr/bin/env bash
# Provision hermes-controlplane-01 — see docs/part-ii-aws/09-provisioning-hermes-server.md
#
# Usage:
#   export AWS_PROFILE=hermes AWS_REGION=us-east-1
#   source ~/hermes-platform/notes/network-resources.env
#   bash infrastructure/aws/cli/ch09-provision-controlplane.sh
#
set -euo pipefail

: "${HERMES_VPC_ID:?Set HERMES_VPC_ID — source network-resources.env}"
: "${HERMES_PUBLIC_SUBNET_ID:?Set HERMES_PUBLIC_SUBNET_ID}"

AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-m7i.2xlarge}"
KEY_NAME="${KEY_NAME:-hermes-controlplane-key}"
ROOT_GB="${ROOT_GB:-100}"
MODELS_GB="${MODELS_GB:-300}"
DATA_GB="${DATA_GB:-100}"
MY_IP="$(curl -s https://checkip.amazonaws.com | tr -d '\n')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA_FILE="${SCRIPT_DIR}/../cloud-init/hermes-controlplane-bootstrap.sh"

AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")

if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text \
    --region "$AWS_REGION" > "${HOME}/.ssh/${KEY_NAME}.pem"
  chmod 600 "${HOME}/.ssh/${KEY_NAME}.pem"
  echo "Wrote private key to ~/.ssh/${KEY_NAME}.pem"
fi

SG_ID=$(aws ec2 create-security-group \
  --group-name hermes-controlplane-sg \
  --description "Hermes control plane — SSH from operator IP only (Ch 9)" \
  --vpc-id "$HERMES_VPC_ID" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=hermes-controlplane-sg" "Name=vpc-id,Values=$HERMES_VPC_ID" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region "$AWS_REGION")

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "${MY_IP}/32" \
  --region "$AWS_REGION" 2>/dev/null || true

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --subnet-id "$HERMES_PUBLIC_SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --user-data "file://${USER_DATA_FILE}" \
  --block-device-mappings \
    "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${ROOT_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}},{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":${MODELS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":false}},{\"DeviceName\":\"/dev/sdg\",\"Ebs\":{\"VolumeSize\":${DATA_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":false}}]" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=hermes-controlplane-01},{Key=Project,Value=hermes},{Key=Role,Value=controlplane}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$AWS_REGION")

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

# Tag EBS volumes (hermes-root, hermes-models, hermes-data)
for vol in $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' --output text); do
  size=$(aws ec2 describe-volumes --volume-ids "$vol" --region "$AWS_REGION" --query 'Volumes[0].Size' --output text)
  case "$size" in
    100)
      # First 100G may be root or data — check attachment device
      dev=$(aws ec2 describe-volumes --volume-ids "$vol" --region "$AWS_REGION" \
        --query 'Volumes[0].Attachments[0].Device' --output text)
      if [[ "$dev" == */sda1 || "$dev" == *nvme0n1 ]]; then name=hermes-root; else name=hermes-data; fi
      ;;
    300) name=hermes-models ;;
    *) name=hermes-ebs-${size}gb ;;
  esac
  aws ec2 create-tags --resources "$vol" --tags "Key=Name,Value=${name}" "Key=Project,Value=hermes" --region "$AWS_REGION"
done

EIP_ALLOC=$(aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=hermes-controlplane-eip}]' \
  --query AllocationId \
  --output text \
  --region "$AWS_REGION")

aws ec2 associate-address \
  --instance-id "$INSTANCE_ID" \
  --allocation-id "$EIP_ALLOC" \
  --region "$AWS_REGION"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region "$AWS_REGION")

mkdir -p ~/hermes-platform/notes
cat >> ~/hermes-platform/notes/controlplane.env <<EOF
# hermes-controlplane-01 — $(date +%Y-%m-%d)
export HERMES_INSTANCE_ID=$INSTANCE_ID
export HERMES_PUBLIC_IP=$PUBLIC_IP
export HERMES_SG_ID=$SG_ID
export HERMES_KEY_NAME=$KEY_NAME
EOF

echo "Instance $INSTANCE_ID running at $PUBLIC_IP"
echo "SSH: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
