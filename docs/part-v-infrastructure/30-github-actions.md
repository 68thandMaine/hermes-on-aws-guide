---
sidebar_position: 30
description: "Event-driven Terraform execution — GitHub Actions as the infrastructure control plane."
---

# Chapter 30: GitHub Actions

> Infrastructure does not change because you decide.
>
> It changes because the system decides it is time.

---

[Chapter 29](29-terraform.md) made infrastructure **declarative**. This chapter makes infrastructure changes **event-driven**.

Until now, Terraform ran on your laptop. That works for learning—it does not scale for teams, audit trails, or Hermes evolving through Git.

```text
Before:  Human → terraform apply → AWS
After:   Git event → GitHub Actions → terraform apply → AWS
```

This is the first **non-human execution actor** in the Hermes platform: CI becomes part of the control plane.

:::note Why this matters for Hermes

Hermes evolves through model updates, scaling changes, and new integrations. The platform beneath it must evolve through **Git events**, not ad-hoc terminal sessions. GitHub Actions is the delivery layer that connects repository changes to AWS reality.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain GitHub Actions as an event-driven execution layer on Git
- [ ] Wire a Terraform pipeline: validate → plan → apply
- [ ] Store AWS credentials in GitHub Secrets (never in the repo)
- [ ] Restrict `terraform apply` to the `main` branch
- [ ] Recognize CI as a **privileged infrastructure actor**
- [ ] Draw the full stack: Git → Actions → Terraform → k3s → Kubernetes → Hermes

---

## Prerequisites

- [Chapter 29](29-terraform.md) complete (network module applied locally at least once)
- GitHub repository with push access
- AWS account ([Chapter 7](../part-ii-aws/07-provisioning-aws-account.md))
- Existing [Book CI](../../.github/workflows/book-ci.yml) workflow (markdownlint, build)—unchanged by this chapter

---

## Estimated Time

**75 minutes** — 25 minutes reading, 50 minutes secrets + workflow verification.

---

## Background

### The Problem

After Chapter 29:

- Terraform code lives in Git
- **Execution** still depends on your machine and memory
- No automatic plan on pull requests
- No branch policy for who can mutate infrastructure

Gap:

> **Infrastructure exists as code, but changes are still human-driven**

We close that gap by attaching an execution layer to Git.

### GitHub Actions Mental Model

GitHub Actions is:

> an event-driven execution system attached to the repository

| Trigger | Typical use |
|---------|-------------|
| `push` | Run plan/apply after merge |
| `pull_request` | Plan only—show diff before merge |
| `workflow_dispatch` | Manual re-run |

```text
Git commit / PR
      ↓
Workflow trigger (.github/workflows/*.yml)
      ↓
Runner (ubuntu-latest)
      ↓
Steps (checkout, terraform init, plan, apply)
      ↓
AWS API (via injected credentials)
```

Same declarative pattern as Kubernetes—**desired state in Git, reconciler executes**.

### Pipeline Phases

Formalize every infrastructure change:

```text
Validate → Plan → Apply
```

| Phase | Purpose | Needs AWS creds? |
|-------|---------|------------------|
| **Validate** | Syntax and provider config | No |
| **Plan** | Compute diff vs state | Yes |
| **Apply** | Mutate AWS | Yes |

On pull requests: **validate + plan only**. On `main`: **apply** after plan succeeds.

---

## Architecture

### Repository Layout

```text
.github/
  workflows/
    book-ci.yml       ← docs site (existing)
    terraform.yml     ← Chapter 30 — AWS infrastructure
infrastructure/aws/terraform/
  modules/network/
  environments/dev/
```

Path filters limit runs to Terraform changes—book edits do not trigger AWS API calls.

### Execution Flow

```text
Developer commits .tf change
        ↓
GitHub event triggers terraform.yml
        ↓
terraform init + validate
        ↓
terraform plan (diff computed)
        ↓
Merge to main (if approved)
        ↓
terraform apply (main only)
        ↓
AWS infrastructure updated
        ↓
k3s / Kubernetes reconcile downstream
        ↓
Hermes reflects new platform state
```

