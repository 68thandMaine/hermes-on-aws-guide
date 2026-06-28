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
| **Control plane** | The tools and environment you use to manage infrastructure (laptop, terminal, Git, Terraform)—distinct from the data plane. | Ch 1 |
| **Data plane** | Where application workloads actually execute—in this book, EC2 instances, containers, and pods in AWS. | Ch 1 |
| **Dev environment** | A configured space for writing and testing code; may be local, remote, or cloud-hosted. | Ch 1 |
| **Infrastructure as Code (IaC)** | Defining servers, networks, and services in version-controlled files rather than manual console clicks. | Ch 1 |
| **Production-inspired** | Architecture mirroring real SaaS patterns (VPC isolation, orchestration, observability) without production SLA guarantees. | Ch 1 |
| **Availability Zone (AZ)** | An isolated location within an AWS region with independent power, networking, and cooling. | Ch 2 |
| **AMI** | Amazon Machine Image — a template for EC2 instances containing OS and optional software. | Ch 7 |
| **CIDR** | Classless Inter-Domain Routing — notation for IP address ranges (e.g., `10.0.0.0/16`). | Ch 4 |
| **CNI** | Container Network Interface — plugin that configures network interfaces for Kubernetes pods. | Ch 11 |
| **ConfigMap** | Kubernetes resource for storing non-sensitive configuration data. | Ch 11 |
| **Container** | A lightweight, isolated process running on a shared kernel, packaged with its dependencies. | Ch 10 |
| **Control Plane** | The Kubernetes components that manage the cluster (API server, etcd, scheduler, controller manager). | Ch 11 |
| **CronJob** | Kubernetes resource that runs Jobs on a schedule. | Ch 18 |
| **Deployment** | Kubernetes resource that manages stateless application replicas with rolling updates. | Ch 11 |
| **EBS** | Elastic Block Store — persistent block storage volumes for EC2 instances. | Ch 9 |
| **EC2** | Elastic Compute Cloud — AWS virtual machine service. | Ch 7 |
| **etcd** | Distributed key-value store used by Kubernetes to store cluster state. | Ch 11 |
| **gp3** | General Purpose SSD EBS volume type with independently configurable IOPS and throughput. | Ch 9 |
| **IAM** | Identity and Access Management — AWS service for authentication and authorization. | Ch 6 |
| **IGW** | Internet Gateway — VPC component allowing internet access for public subnets. | Ch 8 |
| **Ingress** | Kubernetes resource defining external access to services, typically via HTTP/HTTPS routes. | Ch 12 |
| **Instance Profile** | IAM role attached to an EC2 instance, providing temporary credentials via STS. | Ch 6 |
| **k3s** | Lightweight Kubernetes distribution by Rancher, designed for edge and resource-constrained environments. | Ch 12 |
| **kubectl** | Command-line tool for interacting with Kubernetes clusters. | Ch 11 |
| **NAT Gateway** | AWS managed service allowing instances in private subnets to reach the internet. | Ch 8 |
| **Nitro** | AWS hypervisor system offloading network, storage, and security to dedicated hardware. | Ch 7 |
| **Node** | A worker machine in Kubernetes (virtual or physical) that runs pods. | Ch 11 |
| **OIDC** | OpenID Connect — authentication protocol used for GitHub Actions → AWS federation. | Ch 14 |
| **Ollama** | *(Not used in this book.)* Desktop model runner; we deploy **llama.cpp** directly ([Chapter 36](docs/part-vi-ai/36-model-serving.md)). | — |
| **PersistentVolumeClaim (PVC)** | Kubernetes request for persistent storage, bound to a PersistentVolume. | Ch 16 |
| **Pod** | The smallest deployable unit in Kubernetes — one or more containers sharing network and storage. | Ch 11 |
| **Quantization** | Reducing model precision (e.g., FP16 → Q4) to decrease size and memory requirements. | Ch 17 |
| **Route Table** | Set of rules determining where network traffic is directed within a VPC. | Ch 8 |
| **S3** | Simple Storage Service — AWS object storage for files, backups, and static assets. | Ch 9 |
| **Security Group** | Stateful virtual firewall controlling inbound and outbound traffic for AWS resources. | Ch 7 |
| **StatefulSet** | Kubernetes resource for stateful applications requiring stable network identity and persistent storage. | Ch 16 |
| **STS** | Security Token Service — AWS service issuing temporary credentials. | Ch 6 |
| **Subnet** | A range of IP addresses within a VPC, tied to a single availability zone. | Ch 8 |
| **Terraform** | Infrastructure as Code tool by HashiCorp using HCL configuration language. | Ch 13 |
| **Traefik** | Open-source reverse proxy and ingress controller, bundled with k3s. | Ch 12 |
| **VPC** | Virtual Private Cloud — isolated network environment within AWS. | Ch 8 |

## Adding Terms

When writing chapter content, add new terms to this table with the chapter where they are first defined. Keep definitions concise — one or two sentences.
