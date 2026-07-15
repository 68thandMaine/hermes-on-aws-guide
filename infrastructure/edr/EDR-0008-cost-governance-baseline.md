# EDR-0008: Tag-based cost governance baseline for the Hermes lab

| | |
|---|---|
| **Status** | Accepted |
| **Chapter** | 16 — Managing Platform Costs |
| **Date** | 2026-06-30 |

## Context

Chapter 7 configured a **$50 CloudWatch billing alarm** before any compute existed—a tripwire for an empty account. After Chapters 8–15, the Hermes lab runs continuously on `m7i.2xlarge` with ~500 GB of EBS, S3 backups, and CloudWatch ingestion. Baseline spend is **~$290–340/month** on-demand.

Without updated guardrails and tagging, operators face false alarms, cannot attribute spend to Hermes vs other experiments, and discover GPU or snapshot overruns only from invoices.

## Decision

Adopt a **cost governance baseline** for the Hermes lab account:

1. **Raise** the billing alarm to **~$350** estimated monthly charges (operator-tunable).
2. Create an **AWS Budget** `hermes-monthly-lab` at **$400/month** with alerts at 80% actual and 100% forecasted.
3. **Standardize tags** `Project=hermes` and `Environment=lab` on platform resources; **activate** tag keys in Cost allocation tags.
4. Establish a **monthly cost review checklist** (Cost Explorer by service, running instances, snapshot hygiene).
5. Document targets in `~/hermes-platform/notes/cost.env`.

Reserved Instances and Savings Plans remain **out of scope** until usage is stable (revisited in Chapter 44).

## Consequences

**Positive:**

- Guardrails match real platform spend; fewer false-positive $50 alarms
- Cost Explorer can filter Hermes-tagged resources
- Budget forecast alerts catch GPU or duplicate-instance mistakes mid-month
- Habitual review connects technical choices (instance size, snapshots) to dollars

**Negative:**

- Higher alarm thresholds delay detection of *small* anomalies that still matter on tight budgets
- Tag activation lag (~24h) delays first tagged reports
- Budgets and alarms do not stop spend—operator action still required
- Multi-project AWS accounts need discipline to tag every Hermes resource

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Keep $50 alarm forever | Unusable after EC2 provisioning; alarm fatigue or ignored alerts |
| Separate AWS account per project | Best practice at scale; heavier for solo learners—tags suffice for lab |
| Third-party FinOps tool | Overkill for single-node lab |
| Immediate Savings Plan purchase | Instance type and uptime pattern not yet proven |

## References

- [Chapter 16: Managing Platform Costs](../../docs/part-ii-aws/16-managing-platform-costs.md)
- [Appendix: Cost Estimates](../../docs/appendices/cost-estimates.md)
- [AWS Budgets documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
