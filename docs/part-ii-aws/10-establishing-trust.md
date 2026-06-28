---
sidebar_position: 10
description: "Define who may interact with the Hermes platform—trust boundaries, SSH, and defense in depth."
---

# Chapter 10: Establishing Trust

> How do we decide who is allowed to interact with the Hermes platform?

---

SSH is not the subject of this chapter. **Trust** is.

For the first time, your infrastructure lives on the public Internet. Before Kubernetes, before Hermes, before HTTPS APIs—you must define **who and what may cross the boundary** between the untrusted internet and `hermes-controlplane-01`.

This chapter follows **Concept → Design → Implementation**. Commands appear only after you understand authentication, authorization, host identity, and defense in depth.

### The Big Idea

Every system has a trust boundary.

Before Kubernetes…  
Before Hermes…  
Before APIs…  
Before HTTPS…

You define that boundary here.

:::note Why this matters for Hermes

Hermes will hold API keys, model weights, and conversation data. A compromised shell on `hermes-controlplane-01` is game over for the entire platform—not a single misconfigured bucket. Establishing trust now means every later chapter builds on a host whose **identity is verified** and whose **administrative surface is minimal**.

:::

---

## Learning Objectives

After completing this chapter, you will be able to:

- [ ] Define a **trust boundary** and locate each layer for the Hermes platform
- [ ] Distinguish **authentication** (who are you?) from **authorization** (what may you do?)
- [ ] Explain why Security Groups are the first network-line defense—and why they attach to ENIs, not the OS
- [ ] Explain why SSH keys beat passwords and how public/private key pairs relate
- [ ] Describe how SSH encryption and **host keys** prevent man-in-the-middle attacks
- [ ] Explain why **UFW** complements—but does not replace—Security Groups
- [ ] Harden `hermes-controlplane-01` and verify trust controls before installing Docker
- [ ] Describe how HTTPS will be exposed safely in a later chapter

Most objectives are **understanding**, not commands. The implementation section maps each command back to a concept.

---

## Prerequisites

- [Chapter 9: Provisioning the Hermes Server](09-provisioning-hermes-server.md) — `hermes-controlplane-01` running, bootstrap complete
- `~/hermes-platform/notes/controlplane.env` with `HERMES_PUBLIC_IP`, `HERMES_SG_ID`, `HERMES_KEY_NAME`
- SSH access working: `ssh -i ~/.ssh/hermes-controlplane-key.pem ubuntu@$HERMES_PUBLIC_IP`

```bash
export AWS_PROFILE=hermes
export AWS_REGION=us-east-1
source ~/hermes-platform/notes/controlplane.env
```

---

## Estimated Time

**90 minutes** — 45 minutes concept and design, 45 minutes implementation and verification.

---

## Background

### Concept — The Problem

Imagine `hermes-controlplane-01` launched with:

```text
Source: 0.0.0.0/0
All ports: Allowed
```

Within minutes:

- Internet scanners discover the host
- Bots probe SSH, HTTP, and database ports
- Login attempts flood `/var/log/auth.log`
- Automated tools fingerprint the OS

Nothing personal happened. **This is what connecting to the Internet means.**

Security starts by accepting that reality—not by hoping attackers will ignore you.

Chapter 9 applied a **temporary** Security Group rule: SSH from your IP only. This chapter turns that into a **deliberate trust model** with host-level controls, verified identity, and documented decisions.

---

## Theory

### Trust Boundaries

```text
                Internet
        (anything here is untrusted)
════════════════════════════════════

        AWS Security Group
        Who may reach the ENI?

════════════════════════════════════

        Ubuntu (UFW, sshd)
        Who may reach the OS?

════════════════════════════════════

        Hermes / k3s / services
        Who may call APIs?

════════════════════════════════════

        llama.cpp / PostgreSQL / Redis
        (cluster-local — not public)
```

Every layer answers: **Who may cross this boundary?**

### Authentication vs Authorization

People confuse these constantly.

| Term | Question | Hermes platform examples |
|------|----------|--------------------------|
| **Authentication** | Who are you? | SSH key proves you are the operator; AWS IAM proves you are `hermes-admin` |
| **Authorization** | What may you do? | `sudo` grants root on Ubuntu; IAM policies grant EC2 API access; Hermes API tokens grant agent actions |

```text
SSH key pair        →  Authentication (prove identity)
sudo                →  Authorization (elevated actions on host)
AWS IAM             →  Both (identity + policy)
Future Hermes login →  Both (user identity + tool permissions)
```

