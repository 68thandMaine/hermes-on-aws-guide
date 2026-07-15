---
sidebar_position: 7
description: "Create and secure the AWS account that will host the Hermes platform."
---

# Chapter 7: Provisioning Your AWS Account

> You are not learning AWS—you are provisioning infrastructure for Hermes.

---

Part I defined **what** you are building. Part II implements it.

This chapter is the first time you log into AWS and perform meaningful work. By the end, you will have a secured account, an operator identity, billing guardrails, and a working AWS CLI—everything required before you create a VPC or EC2 instance for Hermes.

We are not exploring the AWS console for its own sake. Every step exists because the [Hermes platform design](../part-i-foundations/06-designing-the-hermes-platform.md) depends on it.

:::note[Why this matters for Hermes]

We enable MFA and create a dedicated administrator **before** launching any infrastructure because this AWS account will eventually hold the entire Hermes platform—models under `/opt/models`, PostgreSQL data, Redis queues, and application secrets. A compromised root account could delete volumes, exfiltrate models, or leave you with a surprise bill. Strong account security now protects everything that follows.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Create or access an AWS account dedicated to the Hermes platform
- [ ] Secure the root user with MFA and confirm root is not used for daily work
- [ ] Create an IAM administrator user with MFA for day-to-day operations
- [ ] Configure a billing alarm before provisioning EC2 or storage
- [ ] Install and verify the AWS CLI authenticated as your IAM administrator
- [ ] Explain which Hermes platform components remain unprovisioned—and what comes next

---

## Prerequisites

- [Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md) completed, including Lab 6 platform design worksheet
- Email address and payment method for AWS (credit card; Free Tier may apply to some services)
- Authenticator app (1Password, Authy, Google Authenticator, or hardware key supporting TOTP)
- Lab 1 from [Chapter 1](../part-i-foundations/01-introduction.md): terminal, Git, and code editor ready

**Linux note:** You do not need to finish all of [Chapter 3](../part-i-foundations/03-linux.md) first. This book uses **just-in-time Linux**—you learn commands when the platform needs them. Chapter 7 requires only a working terminal.

---

## Estimated Time

**90 minutes** — 45 minutes reading and walkthrough, 45 minutes for Lab 7.

---

## Background

### Purpose-Driven Provisioning

In [Chapter 6](../part-i-foundations/06-designing-the-hermes-platform.md), you mapped platform components to AWS resources. The first rows in that table are not EC2 or VPC—they are **account, identity, and cost guardrails**.

Without those:

- Anyone with root credentials owns every future resource
- A forgotten GPU instance can run for weeks unnoticed
- You cannot audit who changed security groups or deleted EBS volumes

Experienced operators secure the account **before** the first instance launches. You will follow the same order.

### What AWS Is (Briefly)

Amazon Web Services is a collection of APIs backed by data-center infrastructure. When you "create an EC2 instance," you are calling an API that allocates a virtual machine, attaches network interfaces, and bills your account by the hour.

You do not need to memorize every service name. For the Hermes platform, Part II focuses on a small set:

| Service | Hermes platform role |
|---------|---------------------|
| **IAM** | Who can create and manage resources |
| **VPC** | Private network for your server |
| **EC2** | Ubuntu server running k3s and Hermes stack |
| **EBS / S3** | Model files, databases, backups |
| **Route 53** | DNS for HTTPS access |
| **CloudWatch** | Metrics, logs, billing alarms |

Everything else comes later—or never, if a simpler option serves Hermes.

### The Shared Responsibility Model

AWS secures the **cloud** (physical data centers, hypervisors, core networking). You secure **what you put in the cloud** (OS patches, SSH keys, security groups, IAM policies, encryption choices).

For Hermes, that means:

- AWS keeps the Nitro hypervisor patched
- **You** keep Ubuntu updated, restrict SSH, and scope IAM permissions

Confusing the boundary leads to false confidence—"AWS is secure" does not mean "my Hermes deployment is secure."

---

## Theory

### Root User vs IAM Identities

Every AWS account has exactly one **root user**—the email address used at signup. Root has unrestricted access to everything, including closing the account and changing billing.

**Rule:** Use root only for account-level tasks that require it (initial setup, changing payment method, enabling MFA on root). Never create access keys for root. Never deploy Hermes resources while authenticated as root.

**IAM users and roles** are how daily work should happen. An IAM user is a named identity with credentials and attached policies. A **role** is an identity assumed temporarily—common for EC2 instances and Terraform in CI (covered later).

