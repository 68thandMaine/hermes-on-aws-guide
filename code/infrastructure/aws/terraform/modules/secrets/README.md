# Secrets module (Chapter 32+)

IAM policies and (future) Secrets Manager resources for Hermes.

## Lab policy

[`iam-eso-read-policy.json`](iam-eso-read-policy.json) — scoped read for `hermes/*` secrets.

Attach to a dedicated identity:

- **`hermes-eso`** IAM user (k3s lab — credentials in K8s Secret for ESO `secretRef` auth)
- **`hermes-controlplane` instance profile** (production path when controlplane module attaches role)

## CLI

[`../../../cli/ch32-create-hermes-api-secret.sh`](../../../cli/ch32-create-hermes-api-secret.sh) — create `hermes/api-key` in Secrets Manager.

## Kubernetes sync

Manifests in [`../../../../kubernetes/`](../../../../kubernetes/ch32-cluster-secret-store.yaml):

- `ch32-eso-aws-credentials-secret.example.yaml` — template only; copy locally
- `ch32-cluster-secret-store.yaml`
- `ch32-external-secret-hermes-api.yaml`
- `ch32-external-secret-demo-pod.yaml`

**Never commit real AWS access keys.**
