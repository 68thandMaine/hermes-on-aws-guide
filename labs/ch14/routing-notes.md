# Lab 14 — Routing Notes Worksheet

Complete alongside [Chapter 14](../../docs/part-ii-aws/14-routing-traffic-to-hermes.md).

## Domain

| Field | Value |
|-------|-------|
| Root domain | |
| Hermes hostname | |
| Registrar | |
| Route 53 hosted zone ID | |
| Nameservers (NS) | |

## DNS record

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | | Elastic IP: | 60 |

## Trust boundary (443)

| Control | Setting after lab |
|---------|-------------------|
| Security Group 80 | |
| Security Group 443 | |
| Security Group 22 | (should still be your IP only) |
| UFW 80/443 | |

## TLS

| Field | Value |
|-------|-------|
| ClusterIssuer | `letsencrypt-prod` (or staging while debugging) |
| TLS secret name | |
| Certificate Ready? | |
| `curl -vI https://…` result | |

## Decision check

- [ ] Read EDR-0009 before leaving 80/443 open to the internet
- [ ] Postgres / Redis / llama ports still closed at the Security Group
- [ ] `routing.env` saved under `~/hermes-platform/notes/`