This chapter creates one IAM user: **`hermes-admin`**—your operator account for building the platform.

### MFA

Multi-factor authentication requires something you know (password) plus something you have (TOTP code from an authenticator app or hardware key).

Enable MFA on:

1. **Root** — non-negotiable
2. **`hermes-admin`** — non-negotiable

If credentials leak, MFA often prevents account takeover.

### Regions and Availability Zones

AWS partitions infrastructure into **regions** (e.g., `us-west-2` in Oregon). Each region contains multiple **Availability Zones** (isolated data centers).

Pick **`us-west-2`** (Oregon) as the Hermes home region and stay consistent in every command, console session, and resource name.

### Billing and Cost Guardrails

The Hermes single-node design from Chapter 6 costs roughly **$250–300/month** on-demand for an `m7i.2xlarge` plus storage. That is manageable for a learning platform—but only if you **notice** when spend spikes.

Before EC2 exists, configure:

1. **Billing preferences** — enable IAM access to billing data (so `hermes-admin` can view costs)
2. **Billing alarm** — CloudWatch alarm when estimated charges exceed a threshold you choose (e.g., $50 while learning, raised later)

This is not optional for a platform you leave running.

---

## Architecture

### Account Structure After This Chapter

```text
AWS Account (Hermes platform)
│
├── Root user
│   ├── MFA enabled
│   └── No access keys; not used for daily ops
│
├── IAM user: hermes-admin
│   ├── AdministratorAccess (temporary; tightened in later chapters)
│   ├── MFA enabled
│   └── Access keys for CLI (stored securely)
│
├── Billing alarm (e.g., $50 threshold)
│
└── (Not yet created)
    ├── VPC
    ├── EC2
    ├── EBS volumes
    └── S3 buckets
```

### What You Are Not Creating Yet

| Resource | Chapter |
|----------|---------|
| VPC, subnets, Internet Gateway | [Chapter 8](08-creating-network-for-hermes.md) |
| EC2 instance | [Chapter 9](09-provisioning-hermes-server.md) |
| Security groups for SSH/HTTPS | [Chapter 9](09-provisioning-hermes-server.md), [Chapter 10](10-establishing-trust.md) |
| EBS volumes, S3 buckets | [Chapter 11](11-persistent-storage.md) |
| Docker, k3s prerequisites | [Chapter 12](12-building-the-application-platform.md) |

Resist launching an EC2 instance from the console today. The next chapters exist so each resource is created in the right order with the right dependencies.

---

## Walkthrough

Complete these steps once. Use a dedicated AWS account for Hermes if possible—separate from production employer accounts.

### Step 1 — Create or Sign In to Your AWS Account

