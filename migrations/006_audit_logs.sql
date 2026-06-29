-- 6. Audit Trail / Transaction Log History
-- Using JSONB allows storing before/after snapshots without redesigning the schema.
-- Record all important data modifications (only INSERT data).
-- Capture previous and new values.
-- Track the acting user or system process.
-- Support compliance and troubleshooting.

CREATE TABLE audit_logs (

    id BIGSERIAL PRIMARY KEY,

    table_name VARCHAR(100) NOT NULL,

    record_id UUID,

    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE

    old_values JSONB,

    new_values JSONB,

    changed_by VARCHAR(100),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);