# Chapter 9 — CLI reference

Reproducible AWS CLI commands for provisioning `hermes-controlplane-01`.

**Do not commit** private keys or `network-resources.env` with live IDs to public repos.

## Prerequisites

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-east-1
source ~/hermes-platform/notes/network-resources.env
```

## Usage

Run commands in order from [Chapter 9](../../../docs/part-ii-aws/09-provisioning-hermes-server.md#walkthrough), or use the consolidated script after reviewing it:

```bash
# Review before running — updates will land here as the chapter stabilizes
bash infrastructure/aws/cli/ch09-provision-controlplane.sh
```

## Artifacts

| File | Purpose |
|------|---------|
| `../cloud-init/hermes-controlplane-bootstrap.sh` | First-boot user-data |
| `ch09-provision-controlplane.sh` | Full CLI provisioning sequence |
| `../terraform/` | Reserved for Part V — Terraform modules |

Every implementation chapter adds to this tree. Manual steps you run today become Terraform resources later.