You will reuse this distinction through Part V (IAM/Terraform) and Part VII (Hermes agent auth).

### SSH — Why It Exists

SSH provides:

- **Encrypted channel** — no plaintext passwords on the wire
- **Identity verification** — keys and host keys
- **Remote shell** — administration without physical access
- **File transfer** — `scp` and `sftp` over the same trust model

It replaced **Telnet** and **rlogin**—protocols that sent credentials and sessions in plaintext. Every production platform uses SSH or something built on the same principles.

### SSH Keys — The Relationship

```text
Your laptop                    hermes-controlplane-01
     │                                  │
 Private key  ─── proves you ───►  Public key
 (never leaves                       (~/.ssh/authorized_keys)
  your laptop)
```

The **private key never leaves your laptop. Ever.**

That single rule prevents most beginner mistakes: no uploading `.pem` files to the server, no committing keys to Git, no sharing keys in Slack.

Chapter 9 created `hermes-controlplane-key`. This chapter verifies the server **rejects** password login and accepts only that key.

### Host Keys — The Server Proves Itself Too

When you first SSH, you may see:

```text
The authenticity of host 'x.x.x.x' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no)?
```

Most tutorials say "type yes." Professionals understand **why**:

- The server presents a **host key**—its cryptographic identity
- Your laptop stores it in `~/.ssh/known_hosts`
- On future connections, SSH alerts if the key changes (possible **man-in-the-middle** attack)

After Elastic IP association or instance rebuild, host keys may change—delete the old entry with `ssh-keygen -R $HERMES_PUBLIC_IP` before reconnecting.

**Verify identity on first connect:** compare fingerprint to `ssh-keygen -lf` on the server if you have out-of-band access, or use AWS Systems Manager Session Manager in production. For this book, accept-on-first-use with awareness is sufficient—document the fingerprint in your notes.

### Security Groups — Network Trust

Security Groups are:

- **Stateful firewalls** — return traffic for allowed connections is automatically permitted
- **Attached to ENIs** (network interfaces)—not inside Ubuntu
- **Allow-rules only** — default deny inbound; you explicitly permit ports

They protect **before packets reach the operating system**. They do not replace OS firewalls—they define the **outer** trust boundary.

For `hermes-controlplane-01` today:

| Port | Source | Purpose |
|------|--------|---------|
| 22 | Your IP `/32` | SSH administration |
| 443 | *Not yet* | HTTPS to Traefik—added when Hermes is served |

PostgreSQL, Redis, and llama.cpp ports stay **closed** at the Security Group—never exposed to `0.0.0.0/0`.

### Why UFW Still Matters

Some AWS engineers say "don't use UFW—the Security Group is enough."

For the Hermes learning platform, **both**:

| Layer | Protects | Scope |
|-------|----------|-------|
| **Security Group** | Network path to the ENI | AWS hypervisor boundary |
| **UFW** | Processes listening on the OS | Ubuntu itself |

**Defense in depth:** a misconfigured SG or a future rule change still faces a host firewall. While learning, UFW makes `ss -tlnp` and deny rules tangible on the machine you operate daily.

UFW does **not** replace Security Groups. It complements them.

### Safely Exposing HTTPS Later

When Traefik serves Hermes:

1. Add Security Group inbound **443** from intended clients (start with your IP; tighten with auth)
2. UFW allow 443/tcp
3. Terminate TLS at Traefik—never send API keys over plain HTTP
4. Keep database and inference ports off both SG and UFW public rules

Document the decision in an EDR before opening 443 in production.

---

## Architecture

### Design — Trust Model for hermes-controlplane-01

```text
Internet (untrusted)
    │
    │  TCP 22 from YOUR_IP/32 only
    ▼
hermes-controlplane-sg (AWS)
    │
    │  UFW: deny incoming default; allow 22
    ▼
sshd: key-only, no root, no passwords
    │
    ▼
ubuntu user → sudo for admin
    │
    ▼
(Hermes stack — future chapters)
```

| Control | Setting |
|---------|---------|
| Security Group | SSH from operator IP only; no 0.0.0.0/0 on 22 |
| sshd | `PasswordAuthentication no`, `PermitRootLogin no`, key auth only |
| UFW | Enabled; default deny incoming; allow 22 |
| Updates | `unattended-upgrades` for security patches |
| Fail2Ban | Optional—see Further Reading |

---

## Walkthrough

### Implementation — Establish Trust on hermes-controlplane-01

Each step maps to a concept above.

#### Step 1 — Audit the Security Group (Authorization at the Network Edge)

Verify only SSH from your IP is permitted:

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')

