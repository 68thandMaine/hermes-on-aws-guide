# EDR-0003: Key-based SSH authentication; password and root login disabled

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 10 — Establishing Trust |
| **Date** | 2026-06-27 |

## Context

The Hermes platform runs on `hermes-controlplane-01`, a single EC2 instance in a public subnet with an Elastic IP. The host is reachable from the public Internet for remote administration. Automated scanners and credential-stuffing bots continuously probe SSH on all public IPs.

## Decision

Administrative access requires **asymmetric SSH key authentication** (`hermes-controlplane-key`). We disable **password authentication** and **direct root login** in `sshd`. We complement the AWS Security Group (TCP 22 from operator IP only) with **UFW** on the host (default deny incoming, allow 22).

HTTPS (443) remains closed until Traefik serves Hermes; that decision will be recorded in a future EDR.

## Consequences

**Positive:**

- Automated password attacks against SSH become ineffective
- Administrative access is tied to a key pair that never leaves the operator laptop
- Defense in depth: network SG + host UFW + sshd policy
- Decisions are auditable via this EDR series

**Negative:**

- Loss of the private key requires out-of-band recovery (EC2 Instance Connect, replace instance, or attach volume to recovery host)
- Operator IP changes require Security Group updates
- Slightly more operational overhead than "SSH open to the world with a password"

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Password SSH with strong password | Brute-force exposure; secrets rotate poorly |
| Security Group only (no UFW) | Single layer; weaker learning and defense in depth |
| VPN-only access (WireGuard/Tailscale) | Valid for production; added complexity before platform exists |
| AWS Systems Manager Session Manager only | Excellent for prod; book teaches SSH fundamentals first |

## References

- [Chapter 10: Establishing Trust](../../../docs/part-ii-aws/10-establishing-trust.md)
- [OpenSSH best practices](https://www.openssh.com/manual.html)
