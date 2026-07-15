# Lab 15 — Host Observability Notes Worksheet

Complete alongside [Chapter 15](../../docs/part-ii-aws/15-observing-hermes-platform.md).

## Instance profile

| Field | Value |
|-------|-------|
| IAM role | `hermes-controlplane-cloudwatch-role` |
| Instance profile | `hermes-controlplane-cloudwatch-profile` |
| Instance ID | |
| Profile attached? | |

## CloudWatch Agent

| Check | Result |
|-------|--------|
| `systemctl is-active amazon-cloudwatch-agent` | |
| Namespace | `Hermes/ControlPlane` |
| Paths monitored | `/`, `/models`, `/data` |
| Memory metric present? | |

## Logs

| Field | Value |
|-------|-------|
| Log group | `/hermes/controlplane` |
| Retention (days) | |
| Journald → CloudWatch working? | |

## Alarms

| Alarm | Metric | Threshold | State |
|-------|--------|-----------|-------|
| `hermes-cpu-high` | | | |
| `hermes-data-disk-low` | | | |
| `hermes-status-failed` | | | |

## SNS

| Field | Value |
|-------|-------|
| Topic | `hermes-platform-alerts` |
| Email subscription confirmed? | |

## Dashboard

| Field | Value |
|-------|-------|
| Name | `hermes-controlplane` |
| Widgets (CPU, disk, …) | |

## Decision check

- [ ] Read EDR-0007
- [ ] No AWS access keys on the instance for CloudWatch
- [ ] `observability.env` saved under `~/hermes-platform/notes/`
