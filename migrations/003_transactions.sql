-- 3. Creates the transactions table.
-- Store payment transaction metadata.
-- Track transaction status.
-- Record transaction type.
-- Transactions cannot be physically deleted.
-- Only SETTLED transactions affect reporting.

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

/*
A common reporting query is slow in production: 
SELECT wallet_id, currency, SUM(amount) FROM transactions
WHERE status = 'SETTLED' AND created_at >= :month_start AND created_at < :month_end
GROUP BY wallet_id, currency; 

=> Solution: create a covering index (status, created_at, wallet_id, currency).

a transactions table that already holds roughly 50 million rows and grows by ~2 million per month.
50M -> 52M -> 54M ->.... 100M
=> Solution: Create Partitioning for each month 2026_01, 2026_02, 2026_03...

*/