#!/usr/bin/env bash
# Chapter 15 — IAM profile, SNS topic, CloudWatch alarms (run from laptop)
# Install CloudWatch Agent on the server per chapter walkthrough Step 2.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-hermes}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
source "${HOME}/hermes-platform/notes/controlplane.env"

ROLE_NAME=hermes-controlplane-cloudwatch-role
PROFILE_NAME=hermes-controlplane-cloudwatch-profile
TOPIC_NAME=hermes-platform-alerts
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
SNS_ARN="arn:aws:sns:${AWS_REGION}:${ACCOUNT}:${TOPIC_NAME}"

echo "=== IAM role and instance profile ==="
aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || true

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy 2>/dev/null || true

aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null || true
aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME" 2>/dev/null || true

aws ec2 associate-iam-instance-profile \
  --instance-id "$HERMES_INSTANCE_ID" \
  --iam-instance-profile Name="$PROFILE_NAME"

echo "=== SNS topic (confirm email subscription in console) ==="
aws sns create-topic --name "$TOPIC_NAME" >/dev/null 2>&1 || true

echo "=== CloudWatch alarms ==="
aws cloudwatch put-metric-alarm \
  --alarm-name hermes-cpu-high \
  --alarm-description "Control plane CPU sustained high" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$HERMES_INSTANCE_ID" \
  --statistic Average --period 300 --evaluation-periods 3 \
  --threshold 80 --comparison-operator GreaterThanThreshold \
  --alarm-actions "$SNS_ARN"

aws cloudwatch put-metric-alarm \
  --alarm-name hermes-data-disk-low \
  --alarm-description "Less than 15% free on /data" \
  --namespace Hermes/ControlPlane \
  --metric-name disk_used_percent \
  --dimensions Name=InstanceId,Value="$HERMES_INSTANCE_ID",Name=path,Value=/data \
  --statistic Average --period 300 --evaluation-periods 2 \
  --threshold 85 --comparison-operator GreaterThanThreshold \
  --alarm-actions "$SNS_ARN"

aws cloudwatch put-metric-alarm \
  --alarm-name hermes-status-failed \
  --alarm-description "EC2 status check failed" \
  --namespace AWS/EC2 \
  --metric-name StatusCheckFailed \
  --dimensions Name=InstanceId,Value="$HERMES_INSTANCE_ID" \
  --statistic Maximum --period 60 --evaluation-periods 2 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "$SNS_ARN"

NOTES="${HOME}/hermes-platform/notes/observability.env"
mkdir -p "$(dirname "$NOTES")"
{
  echo "HERMES_LOG_GROUP=/hermes/controlplane"
  echo "HERMES_DASHBOARD=hermes-controlplane"
  echo "HERMES_ALERTS_TOPIC=${TOPIC_NAME}"
  echo "CLOUDWATCH_NAMESPACE=Hermes/ControlPlane"
  echo "HERMES_CLOUDWATCH_ROLE=${ROLE_NAME}"
} >> "$NOTES"

echo "Done. Next: install CloudWatch Agent on the server (Chapter 15 Step 2)."
echo "Subscribe an email to SNS topic: ${TOPIC_NAME}"
