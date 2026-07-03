-- Wallet lookup
CREATE INDEX idx_wallet_user
ON wallets(user_id);

-- Transaction lookup by wallet
CREATE INDEX idx_transaction_wallet
ON transactions(wallet_id);

-- Because the transactions table contains approximately 50 million rows and remains under continuous write traffic, indexes must be created without blocking inserts or updates.
-- Use PostgreSQL's concurrent index build.
CREATE INDEX CONCURRENTLY idx_transactions_settled
ON transactions
(
    created_at,
    wallet_id,
    currency
)
INCLUDE (amount)
WHERE status = 'SETTLED';

-- Ledger lookup
CREATE INDEX idx_ledger_transaction
ON ledger_entries(transaction_id);

CREATE INDEX idx_ledger_wallet
ON ledger_entries(wallet_id);

-- Audit search
CREATE INDEX idx_audit_record
ON audit_logs(table_name, record_id);

-- Idempotency lookup
CREATE UNIQUE INDEX idx_idempotency_key
ON idempotency_keys(idempotency_key);