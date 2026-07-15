# Terraform Starter Configurations

Starter Terraform files for Chapter 14 (Route 53 / TLS) will live here.

## Planned Files

```
terraform/
├── main.tf           # Provider, backend, versions
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── vpc.tf            # VPC, subnets, IGW, NAT
├── ec2.tf            # EC2 instance, security groups
├── iam.tf            # IAM roles, instance profiles
├── s3.tf             # State bucket, backup bucket
└── terraform.tfvars.example
```

## Usage

These files are created during Lab 29. Until then, follow the step-by-step instructions in [Chapter 30](../../docs/part-v-infrastructure/30-terraform.md).

## Backend Setup

Before running `terraform init`, create the S3 bucket and DynamoDB table manually:

```bash
aws s3 mb s3://personal-ai-cloud-backups-<account-id>
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values. Never commit `terraform.tfvars`.
