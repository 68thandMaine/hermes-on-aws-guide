# llama.cpp inference server (Chapter 36)

Local **reasoning layer** for Hermes — replaces `hermes-model` stub from [Chapter 34](../hermes-lab/README.md).

## Prerequisites

- GGUF on the k3s node at `/models/model.gguf` ([Chapter 11](../../../docs/part-ii-aws/11-persistent-storage.md) `hermes-models` volume)
- Sufficient RAM (≥ 4 GiB free for small Q4 models on CPU)

Prepare model (on EC2 via SSH):

```bash
# Example: symlink one GGUF already under /models/qwen/...
sudo ln -sf /models/qwen/your-model.Q4_K_M.gguf /models/model.gguf
ls -lh /models/model.gguf
```

Or run [`../../aws/cli/ch36-prepare-model-lab.sh`](../../aws/cli/ch36-prepare-model-lab.sh) for guided setup notes.

## Install

```bash
helm upgrade --install llama-server infrastructure/helm/llama-server \
  -n hermes \
  -f infrastructure/helm/llama-server/values.yaml
```

Disable stub model in hermes-lab and point API at llama-server:

```bash
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml \
  -f infrastructure/helm/hermes-lab/values-with-llama.yaml
```

## Verify

```bash
./infrastructure/aws/cli/ch36-verify-llama-inference.sh
```

## API

Internal only: `http://llama-server:8080/completion` (POST JSON). Workers and Hermes API call this — not exposed via Ingress.

## GPU path (Chapter 37)

Second release on GPU-labeled nodes:

```bash
./infrastructure/aws/cli/ch37-gpu-node-prep.sh
kubectl apply -f infrastructure/kubernetes/ch37-nvidia-device-plugin.yaml

helm upgrade --install llama-server-gpu infrastructure/helm/llama-server \
  -n hermes -f infrastructure/helm/llama-server/values-gpu.yaml
```

Dual-path worker wiring:

```bash
helm upgrade hermes-lab infrastructure/helm/hermes-lab -n hermes \
  -f infrastructure/helm/hermes-lab/values.yaml \
  -f infrastructure/helm/hermes-lab/values-with-llama.yaml \
  -f infrastructure/helm/hermes-lab/values-dual-inference.yaml
```
