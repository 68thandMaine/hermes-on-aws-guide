# Control plane notes (local — do not commit secrets)

After Chapter 9, save to `~/hermes-platform/notes/controlplane.env`:

```bash
export HERMES_INSTANCE_ID=i-xxxxxxxx
export HERMES_PUBLIC_IP=x.x.x.x
export HERMES_SG_ID=sg-xxxxxxxx
export HERMES_KEY_NAME=hermes-controlplane-key
export HERMES_AMI_ID=ami-xxxxxxxx
```

Source before later chapters:

```bash
source ~/hermes-platform/notes/controlplane.env
```

## Verification commands

See [Chapter 9 verification](../../docs/part-ii-aws/09-provisioning-hermes-server.md#verification).