**If you already have an account:** Sign in at [https://console.aws.amazon.com/](https://console.aws.amazon.com/) as root, then skip to Step 2.

**If you need a new account:**

1. Go to [https://aws.amazon.com/](https://aws.amazon.com/) and choose **Create an AWS Account**
2. Enter email, password, and account name (e.g., `hermes-platform-dev`)
3. Complete contact and payment verification
4. Select the **Basic Support** plan (free)

AWS may take a few minutes to activate the account. You will receive a confirmation email when ready.

:::note[Why this matters for Hermes]

A dedicated account isolates Hermes experiments from other workloads. Billing, IAM boundaries, and blast radius stay contained—if you tear down the platform, you do not affect unrelated projects.

:::

### Step 2 — Secure the Root User

1. Sign in as **root**
2. Open **IAM** → **Dashboard**
3. Note any "security recommendations"—you will address them in this chapter
4. Click your **account name** (top right) → **Security credentials**
5. Under **Multi-factor authentication (MFA)**, choose **Assign MFA device**
6. Select **Authenticator app**, follow the QR code setup, enter two consecutive codes
7. Confirm MFA is **Enabled** for root

**Do not** create access keys for the root user. If access keys exist, delete them.

### Step 3 — Enable IAM Access to Billing

Still signed in as root (one of the few tasks that require root):

1. Open **Billing and Cost Management** → **Billing preferences**
2. Enable **IAM user and role access to Billing information**
3. Save preferences

This allows `hermes-admin` to view invoices and set budgets—not strictly required for the alarm in Step 6, but essential for operating Hermes cost-consciously.

### Step 4 — Create the `hermes-admin` IAM User

Remain as root for user creation, or use an existing admin if you already have one.

1. Open **IAM** → **Users** → **Create user**
2. User name: `hermes-admin`
3. Select **Provide user access to the AWS Management Console** → **I want to create an IAM user**
4. Custom password or autogenerated—save it in a password manager
5. Unselect **Users must create a new password at next sign-in** if you prefer (optional)
6. Attach policy: **AdministratorAccess**

:::note[Why this matters for Hermes]

`hermes-admin` is the identity that will create VPCs, EC2 instances, and S3 buckets for Hermes. We start with `AdministratorAccess` to reduce friction while learning. [Chapter 10: Establishing Trust](10-establishing-trust.md) and Part V (Terraform) tighten permissions to least privilege once the platform shape is stable.

:::

7. Create the user
8. Open the new user → **Security credentials**
9. Assign **MFA** (same authenticator app process as root—use a separate entry labeled `hermes-admin`)

### Step 5 — Create Access Keys for the CLI

1. Still on `hermes-admin` → **Security credentials**
2. Under **Access keys**, **Create access key**
3. Use case: **Command Line Interface (CLI)**
4. Confirm the warning, create the key
5. **Download the `.csv` file** or copy Access key ID and Secret access key to your password manager

You will not see the secret again. Never commit keys to Git.

Sign out of root. **From this point forward, use `hermes-admin` for all work** (console and CLI).

### Step 6 — Configure a Billing Alarm

Sign in as **`hermes-admin`**.

1. Confirm region selector shows **US West (Oregon) `us-west-2`**
2. Open **CloudWatch** → **Alarms** → **Create alarm**
3. Choose **Select metric** → **Billing** → **Total Estimated Charge**
4. If no billing metrics appear, wait up to 24 hours after account creation, or enable billing alerts in **Billing** → **Billing preferences** → **Receive Billing Alerts**
5. Set threshold: **Static** → **Greater than** → `50` (USD)—adjust if your budget differs
6. Configure notification: create an **SNS topic** in `us-west-2` (e.g., `hermes-billing-alerts`) and subscribe your email; confirm the subscription from your inbox
7. Alarm name: `hermes-estimated-charges-50usd`
8. Create alarm

When estimated monthly charges exceed $50, you receive email. Raise the threshold after you intentionally launch the full Hermes server.

### Step 7 — Install and Configure the AWS CLI

On your laptop:

**macOS (Homebrew):**

```bash
brew install awscli
```

**Ubuntu / WSL:**

```bash
sudo apt update && sudo apt install -y awscli
```

Verify:

```bash
aws --version
```

Configure a named profile for Hermes:

```bash
aws configure --profile hermes
```

Enter:

- **AWS Access Key ID:** from Step 5
- **AWS Secret Access Key:** from Step 5
- **Default region name:** `us-west-2`
- **Default output format:** `json`

Test authentication:

```bash
aws sts get-caller-identity --profile hermes
```

Expected output includes `"Arn": "arn:aws:iam::ACCOUNT_ID:user/hermes-admin"`.

Optional: set default profile for this project:

```bash
export AWS_PROFILE=hermes
```

Add that line to your shell profile if you want it persistent.

### Step 8 — Record Account Metadata

Create a local notes file (never commit secrets):

```bash
mkdir -p ~/hermes-platform/notes
cat >> ~/hermes-platform/notes/aws-account.md <<'EOF'
# Hermes AWS Account

- Account ID: (from sts get-caller-identity)
- Home region: us-west-2
- Operator IAM user: hermes-admin
- MFA: enabled on root and hermes-admin
- Billing alarm: hermes-estimated-charges-50usd @ $50
EOF
```

Fill in your account ID from the `get-caller-identity` output.

---

## Hands-on Lab

### Lab 7: Provision and Secure Your Hermes AWS Account

**Estimated Time:** 45 minutes

**Goal:** End with MFA-protected root and `hermes-admin`, a billing alarm, and a verified AWS CLI profile—ready for [Chapter 8](08-creating-network-for-hermes.md).

**Prerequisites:** Chapter 6 design worksheet; authenticator app installed

**Steps:**

1. Create or sign in to your AWS account
2. Enable MFA on the root user; confirm no root access keys exist
3. Enable IAM access to billing information (root)
4. Create IAM user `hermes-admin` with `AdministratorAccess` and MFA
5. Create CLI access keys; store in password manager only
6. Sign out of root; sign in as `hermes-admin`
7. Create billing alarm `hermes-estimated-charges-50usd` at $50 with SNS email notification
8. Install AWS CLI; configure profile `hermes`
9. Run `aws sts get-caller-identity --profile hermes` and save account ID to `~/hermes-platform/notes/aws-account.md`
10. Review your [Chapter 6 platform design worksheet](../part-i-foundations/06-designing-the-hermes-platform.md#hands-on-lab)—confirm no VPC or EC2 exists yet

**Verification:**

```bash
aws sts get-caller-identity --profile hermes
```

Output shows `hermes-admin`. In the console, **EC2 → Instances** lists zero instances in `us-west-2`.

**Expected output:**

- Root and `hermes-admin` both show MFA enabled in IAM
- CloudWatch billing alarm exists in `us-west-2`
- CLI returns valid account ID and user ARN

**Troubleshooting:**

| Problem | Cause | Fix |
|---------|-------|-----|
| No billing metrics in CloudWatch | New account or alerts disabled | Enable **Receive Billing Alerts** in Billing preferences; wait up to 24 hours |
| `AccessDenied` on CLI | Wrong keys or profile | Re-run `aws configure --profile hermes`; verify keys belong to `hermes-admin` |
| MFA required on console login | Expected | Enter TOTP from authenticator app |
| Cannot create IAM user | Signed in without admin rights | Sign in as root once to create `hermes-admin` |

**Cleanup:** Do not delete the account or users—you need them for the rest of the book. If you created duplicate test users, delete unused users in IAM.

---

## Verification

Confirm before moving to Chapter 8:

- [ ] Root has MFA; no root access keys
- [ ] `hermes-admin` exists with MFA and `AdministratorAccess`
- [ ] Billing alarm configured with confirmed SNS subscription
- [ ] `aws sts get-caller-identity --profile hermes` succeeds
- [ ] Account ID recorded in local notes
- [ ] Zero EC2 instances in `us-west-2`

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| AWS asks for phone verification repeatedly | Fraud prevention | Complete verification; use consistent billing address |
| Lost MFA device | No backup | Root recovery requires AWS support; store backup codes if offered |
| SNS email not received | Spam filter or unconfirmed subscription | Check spam; confirm subscription link in AWS email |
| `AdministratorAccess` feels too broad | Learning phase tradeoff | Document tightening for Part V; never share keys |

---

## Review Questions

1. Why should you avoid using the root user after initial setup?
2. What is the purpose of the `hermes-admin` IAM user?
3. Why configure a billing alarm before launching EC2?
4. What does `aws sts get-caller-identity` confirm?
5. Which Hermes platform resources are intentionally **not** created in this chapter?
6. What is the shared responsibility model, and who patches the Ubuntu OS on your future EC2 instance?
7. Why does this book use a dedicated AWS profile named `hermes`?

---

## Key Takeaways

- **You are provisioning for Hermes**, not studying AWS abstractly—every step maps to the Chapter 6 design
- **Secure account first:** MFA on root and operator, no root access keys, billing alarm before compute
- **`hermes-admin`** is your daily identity; CLI profile `hermes` connects your laptop to the account
- **Nothing is deployed yet**—no VPC, EC2, or storage until the next chapters, in dependency order
- **Just-in-time Linux** continues—you did not need advanced sysadmin skills to complete this chapter

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Root user** | Original AWS account identity with full control; use only for account-level tasks. |
| **IAM user** | Named identity in your account with credentials and policies (e.g., `hermes-admin`). |
| **MFA** | Multi-factor authentication—password plus TOTP or hardware key. |
| **AWS CLI profile** | Named set of credentials and region defaults (e.g., `--profile hermes`). |
| **Region** | Geographic AWS partition where resources run (e.g., `us-west-2`). |
| **SNS** | Simple Notification Service—delivers billing alarm emails. |

---

## Further Reading

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Creating a billing alarm](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html)
- [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/)
- [Configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

---

## Hermes Platform Status

After completing this chapter, your platform progress looks like this:

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account            ✓
Billing Alerts         ✓
MFA                    ✓
IAM Administrator      ✓

VPC                    ✗
EC2                    ✗
Docker                 ✗
k3s                    ✗
Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

██░░░░░░░░░░░░░░░░░ 10%
───────────────────────────────────────────────
```

Every implementation chapter updates this dashboard. By the end of the book, every line shows ✓ and progress reaches 100%.

---

## What's Next

[Chapter 8: Creating the Network for Hermes](08-creating-network-for-hermes.md) — VPC, subnets, and routing so your server has a place to live.

You secured the account. Next you build the network.

---

[← Chapter 6: Designing the Hermes Platform](../part-i-foundations/06-designing-the-hermes-platform.md) | [Next: Chapter 8 — Creating the Network for Hermes →](08-creating-network-for-hermes.md)
