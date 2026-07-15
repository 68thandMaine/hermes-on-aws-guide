# EDR-0009: Public HTTPS entry via Route 53 and Let's Encrypt

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 14 — Routing Traffic to Hermes |
| **Date** | 2026-07-14 |

## Context

[Chapter 10](../../docs/part-ii-aws/10-establishing-trust.md) left TCP **443** closed until Traefik served a real workload. [Chapter 24](../../docs/part-iv-kubernetes/24-ingress.md) proves HTTP Ingress with `/etc/hosts`. Hermes will eventually exchange API tokens and conversation payloads with clients; that traffic should not remain on raw Elastic IPs over cleartext HTTP.

[Chapter 6](../../docs/part-i-foundations/06-designing-the-hermes-platform.md) already chose: Internet → Route 53 → Elastic IP → Traefik (TLS) → Hermes. ACM on an Application Load Balancer would introduce a new AWS front door and ongoing ALB cost that the single-node lab does not need.

## Decision

Adopt a **public HTTPS entrypoint** for the Hermes lab:

1. **Route 53** public hosted zone for the operator-owned domain; **A record** mapping `hermes.<domain>` (or equivalent) to the existing Elastic IP on `hermes-controlplane-01`.
2. **Security Group + UFW** allow **80** and **443** from `0.0.0.0/0` so Let's Encrypt HTTP-01 validators and HTTPS clients can reach Traefik. SSH (22) remains IP-restricted.
3. **cert-manager** with a **Let's Encrypt** `ClusterIssuer` (HTTP-01, Ingress class `traefik`) to issue and renew certificates into a Kubernetes TLS secret.
4. **Traefik** continues to terminate TLS on the node—no Application Load Balancer and no ACM attachment in this phase.
5. Document hostname, zone ID, and issuer names in `~/hermes-platform/notes/routing.env`.

Application-level authentication for Hermes remains a later concern; TLS protects the transport only.

## Consequences

**Positive:**

- Stable public hostname matching the Chapter 6 diagram
- Trusted certificates without paying for ALB
- Certificate renewal automated inside the cluster
- Same Traefik Ingress path Chapter 24 already taught

**Negative:**

- Ports 80/443 are world-reachable—attack surface increases; rely on tight app exposure and closed data-plane ports
- Depends on a registered domain and NS delegation
- Let's Encrypt rate limits punish misconfiguration; use staging while debugging
- HTTP-01 requires port 80 to remain available for renewals

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| ACM + Application Load Balancer | Extra cost and hop; diverges from EIP → Traefik design |
| Self-signed certificates permanently | Browser/client friction; poor habit for agent tokens |
| Cloudflare/other DNS proxy only | Extra vendor; book standardizes on Route 53 in-account |
| Keep `/etc/hosts` + HTTP indefinitely | Acceptable for early labs; not for Hermes client traffic |

## References

- [Chapter 14: Routing Traffic to Hermes](../../docs/part-ii-aws/14-routing-traffic-to-hermes.md)
- [EDR-0003: Key-based SSH](EDR-0003-key-based-ssh.md) — prior trust boundary
- [cert-manager docs](https://cert-manager.io/docs/)
