---
sidebar_position: 1
description: "Appendix: labs."
---

# Lab Index

Hands-on labs for every chapter. Each lab includes an estimated time, goal, step-by-step instructions, verification commands, troubleshooting, and cleanup.

## Lab Directory Structure

```
labs/
├── ch03/          # SSH keys and Linux essentials (local)
├── ch04/          # Network diagnostics notes
├── ch06/          # Hermes platform design worksheet
├── ch07/          # AWS account notes (local only)
├── ch08/          # VPC IDs and design notes
├── ch09/          # Control plane env template
├── ch10/          # Dockerfile and docker-compose
├── ch11/          # Kubernetes manifests (minikube)
├── ch12/          # k3s kubeconfig notes
├── ch13/          # Terraform configuration
│   └── terraform/
├── ch15/          # Observability notes
├── ch16/          # Cost / platform notes
├── ch17/          # Docker depth notes
├── ch18/          # Compose stack notes
├── ch19/          # OCI portability notes
├── ch20/          # Why Kubernetes Exists worksheet
└── ch38/          # Hermes agent manifests and platform summary
```

## All Labs

| Lab | Chapter | Title | Time | Status |
|-----|---------|-------|------|--------|
| 1 | 1 | Prepare Your Development Environment | 30 min | 📝 Scaffold |
| 2 | 2 | Explore AWS Global Infrastructure | 20 min | 📝 Scaffold |
| 3 | 3 | Linux Essentials on Your Machine | 45 min | 📝 Scaffold |
| 4 | 4 | Network Diagnostics | 30 min | 📝 Scaffold |
| 6 | 6 | Hermes Platform Design Worksheet | 30 min | ✏️ Draft |
| 7 | 7 | Provision and Secure AWS Account for Hermes | 45 min | ✏️ Draft |
| 8 | 8 | Create the Hermes Network (VPC) | 40 min | ✏️ Draft |
| 9 | 9 | Provision hermes-controlplane-01 | 60 min | ✏️ Draft |
| 10 | 10 | Establish Trust on hermes-controlplane-01 | 45 min | ✏️ Draft |
| 11 | 11 | Persistence, snapshots, S3, restore test | 70 min | ✏️ Draft |
| 12 | 12 | Build application platform (Docker) | 45 min | ✏️ Draft |
| 13 | 13 | First control plane (k3s) | 60 min | ✏️ Draft |
| 14 | 14 | Routing traffic to Hermes | 60 min | ✏️ Draft |
| 15 | 15 | Observing the Hermes Platform | 60 min | ✏️ Draft |
| 16 | 16 | Managing Platform Costs | 45 min | ✏️ Draft |
| 17 | 17 | Docker depth (images, digests, Dockerfile) | 50 min | ✏️ Draft |
| 18 | 18 | Multi-service Compose stack | 45 min | ✏️ Draft |
| 19 | 19 | Prove OCI portability | 25 min | ✏️ Draft |
| 20 | 20 | Why Kubernetes Exists (theory worksheet) | 15 min | ✏️ Draft |

*Part VI — llama.cpp (not Ollama):* Labs 36–37 deploy `llama-server` via Helm; scripts in `infrastructure/aws/cli/ch36-*` and `ch37-*`.

| 36 | 36 | Deploy llama.cpp model server | 120 min | ✏️ Draft |
| 37 | 37 | GPU inference path | 120 min | ✏️ Draft |
| 38 | 38 | Hermes reasoning loop + task schema | 75 min | ✏️ Draft |

**Total estimated lab time:** ~17 hours (excluding reading and troubleshooting)

## Lab Conventions

- Lab assets go in `labs/chXX/` matching the chapter number
- Never commit secrets — use `.env.example` files and Kubernetes Secrets
- Document your actual resource IDs in local files (gitignored via `labs/**/local/`)
- Each lab's verification section must be runnable without modification where possible

## Getting Started

Start with Lab 1 in [Chapter 1](/part-i-foundations/01-introduction). Labs are sequential—skipping a lab means the next chapter assumes knowledge and resources you do not have.
