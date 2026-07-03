-- 5. Creates the idempotency_keys table.
-- The UNIQUE(idempotency_key) constraint guarantees that the same request cannot create multiple transactions.
-- Prevent duplicate transaction processing.
-- Store client-provided idempotency keys.
-- Map each key to a completed transaction.


CREATE TABLE idempotency_keys (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    idempotency_key VARCHAR(255) NOT NULL UNIQUE,
    -- FIX: transaction_id must be NULLABLE to resolve the concurrency race condition.
    -- The app first locks the idempotency_key atomically, then updates this reference once the transaction is saved.
    transaction_id UUID UNIQUE,

    request_hash TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_idempotency_transaction
        FOREIGN KEY(transaction_id)
        REFERENCES transactions(id)
);