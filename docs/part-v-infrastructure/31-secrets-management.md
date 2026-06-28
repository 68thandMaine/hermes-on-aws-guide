---
sidebar_position: 31
description: "Production secret stores — AWS Secrets Manager, External Secrets Operator, and credential boundaries."
---

# Chapter 31: Secrets Management

> Secrets are not data.
>
> Secrets are a control boundary.

---

[Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md) introduced Kubernetes Secrets. [Chapter 30](30-github-actions.md) introduced a **privileged automated actor** that mutates infrastructure with AWS credentials in GitHub Secrets.

You now have:

- GitHub Secrets (CI layer)
- Terraform variables (infrastructure layer)
- Kubernetes Secrets (runtime layer)
- Environment variables (application layer)

That is **four trust boundaries with no central authority**. This chapter fixes that for production Hermes.

```text
Before:  secrets scattered → manual rotation → unknown blast radius
After:   AWS Secrets Manager → sync → Kubernetes → Pods (materialized at runtime)
```

No new mental model—this is **State Layers** applied to credentials: external source of truth, cluster materializes temporarily, workloads consume via refs.

:::note Why this matters for Hermes

Hermes needs model provider keys, tool API credentials, and database passwords. Those cannot live in Git, Helm values, or base64 YAML forever. Automated CI ([Chapter 30](30-github-actions.md)) makes credential leakage more dangerous—not less. External secret management is how the platform stays secure while evolving through merges.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Explain why Kubernetes Secrets alone are insufficient for production
- [ ] Distinguish infrastructure secrets (CI/Terraform) from runtime secrets (Hermes workloads)
- [ ] Store secrets in AWS Secrets Manager and scope IAM read access
- [ ] Install External Secrets Operator (ESO) and sync into the cluster
- [ ] Inject synced secrets into Pods without committing values to Git
- [ ] Describe rotation, revocation, and leakage failure modes

---

## Prerequisites

- [Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md) — ConfigMaps and in-cluster Secrets
- [Chapter 27](../part-iv-kubernetes/27-kubernetes-security.md) — RBAC (who can read Secrets)
- [Chapter 30](30-github-actions.md) — CI credentials in GitHub Secrets
- k3s cluster with `kubectl` access
- AWS CLI profile `hermes` ([Chapter 7](../part-ii-aws/07-provisioning-aws-account.md))
- Helm ([Chapter 25](../part-iv-kubernetes/25-helm.md))

```bash
export KUBECONFIG=~/.kube/hermes-k3s.yaml
export AWS_PROFILE=hermes
kubectl get nodes
helm version
```

---

## Estimated Time

**90 minutes** — 30 minutes reading, 60 minutes AWS + ESO lab.

---

## Background

### The Problem

At this point:

| Layer | Credential example | Risk |
|-------|-------------------|------|
| GitHub Actions | `AWS_ACCESS_KEY_ID` for Terraform | Long-lived CI keys; fork PR exposure |
| Terraform | Variables for DB passwords (future) | State file may capture values |
| Kubernetes | `app-secret` from Ch 26 | Base64 ≠ encryption; etcd exposure |
| Application | `env: API_KEY` | Visible to anyone with Pod exec |

**Automated infrastructure without centralized secret authority does not scale.**

### Why Kubernetes Secrets Are Not Enough

Kubernetes Secrets ([Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md)):

- Are **base64-encoded**, not encrypted by default in etcd
- Are readable by any identity with RBAC `get/list secrets`
- Are **static** unless you manually update and restart Pods
- Have **limited audit trail** compared to cloud secret stores

| Requirement | In-cluster Secret only | External store |
|-------------|------------------------|----------------|
| Rotation | Manual edit + restart | Automated / scheduled |
| Revocation | Delete object; stale Pods may retain | Central disable + sync |
| Auditability | API audit logs | CloudTrail + SM access logs |
| CI vs runtime separation | Weak | Strong domain split |

