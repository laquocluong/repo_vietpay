ADR-001: Relational Core Model for Wallet Payments Platform

Date: 2026-07-01

___


Context

The platform processes digital wallet transactions and maintains financial records. The system must guarantee data integrity, prevent duplicate payment processing, support auditing, and scale to tens of millions of transactions.

The database currently contains approximately 50 million transaction records and continues to grow by roughly 2 million records each month.

The solution must support:

Strong financial consistency
High write throughput
Efficient reporting
Zero-downtime schema evolution
Microservice interoperability

___

### Decision 1 – Relational Data Model

### Decision

PostgreSQL is selected as the primary system of record.

The relational model includes:

Users
Wallets
Transactions
Ledger Entries
Idempotency Keys
Audit Logs

Financial operations follow a double-entry accounting model to ensure that every transaction remains balanced.

# Rationale

A relational database provides:

ACID transactions
Foreign key enforcement
Referential integrity
Mature indexing capabilities
Reliable transactional guarantees

These characteristics are essential for financial systems where correctness is more important than eventual consistency.

___






___








___