### System Shift

```text
Before:
  Human → Terraform → AWS → k3s → Kubernetes

After:
  Git Event → GitHub Actions → Terraform → AWS → k3s → Kubernetes → Hermes
```

### Trust Boundary

GitHub Actions is now a **privileged actor**:

| Component | Role |
|-----------|------|
| GitHub Secrets | Credential vault (runtime injection) |
| Actions runner | Ephemeral execution environment |
| Terraform | Infrastructure mutator |
| `main` branch | Apply gate |

CI is part of the infrastructure control plane—not “just CI.”

---

## Walkthrough

### Step 1 — Create a CI IAM User (Least Privilege Path)

Do **not** reuse `hermes-admin` access keys in GitHub. Create a dedicated identity:

1. IAM → Users → **Create user** → `hermes-terraform-ci`
2. Attach a scoped policy (start narrow; expand as modules grow):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
```

3. Create **access keys** for programmatic use only
4. Store keys in a password manager—never commit them

For early labs, some readers use `AdministratorAccess` temporarily; tighten before production Hermes.

### Step 2 — Configure GitHub Secrets

Repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | CI user access key |
| `AWS_SECRET_ACCESS_KEY` | CI user secret key |

Region is set in the workflow (`us-east-1`)—same as [Chapter 8](../part-ii-aws/08-creating-network-for-hermes.md).

:::warning Never commit credentials

Keys in Git history are permanent exposure. Use Secrets only. [Chapter 31](31-secrets-management.md) covers external vaults and rotation.

:::

### Step 3 — Review the Workflow

The repo ships [`.github/workflows/terraform.yml`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/.github/workflows/terraform.yml) with three jobs:

| Job | Branch / event | AWS creds? |
|-----|----------------|------------|
| `validate` | All triggers | No |
| `plan` | All triggers | Yes |
| `apply` | `main` push / dispatch only | Yes |

Core steps:

```yaml
jobs:
  validate:
    steps:
      - run: terraform init && terraform validate
  plan:
    steps:
      - run: terraform plan -out=tfplan
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  apply:
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    environment: terraform-dev
    steps:
      - run: terraform apply -auto-approve tfplan
```

Key rules encoded:

- **Plan on every PR** that touches Terraform
- **Apply only on `main`**, never on PR events
- **`workflow_dispatch`** for manual re-runs
- **`concurrency` group** prevents overlapping applies to the same environment

### Step 4 — Local vs CI Credentials

Local ([Chapter 29](29-terraform.md)) uses AWS profile `hermes`:

```hcl
# terraform.tfvars
aws_profile = "hermes"
```

CI has no `~/.aws/credentials` profile. The dev environment supports both:

```hcl
# environments/dev/main.tf — profile omitted when empty
profile = var.aws_profile != "" ? var.aws_profile : null
```

In GitHub Actions, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` satisfy the provider. Leave `aws_profile` unset in CI.

### Step 5 — Trigger a Plan (Pull Request)

1. Create a branch: `git checkout -b ch30-terraform-ci-test`
2. Make a harmless change (e.g. add a tag in `modules/network/main.tf`)
3. Open a pull request
4. Open **Actions** → **Terraform Infrastructure Pipeline**
5. Confirm: **Validate** and **Plan** succeed; **Apply** is skipped

### Step 6 — Merge and Apply

After review, merge to `main`. The workflow runs again with apply enabled.

Monitor:

- Plan output in the job log (no secrets printed)
- AWS console or CLI for expected resources

### Step 7 — Remote State (Production Note)

Local state (`terraform.tfstate`) on your laptop does not work for team CI. Before shared apply:

- Store state in S3
- Lock with DynamoDB

This book introduces the pattern here; full remote backend setup is a follow-on lab when the controlplane module lands.

---

## Hands-on Lab

### Lab 30: Event-Driven Terraform

**Estimated Time:** 50 minutes

