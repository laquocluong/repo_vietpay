-- Wallet lookup
CREATE INDEX idx_wallet_user
ON wallets(user_id);

-- Transaction lookup by wallet
CREATE INDEX idx_transaction_wallet
ON transactions(wallet_id);

-- Monthly reporting query
-- Should be monthly partitioning of the transactions table by created_at to improve reporting performance and simplify archival.
CREATE INDEX idx_transaction_report
ON transactions(status, created_at, wallet_id, currency);

-- Partial index for settled transactions only
CREATE INDEX idx_transaction_settled
ON transactions(created_at, wallet_id, currency)
WHERE status='SETTLED';

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