# Chapter 32 — create demo secret in AWS Secrets Manager (lab)
# Usage: AWS_PROFILE=hermes ./ch32-create-hermes-api-secret.sh
# Replace the placeholder value before running in a real account.

set -euo pipefail

SECRET_NAME="${SECRET_NAME:-hermes/api-key}"
SECRET_VALUE="${SECRET_VALUE:-hermes-lab-api-key-change-me}"
AWS_REGION="${AWS_REGION:-us-west-2}"

export AWS_PROFILE="${AWS_PROFILE:-hermes}"

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "Secret $SECRET_NAME already exists — updating value"
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_VALUE" \
    --region "$AWS_REGION"
else
  echo "Creating secret $SECRET_NAME"
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Hermes API key — Chapter 32 lab (not production)" \
    --secret-string "$SECRET_VALUE" \
    --region "$AWS_REGION"
fi

echo "Done. Verify:"
aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$AWS_REGION" \
  --query 'Name' --output text