**Goal:** GitHub Actions runs validate + plan on PR; apply on `main`.

**Steps:**

1. Create `hermes-terraform-ci` IAM user and access keys
2. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to GitHub Secrets
3. Push a branch with a trivial Terraform tag change
4. Open PR — verify plan in Actions log
5. Merge to `main` — verify apply (or plan-only if you disable apply initially)
6. Document workflow URL in `~/hermes-platform/notes/ci-terraform.md`

**Safety:** For first run, comment out the Apply step until plan output looks correct.

---

## Verification

- [ ] Workflow file exists at `.github/workflows/terraform.yml`
- [ ] PR triggers validate + plan without apply
- [ ] Merge to `main` can apply (when secrets configured)
- [ ] No credentials in repo or workflow logs
- [ ] You can explain CI as a privileged control-plane actor
- [ ] You can draw Git → Actions → Terraform → AWS → k3s → Hermes

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Plan fails: No credentials | Secrets missing | Add GitHub Secrets; re-run workflow |
| `error configuring Terraform AWS Provider: no valid credential sources` | Empty profile + no env vars | Set secrets; ensure `aws_profile = ""` not `"hermes"` in CI |
| Apply on wrong branch | Workflow `if` misconfigured | Apply only when `github.ref == refs/heads/main` |
| State conflict | Local + CI both applying | Use one state backend; avoid dual apply |
| Secrets in logs | `echo $AWS_SECRET_ACCESS_KEY` | Never print env vars; GitHub masks secrets |
| Workflow never runs | Path filter | Change files under `infrastructure/aws/terraform/` |

### Failure Modes

**Credential exposure** — Keys in Git, logs, or fork PRs. Use Secrets; restrict fork workflows; prefer OIDC over long-lived keys ([Chapter 31](31-secrets-management.md)).

**State drift** — Manual console edits while CI owns apply. All changes via `.tf` + pipeline.

**Partial apply** — Interrupted apply leaves half-provisioned infra. Re-run plan; fix errors; use concurrency locks.

---

## Review Questions

1. Why is plan-on-PR without apply a safety mechanism?
2. What makes GitHub Actions a control plane actor, not just “CI”?
3. How does CI authentication differ from local `AWS_PROFILE=hermes`?
4. Why create `hermes-terraform-ci` instead of reusing `hermes-admin` keys?
5. What happens downstream when Terraform changes a subnet or security group?

---

## Key Takeaways

- **GitHub Actions is event-driven infrastructure execution**
- **Validate → Plan → Apply** mirrors Terraform locally, remotely
- **Git triggers provisioning** — repository becomes control plane input
- **CI is privileged** — new trust boundary alongside IAM and RBAC
- **Only `main` mutates infrastructure** — branch policy as safety gate
- **Hermes inherits automation** — platform can evolve through merges

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **GitHub Actions** | Event-driven workflow runner attached to a Git repository. |
| **Workflow** | YAML-defined pipeline triggered by Git events. |
| **GitHub Secrets** | Encrypted repository variables injected at runtime. |
| **Plan-only PR** | CI computes Terraform diff without applying—review before merge. |

---

## Further Reading

- [GitHub Actions docs](https://docs.github.com/en/actions)
- [HashiCorp setup-terraform action](https://github.com/hashicorp/setup-terraform)
- [AWS IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Chapter 29: Terraform](29-terraform.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account              ✓
Network (Terraform)      ✓
EC2 / k3s                ✓
Kubernetes platform      ✓

Terraform network module ✓
Terraform CI pipeline    ✓
Remote state / OIDC      ◐ (hardening)

Hermes application       ✗
───────────────────────────────────────────────
```

Part V: codify → **automate** → harden.

---

## What's Next

[Chapter 31: Secrets Management](31-secrets-management.md) — external secret stores, rotation, and auditability beyond Kubernetes Secrets ([Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md)).

---

[← Chapter 29: Terraform](29-terraform.md) | [Next: Chapter 31 — Secrets Management →](31-secrets-management.md)
