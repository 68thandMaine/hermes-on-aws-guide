# Secrets module (Chapter 31+)

IAM policies and (future) Secrets Manager resources for Hermes.

## Lab policy

[`iam-eso-read-policy.json`](iam-eso-read-policy.json) — scoped read for `hermes/*` secrets.

Attach to a dedicated identity:

- **`hermes-eso`** IAM user (k3s lab — credentials in K8s Secret for ESO `secretRef` auth)
- **`hermes-controlplane` instance profile** (production path when controlplane module attaches role)

## CLI

[`../../cli/ch31-create-hermes-api-secret.sh`](../../cli/ch31-create-hermes-api-secret.sh) — create `hermes/api-key` in Secrets Manager.

## Kubernetes sync

Manifests in [`../../../kubernetes/`](../../../kubernetes/):

- `ch31-eso-aws-credentials-secret.example.yaml` — template only; copy locally
- `ch31-cluster-secret-store.yaml`
- `ch31-external-secret-hermes-api.yaml`
- `ch31-external-secret-demo-pod.yaml`

**Never commit real AWS access keys.**
