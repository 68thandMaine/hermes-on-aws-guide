-- Chapter 41 — Governance extensions to Hermes durable state
-- Apply after task-schema.example.sql (Chapter 38/39).

-- Human approval queue for privileged tool proposals
CREATE TABLE IF NOT EXISTS hermes_approvals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id         UUID NOT NULL REFERENCES hermes_tasks(id) ON DELETE CASCADE,
    step_id         BIGINT REFERENCES hermes_task_steps(id),
    requester_id    TEXT NOT NULL,
    agent_role      TEXT NOT NULL,
    tool_name       TEXT NOT NULL,
    parameters_json JSONB NOT NULL DEFAULT '{}',
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','approved','rejected','expired')),
    approver_id     TEXT,
    decision_note   TEXT,
    proposed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_at      TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_hermes_approvals_pending
    ON hermes_approvals (status, proposed_at)
    WHERE status = 'pending';

-- Extend step audit with governance fields (illustrative ALTER for greenfield installs)
-- In production, fold these columns into hermes_task_steps at migration time.
COMMENT ON TABLE hermes_task_steps IS
    'Audit trail: each row should capture requester_id, model_version, tool_name, '
    'authorization_decision, trace_id — see Chapter 41.';

-- Example query operators use after an incident:
-- SELECT t.owner_id, t.agent_role, s.step_type, s.payload_json, s.trace_id, s.created_at
-- FROM hermes_task_steps s
-- JOIN hermes_tasks t ON t.id = s.task_id
-- WHERE s.trace_id = $1
-- ORDER BY s.created_at;