They remain valid for **lab demos** and **sync targets**—not as the system of record.

### Credential Domains

Separate secrets by **who consumes them**:

```text
Infrastructure secrets          Runtime secrets
─────────────────────          ───────────────
GitHub Secrets (Terraform CI)  AWS Secrets Manager → Hermes Pods
Terraform Cloud / SSM (future)  Per-service scoped IAM
Operator laptop (hermes-admin)  ExternalSecret sync layer
```

Rule:

> **Infrastructure secrets mutate AWS. Runtime secrets mutate application behavior. Never use the same key for both.**

### Production Pattern: External Secret Authority

```text
AWS Secrets Manager (source of truth)
        ↓
External Secrets Operator (sync controller)
        ↓
Kubernetes Secret (materialized cache)
        ↓
Pod / Deployment (env or volume mount)
```

Secrets are **federated, pulled, and materialized at runtime**—not copied into Git.

### Store Options

| System | Hermes use case |
|--------|-----------------|
| **AWS Secrets Manager** | Baseline for this book — rotation, IAM, CloudTrail |
| SSM Parameter Store | Simple key/value; cheaper; less rotation tooling |
| HashiCorp Vault | Full control, dynamic secrets — ops overhead |

This chapter uses **AWS Secrets Manager** on `us-east-1`.

---

## Architecture

### Extended Stack

```text
GitHub Actions
        ↓
Terraform
        ↓
AWS (compute + Secrets Manager + IAM)
        ↓
External Secrets Operator (on k3s)
        ↓
Kubernetes Secret (synced)
        ↓
Hermes workloads
```

### k3s-on-EC2 Auth Reality

On EKS, **IRSA** (IAM Roles for Service Accounts) lets Pods assume IAM roles. On **single-node k3s on EC2**, Pods do **not** automatically inherit the EC2 instance profile.

| Environment | ESO auth pattern |
|-------------|------------------|
| **This book (k3s lab)** | Dedicated `hermes-eso` IAM user → credentials in K8s Secret → ESO `secretRef` |
| **EKS production** | IRSA via `serviceAccountRef` — no long-lived keys in cluster |
| **Future controlplane module** | Instance profile for node-level agents; ESO still prefers IRSA or scoped user |

The lab path is intentional: you learn **least privilege** and **scope** before magic identity wiring hides the boundary.

### Security Model Shift

```text
Before:  Secrets live inside Kubernetes (and GitHub, and Terraform state)
After:   Secrets live in AWS; cluster materializes them temporarily
```

CI credentials ([Chapter 30](30-github-actions.md)) remain in GitHub Secrets for now—[Chapter 31 hardening note](#step-8--harden-ci-credentials-preview): prefer **OIDC federation** over long-lived access keys when Terraform apply runs in production.

---

## Walkthrough

### Step 1 — Create Secret in AWS Secrets Manager

Use the repo script or CLI directly:

```bash
chmod +x infrastructure/aws/cli/ch31-create-hermes-api-secret.sh
SECRET_VALUE="your-lab-key-here" AWS_PROFILE=hermes \
  ./infrastructure/aws/cli/ch31-create-hermes-api-secret.sh
```

Or manually:

```bash
aws secretsmanager create-secret \
  --name hermes/api-key \
  --secret-string "your-lab-key-here" \
  --region us-east-1
```

Verify:

```bash
aws secretsmanager describe-secret --secret-id hermes/api-key --region us-east-1
```

### Step 2 — Create Scoped IAM Identity for ESO

1. IAM → Users → **Create user** → `hermes-eso`
2. Attach inline policy from [`infrastructure/aws/terraform/modules/secrets/iam-eso-read-policy.json`](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/aws/terraform/modules/secrets/iam-eso-read-policy.json):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ],
    "Resource": "arn:aws:secretsmanager:*:*:secret:hermes/*"
  }]
}
```

3. Create access keys for **programmatic use only**
4. Store keys in your password manager—**not** in Git

Do **not** reuse `hermes-admin` or `hermes-terraform-ci` keys.

### Step 3 — Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Verify:

```bash
kubectl get pods -n external-secrets
kubectl get crd externalsecrets.external-secrets.io
```

### Step 4 — Provide ESO AWS Credentials (Lab)

Copy the example and fill locally:

```bash
cp infrastructure/kubernetes/ch31-eso-aws-credentials-secret.example.yaml \
   ~/hermes-platform/local/ch31-eso-aws-credentials-secret.yaml
