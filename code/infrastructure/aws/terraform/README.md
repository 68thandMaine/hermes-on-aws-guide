# Terraform — Hermes Platform (Part V)

Infrastructure as Code that **reproduces Part II** manual builds.

## Layout

```text
terraform/
├── modules/
│   ├── network/       ← Chapter 8 (hermes-vpc, IGW, public subnet, route table)
│   └── controlplane/  ← Chapter 9 (planned — EC2, EBS, SG, EIP)
└── environments/
    └── dev/           ← Chapter 30 lab entry point
```

## Quick start (Chapter 30)

```bash
cd code/infrastructure/aws/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
export AWS_PROFILE=hermes
terraform init
terraform plan
terraform apply
```

## State

- Local state: `terraform.tfstate` (gitignored)
- Production: remote state in S3 + DynamoDB lock (later chapter)

## Relationship to other artifacts

| Manual (Part II) | Terraform | Bootstrap |
|------------------|-----------|-----------|
| Ch 8 VPC | `modules/network` | — |
| Ch 9 EC2 | `modules/controlplane` (planned) | `cloud-init/hermes-controlplane-bootstrap.sh` |
| Ch 13 k3s | — | `cli/ch13-install-k3s.sh` |

## Relationship to CI

Chapter 31 adds [`.github/workflows/terraform.yml`](../../../../.github/workflows/terraform.yml) — runs on changes under `code/infrastructure/aws/terraform/`.

Configure repository secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (see chapter). Optional GitHub **environment** `terraform-dev` gates apply on `main`.

**Goal:** Nothing you build by hand should stay hand-built forever.
