# EDR-0007: AWS CloudWatch baseline for the control plane host

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 15 — Observing the Hermes Platform |
| **Date** | 2026-06-30 |

## Context

After k3s is installed, operators can SSH to `hermes-controlplane-01` and run `kubectl`, `df`, and `journalctl`. That manual loop does not scale: disk on `/models` or `/data` can fill while Pods still report Running; instance hardware failures may go unnoticed until SSH fails.

The book will add in-cluster observability (Prometheus, Loki) in Part V. Those tools do not replace **host-level** signals—node disk, memory pressure, and EC2 status checks remain AWS concerns.

Chapter 7 established a billing alarm. Chapter 15 extends visibility to the Hermes server itself.

## Decision

Adopt a **CloudWatch baseline** on `hermes-controlplane-01`:

1. **IAM instance profile** with `CloudWatchAgentServerPolicy`—no static access keys on the instance.
2. **CloudWatch Agent** publishing custom metrics to namespace `Hermes/ControlPlane` for disk usage on `/`, `/models`, and `/data`, plus memory utilization.
3. **CloudWatch Logs** log group `/hermes/controlplane` for journald and bootstrap logs.
4. **Alarms** on CPU, `/data` disk usage, and EC2 status check failure, notifying via SNS (`hermes-platform-alerts`).
5. **Dashboard** `hermes-controlplane` for at-a-glance host health.

In-cluster workload monitoring remains deferred to [Chapter 33](../../docs/part-v-infrastructure/33-monitoring.md).

## Consequences

**Positive:**

- Early warning before model or database volumes fill
- Searchable host logs without SSH
- Consistent with billing-alarm pattern readers already configured
- No new application dependencies on the cluster

**Negative:**

- CloudWatch Logs ingestion has per-GB cost—mitigate with 14-day retention and focused log sources
- Custom metrics add minor CloudWatch charges
- Agent must be maintained across OS upgrades
- Does not expose Hermes API latency or Pod-level SLOs

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| SSH-only monitoring | No paging; logs lost if instance is replaced |
| Third-party agent (Datadog, etc.) | Extra cost and account coupling for a learning platform |
| Skip host monitoring until Ch 33 | Prometheus on k3s does not report EBS free space per mount by default |
| Embed AWS access keys in agent config | Security anti-pattern; instance profile is standard |

## References

- [Chapter 15: Observing the Hermes Platform](../../docs/part-ii-aws/15-observing-hermes-platform.md)
- [CloudWatch Agent documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
