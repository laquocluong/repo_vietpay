-- 1.Creates the users table.
-- Store customer information.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";


CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


Output:
CREATE EXTENSION
CREATE TABLE