aws ec2 describe-security-groups \
  --group-ids "$HERMES_SG_ID" \
  --query 'SecurityGroups[0].IpPermissions' \
  --output json
```

Expected: one rule—TCP 22 from `${MY_IP}/32` only. No `0.0.0.0/0`.

If your IP changed since Chapter 9, revoke the old rule and authorize the new one:

```bash
# Example — adjust OLD_IP to your previous address if needed
aws ec2 revoke-security-group-ingress \
  --group-id "$HERMES_SG_ID" \
  --protocol tcp --port 22 --cidr OLD_IP/32 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
  --group-id "$HERMES_SG_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32"
```

#### Step 2 — Record the Host Key (Authentication of the Server)

From your laptop:

```bash
ssh-keygen -R "$HERMES_PUBLIC_IP" 2>/dev/null || true

ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem -o StrictHostKeyChecking=accept-new \
  ubuntu@${HERMES_PUBLIC_IP} 'hostname; cat /etc/ssh/ssh_host_ed25519_key.pub'

# Save fingerprint to notes
ssh-keygen -lf <(ssh-keygen -F ${HERMES_PUBLIC_IP} -f ~/.ssh/known_hosts 2>/dev/null | awk "{print \$2}" ) 2>/dev/null || \
  ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem ubuntu@${HERMES_PUBLIC_IP} \
  'sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'
```

Add to `~/hermes-platform/notes/controlplane.env`:

```bash
# Host key fingerprint verified YYYY-MM-DD
```

#### Step 3 — Harden sshd (Authentication Policy on the Host)

SSH to the server and apply settings:

```bash
ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem ubuntu@${HERMES_PUBLIC_IP}
```

On `hermes-controlplane-01`:

```bash
sudo tee /etc/ssh/sshd_config.d/99-hermes-trust.conf <<'EOF'
# Hermes platform — key-based admin only (Chapter 10)
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
EOF

sudo sshd -t && sudo systemctl reload sshd
```

**Do not close your session** until you verify a second SSH connection works in a new terminal.

#### Step 4 — Enable UFW (OS-Level Trust Boundary)

Still on the server:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH admin'
sudo ufw --force enable
sudo ufw status verbose
```

#### Step 5 — Enable Automatic Security Updates

```bash
sudo apt-get install -y unattended-upgrades apt-listchanges
sudo dpkg-reconfigure -plow unattended-upgrades
# Select Yes when prompted

sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
```

Verify:

```bash
systemctl is-active unattended-upgrades
```

#### Step 6 — Save Server Hardening Script to Infrastructure

On your laptop, the book repo includes a reference script for reproducibility:

```text
infrastructure/aws/cli/ch10-establish-trust-remote.sh
```

Run it after review—it SSHes to the host and applies Steps 3–5.

---

## Hands-on Lab

### Lab 10: Establish Trust on hermes-controlplane-01

**Estimated Time:** 45 minutes

**Goal:** Harden SSH and UFW; verify password login fails and key login succeeds.

**Steps:**

