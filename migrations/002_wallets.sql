-- 2. Creates the wallets table.
-- One wallet belongs to one user.
-- Support multiple wallets per user.

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
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT chk_wallet_status
        CHECK (status IN ('ACTIVE','LOCKED','CLOSED'))
);


Output:
CREATE TABLE