# Edit placeholders — file stays outside repo
kubectl apply -f ~/hermes-platform/local/ch31-eso-aws-credentials-secret.yaml
```

The example template lives at `infrastructure/kubernetes/ch31-eso-aws-credentials-secret.example.yaml`.

### Step 5 — ClusterSecretStore

```bash
kubectl apply -f infrastructure/kubernetes/ch31-cluster-secret-store.yaml
kubectl get clustersecretstore aws-secrets-manager
```

Status should become **Valid** once credentials and IAM policy are correct.

### Step 6 — ExternalSecret Sync

```bash
kubectl apply -f infrastructure/kubernetes/ch31-external-secret-hermes-api.yaml
kubectl get externalsecret hermes-api-secret
kubectl get secret hermes-api-secret
```

ESO creates/updates the Kubernetes Secret `hermes-api-secret` from `hermes/api-key` in AWS.

Inspect sync status:

```bash
kubectl describe externalsecret hermes-api-secret
```

### Step 7 — Consume in a Pod

```bash
kubectl apply -f infrastructure/kubernetes/ch31-external-secret-demo-pod.yaml
kubectl logs external-secret-demo
```

Expected: non-zero API_KEY length; **value not printed** in logs.

Compare to [Chapter 26](../part-iv-kubernetes/26-configuration-configmaps-secrets.md) `app-secret`—same injection pattern, different **source of truth**.

### Step 8 — Harden CI Credentials (Preview)

[Chapter 30](30-github-actions.md) stores `AWS_ACCESS_KEY_ID` in GitHub Secrets. Production hardening:

- Replace long-lived keys with **GitHub OIDC → AWS IAM role** (no static secret in GitHub)
- Scope Terraform role to infrastructure APIs only—not `secretsmanager:*`
- Keep **runtime** secret reads on `hermes-eso`, not the CI role

Full OIDC wiring lands with the controlplane Terraform module; the **domain separation** is the lesson here.

### Step 9 — Rotation Workflow (Conceptual)

1. Update value in Secrets Manager (`put-secret-value`)
2. ESO refreshes on `refreshInterval` (default 1h in manifest—or trigger reconcile)
3. Restart Pods that do not reload secrets on change (most Deployments need rollout)

```bash
kubectl rollout restart deployment/hermes-api   # future Hermes deployment
```

Revocation: disable secret in AWS or delete IAM policy attachment—sync fails closed; Pods retain last materialized value until restarted and secret removed.

---

## Hands-on Lab

### Lab 31: External Secret Sync

**Estimated Time:** 60 minutes

**Goal:** `hermes/api-key` in AWS → ESO → Kubernetes Secret → Pod env.

**Steps:**

1. Create `hermes/api-key` in Secrets Manager
2. Create `hermes-eso` IAM user with read-only policy on `hermes/*`
3. Install External Secrets Operator via Helm
4. Apply local credentials Secret (from example template)
5. Apply ClusterSecretStore + ExternalSecret
6. Verify `kubectl get secret hermes-api-secret`
7. Run `external-secret-demo` Pod and confirm injection
8. Rotate secret in AWS; wait for refresh; confirm Pod still works after rollout

---

## Verification

- [ ] Secret exists in AWS Secrets Manager (`hermes/api-key`)
- [ ] `hermes-eso` IAM policy scoped to `hermes/*` only
- [ ] ESO pods running in `external-secrets` namespace
- [ ] `ClusterSecretStore` status Valid
- [ ] `ExternalSecret` synced; K8s Secret created
- [ ] Demo Pod receives `API_KEY` without value in Git
- [ ] You can explain infrastructure vs runtime credential domains

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| ClusterSecretStore Invalid | Wrong AWS creds or region | Check `eso-aws-credentials`; region `us-east-1` |
| ExternalSecret SecretSyncedError | IAM deny or missing SM secret | Verify policy; `aws secretsmanager get-secret-value` |
| Empty K8s Secret | Wrong `remoteRef.key` | Must match SM name `hermes/api-key` |
| Pod still has old value | ESO refreshed; Pod not restarted | `kubectl rollout restart` or delete Pod |
| ESO cannot reach AWS | Network egress blocked | SG must allow HTTPS outbound (default on Ch 8 VPC) |

### Failure Modes

**Secret drift** — Manual `kubectl edit secret` while ESO owns it. ESO reconciles back; avoid editing synced Secrets by hand.

**IAM misconfiguration** — `hermes-eso` with `Resource: "*"` or admin policy. Scope to `hermes/*`.

**Cache staleness** — `refreshInterval: 1h` means up to one hour before rotation visible. Lower for labs; use operator-triggered reconcile for emergencies.

**Overexposure** — One `hermes/api-key` shared by every service. Split secrets per integration (`hermes/openweather`, `hermes/postgres`).

**CI leakage** — Terraform logs or fork PRs exposing GitHub Secrets. OIDC + environment protection ([Chapter 30](30-github-actions.md)).

---

## Review Questions

1. Why are Kubernetes Secrets insufficient as the system of record?
2. What is the difference between infrastructure secrets and runtime secrets?
3. Why does k3s-on-EC2 use `secretRef` auth for ESO in this lab?
4. What happens if you rotate a secret in AWS but never restart Pods?
5. Why should CI credentials differ from ESO credentials?

---

## Key Takeaways

- **Secrets are a control boundary**, not configuration data
- **Kubernetes Secrets** are sync targets in production—not the vault
- **AWS Secrets Manager** is the baseline external authority for Hermes
- **External Secrets Operator** federates cloud secrets into the cluster
- **IAM scoping** (`hermes/*`) is part of application design
- **Automated CI** raises the cost of credential mistakes—centralize and separate domains
- Hermes tool keys and provider credentials belong in this layer before Part VI deploy

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Secrets Manager** | AWS service for storing and rotating secrets with IAM and audit. |
| **External Secrets Operator** | Kubernetes controller syncing external stores into cluster Secrets. |
| **ExternalSecret** | CRD declaring which remote secret maps to which K8s Secret. |
| **ClusterSecretStore** | Cluster-scoped config for ESO provider auth (AWS SM). |
| **Materialization** | Creating/updating in-cluster Secret from external source at runtime. |

---

## Further Reading

- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [External Secrets Operator — AWS](https://external-secrets.io/latest/provider/aws-secrets-manager/)
- [Chapter 26: Configuration](../part-iv-kubernetes/26-configuration-configmaps-secrets.md)
- [Chapter 30: GitHub Actions](30-github-actions.md)

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account              ✓
Terraform + CI           ✓
Kubernetes platform      ✓

AWS Secrets Manager      ✓ (lab)
External Secrets sync    ✓
CI OIDC / remote state   ◐ (hardening)

Hermes application       ✗
───────────────────────────────────────────────
```

Part V: codify → automate → **secure**.

---

## What's Next

[Chapter 32: Monitoring](32-monitoring.md) — Prometheus, Grafana, and metrics so the platform can explain itself under load and failure.

---

[← Chapter 30: GitHub Actions](30-github-actions.md) | [Next: Chapter 32 — Monitoring →](32-monitoring.md)
