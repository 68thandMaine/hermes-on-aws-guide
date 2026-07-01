---
sidebar_position: 1
description: "Appendix: references."
---

# References

Bibliography and documentation links for *Building a Personal AI Cloud*. Organized by topic.

## Books

| Title | Author | Relevance |
|-------|--------|-----------|
| *Terraform: Up & Running* | Yevgeniy Brikman | Infrastructure as Code (Ch 13) |
| *Kubernetes Up & Running* | Hightower, Burns, Beda | Kubernetes fundamentals (Ch 11) |
| *Docker Deep Dive* | Nigel Poulton | Container internals (Ch 10) |
| *Site Reliability Engineering* | Google | Monitoring and observability (Ch 15) |
| *How Linux Works* | Brian Ward | Linux administration (Ch 3) |
| *Computer Networking: A Top-Down Approach* | Kurose & Ross | Networking fundamentals (Ch 4) |
| *TCP/IP Illustrated* | W. Richard Stevens | Deep networking reference (Ch 4) |
| *The Linux Command Line* | William Shotts | Command-line fluency (Ch 3) |

## AWS Documentation

| Resource | URL | Chapters |
|----------|-----|----------|
| AWS Well-Architected Framework | https://aws.amazon.com/architecture/well-architected/ | 1, all |
| IAM Best Practices | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html | 5, 6 |
| IAM Policy Evaluation Logic | https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html | 6 |
| EC2 User Guide | https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ | 7 |
| AWS Nitro System | https://aws.amazon.com/ec2/nitro/ | 2, 7 |
| VPC User Guide | https://docs.aws.amazon.com/vpc/latest/userguide/ | 4, 8 |
| EBS Volume Types | https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html | 9 |
| S3 User Guide | https://docs.aws.amazon.com/AmazonS3/latest/userguide/ | 9 |
| Shared Responsibility Model | https://aws.amazon.com/compliance/shared-responsibility-model/ | 2 |

## Kubernetes and Containers

| Resource | URL | Chapters |
|----------|-----|----------|
| Kubernetes Documentation | https://kubernetes.io/docs/ | 11, 12 |
| k3s Documentation | https://docs.k3s.io/ | 12 |
| Docker Documentation | https://docs.docker.com/ | 10 |
| Traefik Documentation | https://doc.traefik.io/traefik/ | 12, 16 |
| cert-manager | https://cert-manager.io/docs/ | 16 |

## Infrastructure as Code and CI/CD

| Resource | URL | Chapters |
|----------|-----|----------|
| Terraform Documentation | https://developer.hashicorp.com/terraform/docs | 13 |
| AWS Provider (Terraform) | https://registry.terraform.io/providers/hashicorp/aws/latest/docs | 13 |
| GitHub Actions Documentation | https://docs.github.com/en/actions | 14 |
| GitHub OIDC with AWS | https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services | 14 |

## Monitoring and Observability

| Resource | URL | Chapters |
|----------|-----|----------|
| Prometheus Documentation | https://prometheus.io/docs/ | 15 |
| Grafana Documentation | https://grafana.com/docs/ | 15 |
| OpenTelemetry | https://opentelemetry.io/docs/ | 15 |

## AI and Local Models

| Resource | URL | Chapters |
|----------|-----|----------|
| llama.cpp | https://github.com/ggerganov/llama.cpp | 36–37 |
| llama.cpp server docs | https://github.com/ggerganov/llama.cpp/tree/master/examples/server | 36 |
| Hugging Face Model Hub (GGUF) | https://huggingface.co/models?library=gguf | 36 |

:::note[Not Ollama]

This book deploys **llama.cpp** as a cluster service (`llama-server`), not Ollama. You get explicit GGUF paths, Helm values, and production-style HTTP inference—aligned with [Chapter 36](../part-vi-ai/36-model-serving.md).

:::

## Standards and RFCs

| RFC | Title | Chapters |
|-----|-------|----------|
| RFC 1918 | Address Allocation for Private Internets | 4 |
| RFC 793 | Transmission Control Protocol | 4 |

## Adding References

When writing chapter content, add citations here and link to them from the chapter's References section. Prefer primary documentation over blog posts.
