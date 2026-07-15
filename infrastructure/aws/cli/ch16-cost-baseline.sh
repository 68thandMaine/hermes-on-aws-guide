#!/usr/bin/env bash
# Chapter 16 — Tag verification, billing alarm update, monthly budget (run from laptop)
# Activate cost allocation tags in Billing console (Step 2) — not available via single CLI call.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-hermes}"
export AWS_REGION="${AWS_REGION:-us-west-2}"
# Billing EstimatedCharges metrics exist only in us-east-1
BILLING_REGION="${BILLING_REGION:-us-east-1}"
source "${HOME}/hermes-platform/notes/controlplane.env"

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUDGET_USD="${HERMES_MONTHLY_BUDGET_USD:-400}"
ALARM_USD="${HERMES_BILLING_ALARM_USD:-350}"
TOPIC_NAME="${HERMES_ALERTS_TOPIC:-hermes-platform-alerts}"
SNS_ARN="arn:aws:sns:${BILLING_REGION}:${ACCOUNT}:${TOPIC_NAME}"

echo "=== Tag Hermes resources (idempotent) ==="
for rid in "$HERMES_INSTANCE_ID" "${HERMES_VPC_ID:-}"; do
  [[ -z "$rid" || "$rid" == "null" ]] && continue
  aws ec2 create-tags --resources "$rid" \
    --tags Key=Project,Value=hermes Key=Environment,Value=lab 2>/dev/null || true
done

for vol in $(aws ec2 describe-instances --instance-ids "$HERMES_INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' --output text); do
  aws ec2 create-tags --resources "$vol" \
    --tags Key=Project,Value=hermes Key=Environment,Value=lab
done

echo "=== Billing alarm in ${BILLING_REGION} (estimated charges > ${ALARM_USD} USD) ==="
aws sns create-topic --name "$TOPIC_NAME" --region "$BILLING_REGION" >/dev/null 2>&1 || true

aws cloudwatch put-metric-alarm \
  --alarm-name "hermes-estimated-charges-${ALARM_USD}usd" \
  --alarm-description "Hermes platform estimated monthly charges" \
  --namespace AWS/Billing \
  --metric-name EstimatedCharges \
  --dimensions Name=Currency,Value=USD \
  --statistic Maximum --period 21600 --evaluation-periods 1 \
  --threshold "$ALARM_USD" --comparison-operator GreaterThanThreshold \
  --alarm-actions "$SNS_ARN" \
  --region "$BILLING_REGION"

echo "=== Monthly budget (create in console if API fails — IAM budget permissions vary) ==="
if aws budgets describe-budget --account-id "$ACCOUNT" --budget-name hermes-monthly-lab >/dev/null 2>&1; then
  echo "Budget hermes-monthly-lab already exists."
else
  aws budgets create-budget --account-id "$ACCOUNT" --budget "{
    \"BudgetName\": \"hermes-monthly-lab\",
    \"BudgetLimit\": {\"Amount\": \"${BUDGET_USD}\", \"Unit\": \"USD\"},
    \"TimeUnit\": \"MONTHLY\",
    \"BudgetType\": \"COST\"
  }" 2>/dev/null && echo "Created budget hermes-monthly-lab" || \
    echo "Create budget manually: Billing → Budgets → hermes-monthly-lab at \$${BUDGET_USD}/month"
fi

NOTES="${HOME}/hermes-platform/notes/cost.env"
mkdir -p "$(dirname "$NOTES")"
{
  echo "HERMES_MONTHLY_BUDGET_USD=${BUDGET_USD}"
  echo "HERMES_BILLING_ALARM_USD=${ALARM_USD}"
  echo "HERMES_COST_REPORT=hermes-monthly-by-service"
  echo "HERMES_LAST_REVIEW=$(date +%F)"
} >> "$NOTES"

echo "Done. Activate Project/Environment in Billing → Cost allocation tags."
echo "Run first Cost Explorer review (group by Service, last 30 days)."
