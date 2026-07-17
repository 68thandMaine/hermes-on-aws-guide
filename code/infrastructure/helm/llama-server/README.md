# llama.cpp inference server (Chapter 37)

Local **reasoning layer** for Hermes — replaces `hermes-model` stub from [Chapter 35](../hermes-lab/README.md).

## Prerequisites

- GGUF on the k3s node at `/models/model.gguf` ([Chapter 11](../../../../docs/part-ii-aws/11-persistent-storage.md) `hermes-models` volume)
- Sufficient RAM (≥ 4 GiB free for small Q4 models on CPU)

Prepare model (on EC2 via SSH):

```bash
# Example: symlink one GGUF already under /models/qwen/...
sudo ln -sf /models/qwen/your-model.Q4_K_M.gguf /models/model.gguf
ls -lh /models/model.gguf
```

Or run [`../../aws/cli/ch37-prepare-model-lab.sh`](../../aws/cli/ch37-prepare-model-lab.sh) for guided setup notes.

## Install

```bash
helm upgrade --install llama-server code/infrastructure/helm/llama-server \
  -n hermes \
  -f code/infrastructure/helm/llama-server/values.yaml
```

Disable stub model in hermes-lab and point API at llama-server:

```bash
helm upgrade hermes-lab code/infrastructure/helm/hermes-lab -n hermes \
  -f code/infrastructure/helm/hermes-lab/values.yaml \
  -f code/infrastructure/helm/hermes-lab/values-with-llama.yaml
```

## Verify

```bash
./code/infrastructure/aws/cli/ch37-verify-llama-inference.sh
```

## API

Internal only: `http://llama-server:8080/completion` (POST JSON). Workers and Hermes API call this — not exposed via Ingress.

## GPU path (Chapter 38)

Second release on GPU-labeled nodes:

```bash
./code/infrastructure/aws/cli/ch38-gpu-node-prep.sh
kubectl apply -f code/infrastructure/kubernetes/ch38-nvidia-device-plugin.yaml

helm upgrade --install llama-server-gpu code/infrastructure/helm/llama-server \
  -n hermes -f code/infrastructure/helm/llama-server/values-gpu.yaml
```

Dual-path worker wiring:

```bash
helm upgrade hermes-lab code/infrastructure/helm/hermes-lab -n hermes \
  -f code/infrastructure/helm/hermes-lab/values.yaml \
  -f code/infrastructure/helm/hermes-lab/values-with-llama.yaml \
  -f code/infrastructure/helm/hermes-lab/values-dual-inference.yaml
```
