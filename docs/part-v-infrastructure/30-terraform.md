---
sidebar_position: 30
description: "Infrastructure as Code — Terraform codifies Part II AWS for reproducible Hermes environments."
---

# Chapter 30: Terraform

> Kubernetes defines the system.
>
> Terraform defines the environment that runs the system.

---

Part IV operated **inside** k3s. Part V steps **one layer down**: the AWS foundation you built manually in [Chapters 7–11](../part-ii-aws/07-provisioning-aws-account.md) becomes **Infrastructure as Code (IaC)**.

```text
Part II (manual)     →  specification by doing
Chapter 30 (Terraform) →  same specification, reproducible
```

You are not learning a new mental model. Terraform is **declarative desired state**—the same pattern as Kubernetes Deployments, applied to VPCs and EC2 instead of Pods.

:::note[Why this matters for Hermes]

Hermes runs on a **machine that produces a cluster**. If that machine is hand-built, every environment drifts. Terraform makes `hermes-vpc`, `hermes-controlplane-01`, and security boundaries **repeatable**—dev, staging, disaster rebuild.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain IaC vs manual AWS console/CLI provisioning
- [ ] Run `terraform init`, `plan`, and `apply` for the Hermes network module
- [ ] Map Terraform resources to [Chapter 8](../part-ii-aws/08-creating-network-for-hermes.md) resources
- [ ] Describe `terraform.tfstate` and drift
- [ ] Explain how Terraform outputs feed the k3s bootstrap ([Chapter 13](../part-ii-aws/13-the-first-control-plane.md))
- [ ] Articulate the full stack: Terraform → k3s → Kubernetes → Hermes

---

## Prerequisites

- Part II complete (or willingness to apply Terraform to a **separate dev** account/VPC—do not destroy production notes without planning)
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5+
- AWS CLI profile `hermes` ([Chapter 7](../part-ii-aws/07-provisioning-aws-account.md))

```bash
export AWS_PROFILE=hermes
aws sts get-caller-identity
terraform version
```

---

## Estimated Time

**90 minutes** — 30 minutes reading, 60 minutes init/plan/apply (network module only).

---

## Background

### The Problem

Until now:

- EC2 and VPC **existed** because you created them in Part II
- k3s install assumed a server was already there
- Rebuild meant re-running many CLI steps from memory

Real platforms need:

> **Reproducible infrastructure creation**

Without IaC: environments drift, rebuilds are error-prone, and debugging "what differs from prod?" is painful.

### Terraform Mental Model

```text
Human Intent          ← .tf files + variables
Terraform Core        ← plan/apply, state diff
AWS Provider          ← API calls
Real Infrastructure   ← VPC, EC2, SG, EBS
         ↓
cloud-init / k3s      ← Chapter 9 / 13 bootstrap
         ↓
Kubernetes            ← Part IV
```

| Kubernetes | Terraform |
|------------|-----------|
| Pod, Deployment | aws_vpc, aws_instance |
| kubectl apply | terraform apply |
| etcd state | terraform.tfstate |
| Controller reconcile | plan → apply loop |

### Core Concepts

| Concept | Meaning |
|---------|---------|
| **Provider** | AWS plugin (`hashicorp/aws`) |
| **Resource** | One infrastructure object (`aws_vpc`) |
| **Module** | Reusable bundle (network, controlplane) |
| **State** | `terraform.tfstate` — Terraform's etcd |
| **Plan** | Proposed diff before apply |
| **Apply** | Execute changes |

**State is critical.** If state is lost, Terraform loses track of what it created. Use remote state (S3 + DynamoDB lock) in production—introduced after this lab.

---

## Architecture

### What This Chapter Codifies

The repo module **`code/infrastructure/aws/terraform/modules/network/`** matches [Chapter 8](../part-ii-aws/08-creating-network-for-hermes.md):

| Terraform resource | Chapter 8 name |
|--------------------|----------------|
| `aws_vpc` | `hermes-vpc` `10.0.0.0/16` |
| `aws_internet_gateway` | `hermes-igw` |
| `aws_subnet` | `hermes-public-usw2a` `10.0.1.0/24` |
| `aws_route_table` | `hermes-public-rt` → `0.0.0.0/0` → IGW |

**EC2 + EBS + SG** remain the next module (`controlplane`)—same pattern as [Chapter 9](../part-ii-aws/09-provisioning-hermes-server.md), with `user_data` from [`hermes-controlplane-bootstrap.sh`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/code/infrastructure/aws/cloud-init/hermes-controlplane-bootstrap.sh).

### Full Stack

```text
Terraform        →  AWS (VPC, EC2, EBS, SG)
       ↓
k3s install      →  control plane (Ch 13)
       ↓
Kubernetes       →  workloads (Part IV)
       ↓
Hermes           →  application (Part VI/VII)
```

Two orchestrators: **Terraform** (infra), **Kubernetes** (runtime).

---

## Walkthrough

### Step 1 — Review the Module

```text
code/infrastructure/aws/terraform/
├── modules/
│   └── network/          ← Chapter 8 as code
└── environments/
    └── dev/              ← lab entry point
```

Open `modules/network/main.tf`—compare each resource to your Chapter 8 notes.

### Step 2 — Choose Apply Strategy

