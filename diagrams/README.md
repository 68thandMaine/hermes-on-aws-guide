# Diagram Index

Architecture and flow diagrams used throughout the book. Source files live here; chapters reference them with relative links.

## Platform Overview

| Diagram | File | Used In |
|---------|------|---------|
| Full platform stack | `platform-overview.txt` | Preface, Ch 1 |
| End-state architecture | `end-state-architecture.mmd` | Ch 1, Ch 18 |

## AWS Infrastructure

| Diagram | File | Used In |
|---------|------|---------|
| Region and AZ layout | `aws-region-az.txt` | Ch 2 |
| Shared responsibility model | `shared-responsibility.mmd` | Ch 2 |
| VPC with public/private subnets | `vpc-architecture.txt` | Ch 4, Ch 8 |
| IAM policy evaluation flow | `iam-evaluation.mmd` | Ch 6 |
| EC2 + Nitro + EBS | `ec2-nitro-ebs.txt` | Ch 7 |
| EBS vs S3 storage model | `storage-model.txt` | Ch 9 |

## Containers and Kubernetes

| Diagram | File | Used In |
|---------|------|---------|
| Docker on EC2 | `docker-on-ec2.txt` | Ch 10 |
| Kubernetes control plane | `k8s-control-plane.mmd` | Ch 11 |
| k3s node architecture | `k3s-node.txt` | Ch 12 |

## Platform Applications

| Diagram | File | Used In |
|---------|------|---------|
| Hermes request flow | `hermes-request-flow.mmd` | Ch 16 |
| llama.cpp inference stack | `llama-server-stack.txt` | Ch 36 |
| Hermes agent data flow | `hermes-data-pipeline.mmd` | Ch 39 |
| CI/CD pipeline | `cicd-pipeline.mmd` | Ch 14 |
| Monitoring stack | `monitoring-stack.txt` | Ch 15 |

## Conventions

- **`.txt` files** — ASCII art diagrams (render everywhere)
- **`.mmd` files** — Mermaid diagrams (render on GitHub, GitLab, many doc tools)
- When adding a diagram, update this index and reference it from the relevant chapter

## Creating New Diagrams

### ASCII Art

Best for network topology and layered stacks. Keep width under 80 characters for readability in terminal and narrow viewports.

### Mermaid

Best for flows, sequences, and decision trees. GitHub renders Mermaid natively in Markdown fenced code blocks:

````markdown
```mermaid
graph TD
    A --> B
```
````

Or reference a standalone file when the diagram is large or reused across chapters.
