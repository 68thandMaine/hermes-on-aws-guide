---
sidebar_position: 1
description: "Appendix: glossary."
---

# Glossary

Terms used throughout *Building a Personal AI Cloud*. Terms are added as chapters are written.

| Term | Definition | First Appears |
|------|------------|---------------|
| **vCPU** | Virtual CPU—a core (or portion of a core) allocated to a virtual machine such as an EC2 instance. | Ch 2 |
| **CPU core** | An independent execution unit on a processor; can run one thread at a time per core. | Ch 2 |
| **Hypervisor** | Software that creates and runs virtual machines on physical hardware. | Ch 2 |
| **Machine instruction** | The lowest-level command a CPU executes; all programming languages compile or interpret down to these. | Ch 2 |
| **Process** | A running instance of a program, with its own memory space and OS-managed resources. | Ch 2 |
| **RAM** | Random Access Memory; fast, volatile storage where running programs execute. | Ch 2 |
| **Swap** | Using disk space as overflow when RAM is full; dramatically slower than RAM. | Ch 2 |
| **Thread** | A lightweight execution path within a process; threads share the process's memory. | Ch 2 |
| **Type 1 hypervisor** | Runs directly on hardware (KVM, Nitro, ESXi); used in data centers and EC2. | Ch 5 |
| **Type 2 hypervisor** | Runs as an application on a host OS (VirtualBox, Multipass); used for local development VMs. | Ch 5 |
| **Virtualization** | Running multiple isolated operating systems on one physical machine via a hypervisor. | Ch 2 |
| **Daemon** | Background process without a controlling terminal, often started at boot. | Ch 3 |
| **PID** | Process ID—unique numeric identifier for a running process. | Ch 3 |
| **Signal** | Async notification to a process (e.g. SIGTERM to stop gracefully). | Ch 3 |
| **Unit (systemd)** | Resource systemd manages—typically a `.service` for a daemon. | Ch 3 |
| **sudo** | Command to run a single command as root after authorization check. | Ch 3 |
| **Service account** | Non-human user (e.g. `www-data`, `postgres`) under which daemons run. | Ch 3 |
| **Octal mode** | Three-digit chmod notation (e.g. 755) encoding owner/group/other rwx bits. | Ch 3 |
| **UID** | User ID—numeric identifier the kernel uses for permission checks. | Ch 3 |
| **Distribution (distro)** | Packaged Linux OS—kernel plus tools, package manager, and defaults. | Ch 3 |
| **FHS** | Filesystem Hierarchy Standard—directory layout convention on Linux. | Ch 3 |
| **Kernel** | Core of the OS; manages hardware and enforces permissions via system calls. | Ch 3 |
| **SSH** | Secure Shell—encrypted remote login, typically on port 22. | Ch 3 |
| **systemd** | Init system and service manager; PID 1 on modern Ubuntu. | Ch 3 |
| **system call** | Request from a program to the kernel (read, write, allocate memory). | Ch 3 |
| **Cloud computing** | Delivery of compute, storage, and networking over the internet on a pay-as-you-go basis, without owning physical hardware. | Ch 1 |
| **CloudWatch** | AWS service for metrics, logs, dashboards, and alarms. | Ch 15 |
| **CloudWatch Agent** | Daemon on EC2 that publishes custom host metrics and log files to CloudWatch. | Ch 15 |
| **A record** | DNS record mapping a hostname to an IPv4 address. | Ch 14 |
| **ACM** | AWS Certificate Manager—managed TLS certificates for AWS terminators (ALB, CloudFront). | Ch 14 |
| **cert-manager** | Kubernetes controller that requests and renews TLS certificates (e.g. from Let's Encrypt). | Ch 14 |
| **ClusterIssuer** | Cluster-scoped cert-manager resource defining how to obtain certificates. | Ch 14 |
| **Hosted zone** | DNS container for a domain’s records in Route 53. | Ch 14 |
| **HTTP-01 challenge** | ACME proof of domain control via an HTTP resource on port 80. | Ch 14 |
| **Let's Encrypt** | Free public Certificate Authority with automated short-lived certificates. | Ch 14 |
| **Route 53** | AWS DNS service—hosted zones and records that map names to addresses. | Ch 14 |
| **TLS** | Transport Layer Security—encrypts HTTP as HTTPS. | Ch 14 |
| **AWS Budget** | Billing tool that tracks spend against a monthly limit with configurable alerts. | Ch 16 |
| **Cost Explorer** | AWS console for analyzing historical spend by service, tag, or time range. | Ch 16 |
| **Cost allocation tag** | User-defined tag activated in Billing to appear in cost reports. | Ch 16 |
| **Instance profile** | IAM role attached to an EC2 instance for API access without static access keys. | Ch 15 |
| **Log group** | Container for log streams in CloudWatch Logs (e.g., `/hermes/controlplane`). | Ch 15 |
| **Status check** | EC2 health signal—instance-level or system-level failure detection. | Ch 15 |
| **Control plane** | The tools and environment you use to manage infrastructure (laptop, terminal, Git, Terraform)—distinct from the data plane. | Ch 1 |
| **Data plane** | Where application workloads actually execute—in this book, EC2 instances, containers, and pods in AWS. | Ch 1 |
| **Dev environment** | A configured space for writing and testing code; may be local, remote, or cloud-hosted. | Ch 1 |
| **Infrastructure as Code (IaC)** | Defining servers, networks, and services in version-controlled files rather than manual console clicks. | Ch 1 |
| **Production-inspired** | Architecture mirroring real SaaS patterns (VPC isolation, orchestration, observability) without production SLA guarantees. | Ch 1 |
| **Availability Zone (AZ)** | An isolated location within an AWS region with independent power, networking, and cooling. | Ch 2 |
| **Bare metal** | Physical server hardware without a hypervisor guest layer. | Ch 5 |
| **AMI** | Amazon Machine Image — a template for EC2 instances containing OS and optional software. | Ch 7 |
| **CIDR** | Classless Inter-Domain Routing — notation for IP address ranges (e.g., `10.0.0.0/16`). | Ch 4 |
| **Default route** | Catch-all routing rule (`0.0.0.0/0`) for destinations not matching other entries. | Ch 4 |
| **DNS** | Domain Name System — hierarchical service translating hostnames to IP addresses. | Ch 4 |
| **NAT** | Network Address Translation — rewrites IP addresses at a network boundary (SNAT/DNAT). | Ch 4 |
| **Packet** | Unit of network data with source/destination headers, routed independently. | Ch 4 |
| **Paravirtualization** | Guest OS using hypervisor-aware drivers for faster I/O instead of emulating legacy devices. | Ch 5 |
| **Port** | 16-bit number identifying a service on a host (e.g., 443 for HTTPS). | Ch 4 |
| **TCP** | Transmission Control Protocol — reliable, connection-oriented transport. | Ch 4 |
| **UDP** | User Datagram Protocol — connectionless, best-effort transport. | Ch 4 |
| **CNI** | Container Network Interface — plugin that configures network interfaces for Kubernetes pods. | Ch 11 |
| **ConfigMap** | Kubernetes resource for storing non-sensitive configuration data. | Ch 11 |
| **Container** | A lightweight, isolated process running on a shared kernel, packaged with its dependencies. | Ch 10 |
| **Control Plane** | The Kubernetes components that manage the cluster (API server, etcd, scheduler, controller manager). | Ch 11 |
| **CronJob** | Kubernetes resource that runs Jobs on a schedule. | Ch 19 |
| **Deployment** | Kubernetes resource that manages stateless application replicas with rolling updates. | Ch 11 |
| **EBS** | Elastic Block Store — persistent block storage volumes for EC2 instances. | Ch 5, 9 |
| **EC2** | Elastic Compute Cloud — AWS virtual machine service. | Ch 5, 7 |
| **ENI** | Elastic Network Interface — virtual NIC attached to an EC2 instance in a VPC. | Ch 5 |
| **etcd** | Distributed key-value store used by Kubernetes to store cluster state. | Ch 11 |
| **gp3** | General Purpose SSD EBS volume type with independently configurable IOPS and throughput. | Ch 9 |
| **Guest OS** | Operating system running inside a virtual machine (e.g., Ubuntu on EC2). | Ch 5 |
| **IAM** | Identity and Access Management — AWS service for authentication and authorization. | Ch 6 |
| **IGW** | Internet Gateway — VPC component allowing internet access for public subnets. | Ch 8 |
| **Ingress** | Kubernetes resource defining external access to services, typically via HTTP/HTTPS routes. | Ch 12 |
| **Instance Profile** | IAM role attached to an EC2 instance, providing temporary credentials via STS. | Ch 6 |
| **k3s** | Lightweight Kubernetes distribution by Rancher, designed for edge and resource-constrained environments. | Ch 12 |
| **kubectl** | Command-line tool for interacting with Kubernetes clusters. | Ch 11 |
| **NAT Gateway** | AWS managed service allowing instances in private subnets to reach the internet. | Ch 8 |
| **Nitro** | AWS hypervisor system offloading network, storage, and security to dedicated hardware. | Ch 5, 7 |
| **Node** | A worker machine in Kubernetes (virtual or physical) that runs pods. | Ch 11 |
| **OIDC** | OpenID Connect — authentication protocol used for GitHub Actions → AWS federation. | Ch 14 |
| **Ollama** | *(Not used in this book.)* Desktop-friendly model runner; we use **llama.cpp** directly for explicit GGUF control and Kubernetes-native serving ([Chapter 37](../part-vi-ai/37-model-serving.md)). | — |
| **Oversubscription** | Allocating more virtual resources than physical capacity, relying on average usage patterns. | Ch 5 |
| **PersistentVolumeClaim (PVC)** | Kubernetes request for persistent storage, bound to a PersistentVolume. | Ch 25 |
| **Pod** | The smallest deployable unit in Kubernetes — one or more containers sharing network and storage. | Ch 11 |
| **Quantization** | Reducing model precision (e.g., FP16 → Q4) to decrease size and memory requirements. | Ch 18 |
| **Route Table** | Set of rules determining where network traffic is directed within a VPC. | Ch 8 |
| **S3** | Simple Storage Service — AWS object storage for files, backups, and static assets. | Ch 9 |
| **Security Group** | Stateful virtual firewall controlling inbound and outbound traffic for AWS resources. | Ch 7 |
| **StatefulSet** | Kubernetes resource for stateful applications requiring stable network identity and persistent storage. | Ch 25 |
| **STS** | Security Token Service — AWS service issuing temporary credentials. | Ch 6 |
| **Subnet** | A range of IP addresses within a VPC, tied to a single availability zone. | Ch 8 |
| **Terraform** | Infrastructure as Code tool by HashiCorp using HCL configuration language. | Ch 13 |
| **Traefik** | Open-source reverse proxy and ingress controller, bundled with k3s. | Ch 12 |
| **VPC** | Virtual Private Cloud — isolated network environment within AWS. | Ch 8 |

## Kubernetes operations (Part IV–V)

| Term | Definition | First Appears |
|------|------------|---------------|
| **ClusterRole** | Cluster-scoped RBAC permissions binding. | Ch 28 |
| **ClusterRoleBinding** | Links ClusterRole to users or ServiceAccounts cluster-wide. | Ch 28 |
| **HPA** | Horizontal Pod Autoscaler — scales replicas based on metrics. | Ch 29 |
| **LimitRange** | Namespace default/min/max for Pod resource requests and limits. | Ch 29 |
| **NetworkPolicy** | Kubernetes resource controlling Pod ingress/egress traffic. | Ch 28 |
| **ReplicaSet** | Controller maintaining a set of Pod replicas for a Deployment. | Ch 22 |
| **ResourceQuota** | Namespace cap on aggregate resource consumption. | Ch 29 |
| **Role** | Namespace-scoped RBAC permission set. | Ch 28 |
| **RoleBinding** | Links Role to subjects within a namespace. | Ch 28 |
| **Rolling update** | Incremental Pod replacement to maintain availability during deploys. | Ch 22 |
| **ServiceAccount** | Kubernetes identity assigned to Pods for API and RBAC. | Ch 28 |
| **ServiceMonitor** | Prometheus Operator CRD defining scrape targets. | Ch 33 |
| **StorageClass** | Defines how PVCs are dynamically provisioned. | Ch 25 |

## Platform engineering (Part V)

| Term | Definition | First Appears |
|------|------------|---------------|
| **Alertmanager** | Routes Prometheus alerts to channels and on-call. | Ch 33 |
| **External Secrets Operator (ESO)** | Syncs secrets from cloud stores into Kubernetes. | Ch 32 |
| **ExternalSecret** | ESO CRD mapping remote secret to Kubernetes Secret. | Ch 32 |
| **Grafana** | Dashboards and visualization for metrics and logs. | Ch 33 |
| **LogQL** | Loki query language for log search. | Ch 34 |
| **Loki** | Log aggregation system optimized for Kubernetes. | Ch 34 |
| **PromQL** | Prometheus query language for metrics. | Ch 33 |
| **Prometheus** | Time-series metrics database and alerting engine. | Ch 33 |
| **PrometheusRule** | CRD defining alert and recording rules. | Ch 33 |
| **Secrets Manager** | AWS service for storing and rotating secrets with IAM audit. | Ch 32 |
| **SLO** | Service level objective — measurable reliability target. | Ch 41 |
| **Tempo** | Distributed tracing backend (Grafana stack). | Ch 34 |
| **trace_id** | Correlation ID linking logs, spans, and audit rows. | Ch 34 |

## AI and Hermes (Parts VI–VII)

| Term | Definition | First Appears |
|------|------------|---------------|
| **agent_role** | Task label selecting prompt template and tool allowlist. | Ch 40 |
| **Capability** | Something Hermes can do via a registered tool—not a platform change. | Ch 43 |
| **Coordinator** | Task/worker that decomposes objectives into subtasks. | Ch 40 |
| **Default deny** | Tool policy: reject unless explicitly allowed for the role. | Ch 42 |
| **Distributed cognitive execution** | Multiple reasoning loops coordinated via shared durable state. | Ch 40 |
| **GGUF** | File format for quantized local LLM weights (llama.cpp). | Ch 37 |
| **llama.cpp** | C++ inference engine; runs GGUF models with an HTTP server (`llama-server`). | Ch 37 |
| **llama-server** | Kubernetes Deployment running the llama.cpp HTTP inference server. | Ch 37 |
| **Prompt injection** | Attempt to override instructions via text—defeated by authorization architecture. | Ch 42 |
| **Qdrant** | Vector database for semantic memory and RAG. | Ch 36 |
| **RAG** | Retrieval-augmented generation — context from vector search before inference. | Ch 36 |
| **Reasoning loop** | Hermes task cycle: claim → context → infer → tool → persist. | Ch 39 |
| **root_request_id** | Correlation ID for all tasks in one user objective. | Ch 40 |
| **State Layers** | Intent → API → Scheduler → Containers → Kernel mental model. | Ch 13 |
| **Tool contract** | JSON Schema defining valid tool parameters. | Ch 43 |
| **Tool gateway** | Worker-mediated validate → authorize → execute → audit path. | Ch 42 |
| **Tool registry** | ConfigMap catalog of available tools and metadata. | Ch 43 |

## Adding Terms

When writing chapter content, add new terms to this table with the chapter where they are first defined. Keep definitions concise — one or two sentences.
