#!/usr/bin/env bash
# Chapter 11 — S3 bucket, volume tags, initial snapshots (run from laptop)
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-hermes}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
source "${HOME}/hermes-platform/notes/controlplane.env"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="hermes-platform-backups-${ACCOUNT_ID}"

if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
    ${AWS_REGION:+--create-bucket-configuration LocationConstraint=$AWS_REGION} 2>/dev/null || \
  aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
  aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

echo "S3_BUCKET=$BUCKET" >> "${HOME}/hermes-platform/notes/storage.env"

for vol in $(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' --output text); do
  snap=$(aws ec2 create-snapshot --volume-id "$vol" \
    --description "Hermes initial snapshot $(date +%F)" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=hermes-initial-$(date +%F)},{Key=Project,Value=hermes}]" \
    --query SnapshotId --output text)
  echo "Snapshot $snap for volume $vol"
done

echo "Done. Complete restore exercise from Chapter 11."
