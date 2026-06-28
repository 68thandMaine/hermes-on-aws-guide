# Lab Index

Hands-on labs for every chapter. Each lab includes an estimated time, goal, step-by-step instructions, verification commands, troubleshooting, and cleanup.

## Lab Directory Structure

```
labs/
├── ch03/          # SSH keys and Linux essentials (local)
├── ch04/          # Network diagnostics notes
├── ch08/          # VPC IDs and design notes
├── ch10/          # Dockerfile and docker-compose
├── ch11/          # Kubernetes manifests (minikube)
├── ch12/          # k3s kubeconfig notes
├── ch13/          # Terraform configuration
│   └── terraform/
├── ch15/          # Monitoring notes
├── ch16/          # Hermes Kubernetes manifests
├── ch17/          # Docker Compose lab assets
└── ch38/          # Hermes agent manifests and platform summary
```

## All Labs

| Lab | Chapter | Title | Time | Status |
|-----|---------|-------|------|--------|
| 1 | 1 | Prepare Your Development Environment | 30 min | 📝 Scaffold |
| 2 | 2 | Explore AWS Global Infrastructure | 20 min | 📝 Scaffold |
| 3 | 3 | Linux Essentials on Your Machine | 45 min | 📝 Scaffold |
| 4 | 4 | Network Diagnostics | 30 min | 📝 Scaffold |
| 5 | 5 | Secure Your AWS Account | 45 min | 📝 Scaffold |
| 6 | 6 | Create Your IAM Identity | 45 min | 📝 Scaffold |
| 7 | 7 | Provision Your First EC2 Instance | 45 min | 📝 Scaffold |
| 8 | 8 | Build Your VPC | 60 min | 📝 Scaffold |
| 9 | 9 | EBS and S3 Hands-On | 45 min | 📝 Scaffold |
| 10 | 10 | Docker on EC2 | 60 min | 📝 Scaffold |
| 11 | 11 | Kubernetes with minikube | 60 min | 📝 Scaffold |
| 12 | 12 | Deploy k3s on EC2 | 60 min | 📝 Scaffold |
| 13 | 13 | Rebuild Infrastructure with Terraform | 90 min | 📝 Scaffold |
| 14 | 14 | CI/CD Pipeline for Terraform | 75 min | 📝 Scaffold |
| 15 | 15 | Deploy Prometheus and Grafana | 75 min | 📝 Scaffold |
| 16 | 16 | Deploy Hermes on k3s | 90 min | 📝 Scaffold |

Model serving labs: Chapters 36–37 (`llama-server` Helm chart, not Ollama).
| 38 | 38 | Deploy Hermes Agent + Weather Tool | 120 min | 📝 Scaffold |

**Total estimated lab time:** ~17 hours (excluding reading and troubleshooting)

## Lab Conventions

- Lab assets go in `labs/chXX/` matching the chapter number
- Never commit secrets — use `.env.example` files and Kubernetes Secrets
- Document your actual resource IDs in local files (gitignored via `labs/**/local/`)
- Each lab's verification section must be runnable without modification where possible

## Getting Started

Start with Lab 1 in [Chapter 1](../docs/part-i-foundations/01-introduction.md). Labs are sequential—skipping a lab means the next chapter assumes knowledge and resources you do not have.
