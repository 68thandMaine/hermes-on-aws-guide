-- Chapter 38 — Hermes durable task model (PostgreSQL)
-- Illustrative schema — production Hermes migrates via application migrations.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS hermes_tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        TEXT NOT NULL,
    objective       TEXT NOT NULL,
    -- Ch 39: distributed cognitive execution
    parent_task_id  UUID REFERENCES hermes_tasks(id),
    root_request_id UUID,
    agent_role      TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','claimed','running','awaiting_tool','completed','failed')),
    priority        INT NOT NULL DEFAULT 0,
    retry_count     INT NOT NULL DEFAULT 0,
    claimed_by      TEXT,
    context_json    JSONB NOT NULL DEFAULT '{}',
    result_json     JSONB,
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_hermes_tasks_status ON hermes_tasks (status, priority DESC, created_at);
CREATE INDEX IF NOT EXISTS idx_hermes_tasks_parent ON hermes_tasks (parent_task_id);
CREATE INDEX IF NOT EXISTS idx_hermes_tasks_root ON hermes_tasks (root_request_id);

-- Tool invocation audit trail (workers mediate — model never calls infra directly)
CREATE TABLE IF NOT EXISTS hermes_task_steps (
    id              BIGSERIAL PRIMARY KEY,
    task_id         UUID NOT NULL REFERENCES hermes_tasks(id) ON DELETE CASCADE,
    step_type       TEXT NOT NULL CHECK (step_type IN ('retrieve','infer','tool','persist')),
    payload_json    JSONB NOT NULL DEFAULT '{}',
    trace_id        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hermes_task_steps_task ON hermes_task_steps (task_id, created_at);