1. Audit Security Group (Walkthrough Step 1)
2. Verify and record host key (Step 2)
3. Apply sshd hardening (Step 3)
4. Enable UFW (Step 4)
5. Enable unattended-upgrades (Step 5)
6. Complete [Verification](#verification) checklist
7. Read [EDR-0003](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0003-key-based-ssh.md)

**Cleanup:** Keep settings in place—this is production baseline for the book.

---

## Verification

Do not end with "it works." Prove each control.

### From Your Laptop

```bash
# Key auth succeeds
ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem ubuntu@${HERMES_PUBLIC_IP} 'echo KEY_AUTH_OK'

# Password auth fails (expect Permission denied — do not use a real password)
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  ubuntu@${HERMES_PUBLIC_IP} 2>&1 | grep -i "Permission denied" && echo PASSWORD_AUTH_BLOCKED

# Root direct login fails
ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem root@${HERMES_PUBLIC_IP} 2>&1 | grep -i "Permission denied" && echo ROOT_LOGIN_BLOCKED
```

### On the Server

```bash
ssh -i ~/.ssh/${HERMES_KEY_NAME}.pem ubuntu@${HERMES_PUBLIC_IP} <<'EOF'
grep -E '^(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication)' /etc/ssh/sshd_config.d/99-hermes-trust.conf
sudo ufw status | grep -E 'Status: active'
ss -tlnp | grep -E ':22 '
test -f /var/lib/hermes-bootstrap-complete && echo CLOUD_INIT_OK
systemctl is-active unattended-upgrades
EOF
```

### AWS Security Group

```bash
aws ec2 describe-security-groups --group-ids "$HERMES_SG_ID" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' --output table
```

No port 443 yet—that is intentional.

### Checklist

- [ ] Password authentication disabled
- [ ] Root login disabled
- [ ] Key authentication succeeds
- [ ] UFW active; only 22 (and established) allowed inbound
- [ ] Security Group exposes only port 22 (from your IP)
- [ ] cloud-init bootstrap still intact
- [ ] Automatic security updates enabled
- [ ] Host key fingerprint recorded in local notes

Only then proceed to [Chapter 11](11-persistent-storage.md).

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Locked out after sshd reload | Syntax error or wrong key | Use EC2 Instance Connect or attach volume to recovery instance; fix `sshd_config.d` |
| SSH timeout after UFW | UFW enabled before allow 22 | EC2 serial console or disable UFW via user-data on replace; always `allow 22` before `enable` |
| IP changed, SSH fails | SG still has old `/32` | Update SG ingress to new `MY_IP/32` |
| Host key warning | Instance rebuilt or new EIP | `ssh-keygen -R $HERMES_PUBLIC_IP`; verify fingerprint before accept |
| `sshd -t` fails | Typo in drop-in | Remove file, reload sshd, reconnect |

---

## Review Questions

1. What is the trust boundary between the Internet and Hermes?
2. How does authentication differ from authorization? Give two examples from this platform.
3. Why must the private SSH key never leave your laptop?
4. What does a changed host key warning mean?
5. Why are Security Groups stateful?
6. Why use UFW if a Security Group already exists?
7. Why is port 443 not open yet?
8. What would fail if password authentication were still enabled?

---

## Key Takeaways

- **Trust, not SSH** — this chapter defines who may interact with the Hermes platform
- **Layers:** Security Group (network) → UFW + sshd (host) → future Hermes auth (application)
- **Authentication vs authorization** — keys prove identity; sudo and IAM grant capability
- **Host keys matter** — verify server identity, not only client identity
- **Defense in depth** — AWS SG + UFW; neither alone is sufficient for learning or operations
- **HTTPS waits** — expose 443 deliberately when Traefik serves Hermes, with an EDR

---

## Glossary Additions

| Term | Definition |
|------|------------|
| **Trust boundary** | Line between trusted and untrusted components; crossing requires explicit permission. |
| **Authentication** | Proving identity (SSH key, IAM user). |
| **Authorization** | Proving permission to act (`sudo`, IAM policy). |
| **Host key** | Server's SSH public key; clients store it to detect impersonation. |
| **ENI** | Elastic Network Interface—where Security Groups attach. |
| **UFW** | Uncomplicated Firewall—host-level netfilter front end on Ubuntu. |
| **Defense in depth** | Multiple independent security layers. |

---

## Further Reading

- [OpenSSH host key verification](https://www.openssh.com/manual.html)
- [AWS Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-groups.html)
- [Ubuntu unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades)
- [Fail2Ban](https://www.fail2ban.org/wiki/index.php/Main_Page) — optional brute-force mitigation (appendix exercise)

---

## Engineering Decision Record

Implementation chapters end with an **Engineering Decision Record (EDR)**—a short document capturing *why* a decision was made. This mirrors Architecture Decision Records (ADRs) used in production teams.

**[EDR-0003: Key-based SSH authentication; password and root login disabled](https://github.com/crudnicky/agent-to-aws-guide/blob/main/infrastructure/edr/EDR-0003-key-based-ssh.md)**

By the end of the book, you will have a documented history of platform decisions—not just resources you clicked into existence.

---

## Hermes Platform Status

```text
───────────────────────────────────────────────
        HERMES PLATFORM STATUS

AWS Account            ✓
Network                ✓
EC2                    ✓
SSH                    ✓
Host Authentication    ✓
Firewall               ✓

Docker                 ✗
k3s                    ✗
Hermes                 ✗
llama.cpp              ✗
PostgreSQL             ✗
Redis                  ✗

Overall Progress

███████░░░░░░░░░░░░░░ 36%
───────────────────────────────────────────────
```

Trust is established. The machine is ready for storage and software layers.

---

## What's Next

[Chapter 11: Persistent Storage for Models and Data](11-persistent-storage.md) — snapshots, backup strategy, and S3 for artifacts that must survive beyond a single disk.

---

[← Chapter 9: Provisioning the Hermes Server](09-provisioning-hermes-server.md) | [Next: Chapter 11 — Persistent Storage for Models and Data →](11-persistent-storage.md)
