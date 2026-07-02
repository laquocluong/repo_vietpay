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
    -- FIX: Resolved missing wallet balance column 
    balance NUMERIC(20,2) NOT NULL DEFAULT 0.0000,
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

    -- FIX: Schema rule enforcing DEBIT is strictly positive, CREDIT is strictly negative
    CONSTRAINT chk_ledger_signed_amount
        CHECK(
            (entry_type = 'DEBIT' AND amount > 0) OR 
            (entry_type = 'CREDIT' AND amount < 0)
        )
);

----------------------------------------------------------
-- IDEMPOTENCY KEYS
----------------------------------------------------------

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
-- AUTOMATION & ENFORCEMENT ENGINE (TRIGGERS / FUNCTIONS)
----------------------------------------------------------

-- 1. Double-Entry Verification Engine (Runs on Commit Window)
CREATE OR REPLACE FUNCTION fn_verify_ledger_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_balance_sum NUMERIC(20,4);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_balance_sum
    FROM ledger_entries
    WHERE transaction_id = NEW.transaction_id;

    IF v_balance_sum != 0 THEN
        RAISE EXCEPTION 'Double-entry invariant violation on transaction %: Debits and Credits must balance out to 0 (Current Sum: %).', 
            NEW.transaction_id, v_balance_sum;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- FIX: INITIALLY DEFERRED forces evaluation at the end of the transaction batch
CREATE CONSTRAINT TRIGGER trg_enforce_double_entry
AFTER INSERT OR UPDATE ON ledger_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_verify_ledger_balance();


-- 2. Ledger Immutability Lock Guard
CREATE OR REPLACE FUNCTION fn_enforce_ledger_immutability()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Data Integrity Violation: Ledger entries are append-only. Mutation or deletion is strictly blocked.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_ledger_history
BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW
EXECUTE FUNCTION fn_enforce_ledger_immutability();


-- 3. Dynamic Audit Trail Trigger Engine
CREATE OR REPLACE FUNCTION fn_generic_audit_logger()
RETURNS TRIGGER AS $$
DECLARE
    v_old JSONB := NULL;
    v_new JSONB := NULL;
    v_id UUID;
BEGIN
    IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
        v_old := to_jsonb(OLD);
        v_id := OLD.id;
    END IF;
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        v_new := to_jsonb(NEW);
        v_id := NEW.id;
    END IF;

    INSERT INTO audit_logs (table_name, record_id, action, old_values, new_values)
    VALUES (TG_TABLE_NAME, v_id, TG_OP, v_old, v_new);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Wire up the tables to the audit engine
CREATE TRIGGER trg_audit_wallets AFTER INSERT OR UPDATE OR DELETE ON wallets FOR EACH ROW EXECUTE FUNCTION fn_generic_audit_logger();
CREATE TRIGGER trg_audit_transactions AFTER INSERT OR UPDATE OR DELETE ON transactions FOR EACH ROW EXECUTE FUNCTION fn_generic_audit_logger();

----------------------------------------------------------
-- INDEXES
----------------------------------------------------------

CREATE INDEX idx_wallet_user
ON wallets(user_id);

CREATE INDEX idx_transaction_wallet
ON transactions(wallet_id);


-- FIX: Merged the overlapping partial indexes. 
-- Included 'amount' to ensure Index-Only Scans can run without fetching raw heap tables.
CREATE INDEX idx_transactions_settled_reporting
ON transactions(created_at, wallet_id, currency)
INCLUDE (amount)
WHERE status = 'SETTLED';


CREATE INDEX idx_ledger_transaction
ON ledger_entries(transaction_id);

CREATE INDEX idx_ledger_wallet
ON ledger_entries(wallet_id);

CREATE UNIQUE INDEX idx_idempotency_key
ON idempotency_keys(idempotency_key);

CREATE INDEX idx_audit_record
ON audit_logs(table_name, record_id);