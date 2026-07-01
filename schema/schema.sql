-- =====================================================
-- Wallet Payments Database Schema
-- PostgreSQL 16+
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

----------------------------------------------------------
-- USERS
----------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

----------------------------------------------------------
-- WALLETS
----------------------------------------------------------

CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,

    currency CHAR(3) NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_wallet_user
        FOREIGN KEY(user_id)
        REFERENCES users(id),

    CONSTRAINT chk_wallet_status
        CHECK(status IN ('ACTIVE','LOCKED','CLOSED'))
);

----------------------------------------------------------
-- TRANSACTIONS
----------------------------------------------------------

CREATE TABLE transactions (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    wallet_id UUID NOT NULL,

    transaction_type VARCHAR(30) NOT NULL,

    amount NUMERIC(20,2) NOT NULL,

    currency CHAR(3) NOT NULL,

    status VARCHAR(20) NOT NULL,

    reference VARCHAR(100),

    description TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_transaction_wallet
        FOREIGN KEY(wallet_id)
        REFERENCES wallets(id),

    CONSTRAINT chk_amount
        CHECK(amount > 0),

    CONSTRAINT chk_status
        CHECK(status IN
        (
            'PENDING',
            'SETTLED',
            'FAILED',
            'CANCELLED'
        ))
);

----------------------------------------------------------
-- LEDGER ENTRIES
----------------------------------------------------------

CREATE TABLE ledger_entries (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transaction_id UUID NOT NULL,

    wallet_id UUID NOT NULL,

    entry_type VARCHAR(10) NOT NULL,

    amount NUMERIC(20,2) NOT NULL,

    currency CHAR(3) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_ledger_transaction
        FOREIGN KEY(transaction_id)
        REFERENCES transactions(id),

    CONSTRAINT fk_ledger_wallet
        FOREIGN KEY(wallet_id)
        REFERENCES wallets(id),

    CONSTRAINT chk_entry_type
        CHECK(entry_type IN ('DEBIT','CREDIT')),

    CONSTRAINT chk_ledger_amount
        CHECK(amount > 0)
);

----------------------------------------------------------
-- IDEMPOTENCY KEYS
----------------------------------------------------------

CREATE TABLE idempotency_keys (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    idempotency_key VARCHAR(255) NOT NULL UNIQUE,

    transaction_id UUID NOT NULL UNIQUE,

    request_hash TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_idempotency_transaction
        FOREIGN KEY(transaction_id)
        REFERENCES transactions(id)
);

----------------------------------------------------------
-- AUDIT LOGS
----------------------------------------------------------

CREATE TABLE audit_logs (

    id BIGSERIAL PRIMARY KEY,

    table_name VARCHAR(100) NOT NULL,

    record_id UUID,

    action VARCHAR(20) NOT NULL,

    old_values JSONB,

    new_values JSONB,

    changed_by VARCHAR(100),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

----------------------------------------------------------
-- INDEXES
----------------------------------------------------------

CREATE INDEX idx_wallet_user
ON wallets(user_id);

CREATE INDEX idx_transaction_wallet
ON transactions(wallet_id);

CREATE INDEX idx_transaction_report
ON transactions(status, created_at, wallet_id, currency);

CREATE INDEX idx_transaction_settled
ON transactions(created_at, wallet_id, currency)
WHERE status='SETTLED';

CREATE INDEX idx_ledger_transaction
ON ledger_entries(transaction_id);

CREATE INDEX idx_ledger_wallet
ON ledger_entries(wallet_id);

CREATE UNIQUE INDEX idx_idempotency_key
ON idempotency_keys(idempotency_key);

CREATE INDEX idx_audit_record
ON audit_logs(table_name, record_id);