| Situation | Action |
|-----------|--------|
| **Fresh dev account / new VPC** | Apply Terraform as written |
| **Part II already built `hermes-vpc`** | Use a **new** `name_prefix` (e.g. `hermes-tf-dev`) or `terraform import`—do not duplicate CIDR in same account without planning |

This lab assumes a **non-conflicting** apply (new prefix or clean dev account).

### Step 3 — Init and Plan

```bash
cd code/infrastructure/aws/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit name_prefix if hermes-vpc already exists manually

terraform init
terraform plan
```

Review the plan: **4 resources to add** (VPC, IGW, subnet, route table + association).

### Step 4 — Apply

```bash
terraform apply
```

Type `yes` when prompted. Capture outputs:

```bash
terraform output
```

### Step 5 — Verify Against AWS

```bash
export AWS_PROFILE=hermes
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hermes-vpc" \
  --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock}' --output table
aws ec2 describe-subnets --filters "Name=tag:Name,Values=hermes-public-usw2a" \
  --query 'Subnets[].{Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone}' --output table
```

Match [Chapter 8 verification](../part-ii-aws/08-creating-network-for-hermes.md).

### Step 6 — EC2 Module (Design Preview)

Control plane as code (apply in a follow-on lab—not required to destroy manual server):

```hcl
# Illustration — modules/controlplane/ (future)
resource "aws_instance" "controlplane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m7i.2xlarge"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.controlplane.id]
  user_data              = file("${path.module}/../../cloud-init/hermes-controlplane-bootstrap.sh")

  tags = { Name = "hermes-controlplane-01" }
}
```

`subnet_id` comes from `module.network.public_subnet_id` output—**Terraform wires layers like Helm wires Kubernetes objects**.

### Step 7 — Destroy (Optional Dev Cleanup)

```bash
terraform destroy
```

Never destroy stateful production without backups ([Chapter 11](../part-ii-aws/11-persistent-storage.md)).

---

## Hands-on Lab

### Lab 29: Network as Code

**Estimated Time:** 60 minutes

**Goal:** Apply Hermes VPC module; verify outputs match Chapter 8 design.

**Steps:**

1. `terraform init` in `environments/dev`
2. `terraform plan` — read every line
3. `terraform apply`
4. Verify VPC/subnet with AWS CLI
5. Save outputs to `~/hermes-platform/notes/terraform-dev.env`
6. Optional: `terraform destroy` if lab-only

---

## Verification

- [ ] `terraform apply` succeeded
- [ ] Outputs include `vpc_id` and `public_subnet_id`
- [ ] AWS CLI shows VPC `10.0.0.0/16` and subnet `10.0.1.0/24`
- [ ] You can explain state file purpose
- [ ] You can draw Terraform → k3s → Kubernetes → Hermes stack

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| CIDR overlap | Manual VPC same CIDR | Change `vpc_cidr` or use import |
| Access denied | Wrong profile | `export AWS_PROFILE=hermes` |
| State lock | Interrupted apply | Remove lock file only if sure no other apply running |
| Drift detected | Manual console edit | `terraform plan` shows diff; reconcile or refresh |
| `0.0.0.0/0` on SG in examples | Tutorial anti-pattern | **Never** open SSH to world in prod—use your `/32` from Ch 10 |

### Failure Modes

**State drift** — Manual AWS changes confuse Terraform. Prefer all changes via `.tf` files.

**Partial apply** — Some resources created, apply failed mid-way. Fix error; re-apply; inspect state.

**Lost state** — Terraform may try to recreate or duplicate. Use remote state + backups.

---

## Review Questions

1. How is `terraform apply` like `kubectl apply`?
2. What does `terraform.tfstate` store?
3. Which Part II chapter does the network module codify?
4. Why separate Terraform (infra) from Kubernetes (runtime)?
5. What output does the controlplane module need from the network module?

---

## Key Takeaways

- **Terraform defines the machine that produces k3s**
- **State file** is the source of truth for IaC—protect it
- **Modules** mirror Part II chapters (network first, controlplane next)
- **Hermes spans two orchestrators** — infra + runtime
- Manual Part II was the spec; Terraform is the repeatable implementation

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **IaC** | Infrastructure as Code—declarative, versioned infrastructure. |
| **terraform.tfstate** | Record of managed resources; required for planning. |
| **Drift** | Real infrastructure differs from Terraform state/code. |
| **Module** | Reusable Terraform configuration bundle. |

---

## Further Reading

- [Terraform AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform state](https://developer.hashicorp.com/terraform/language/state)
- [Chapter 8: Creating the Network](../part-ii-aws/08-creating-network-for-hermes.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account (manual)     ✓
Network (Terraform lab) ✓
EC2 / k3s (manual)       ✓
Kubernetes platform      ✓

Terraform network module ✓
Terraform controlplane   ◐ (next module)

Hermes application       ✗
───────────────────────────────────────────────
```

Part V begins: codify, automate, harden.

---

## What's Next

[Chapter 31: GitHub Actions](31-github-actions.md) — CI/CD that runs `terraform plan` on every change.

Production-grade secrets beyond K8s Secrets: [Chapter 32: Secrets Management](32-secrets-management.md).

---

[← Chapter 29: Scaling](../part-iv-kubernetes/29-scaling.md) | [Next: Chapter 31 — GitHub Actions →](31-github-actions.md)
