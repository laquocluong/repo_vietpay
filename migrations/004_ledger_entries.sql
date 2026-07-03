-- 4. Creates the double-entry accounting ledger.
-- Each financial transaction should generate at least two rows: one DEBIT, one CREDIT
-- Ledger entries are immutable.
-- Link entries to transactions.
-- Ensure every financial movement is represented by balanced ledger entries.

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

Output:
CREATE TABLE