# Wallet Payments Relational Core Model

## Overview

This repository contains the solution for the Wallet Payments Database Design assessment.

The solution focuses on designing a production-ready PostgreSQL schema for a fintech wallet/payment platform, optimizing query performance, planning zero-downtime schema migrations, demonstrating polyglot persistence, defining observability practices, and documenting architecture decisions.

The design emphasizes:

- ACID-compliant financial transactions
- Double-entry accounting
- Idempotent payment processing
- Zero-downtime database evolution

---

# Repository Structure

```text
# Repository Structure

```text
REPO_VIETPAY
├── diagrams/
│   ├── ER Diagram.drawio.xml
│   └── ER Diagram.jpg
├── docs/
│   ├── adr.md
│   ├── integrity.md
│   ├── observability.md
│   ├── performance.md
│   ├── polyglot-modeling.md
│   └── zero-downtime-migration.md
├── migrations/
│   ├── 001_users.sql
│   ├── 002_wallets.sql
│   ├── 003_transactions.sql
│   ├── 004_ledger_entries.sql
│   ├── 005_idempotency.sql
│   ├── 006_audit_logs.sql
│   └── 007_indexes.sql
├── notes/
├── schema/
│   └── schema.sql
└── README.md
```

---

# Assessment Deliverables

## Task 1 – Relational Core Model

Deliverables:

- PostgreSQL schema
- Migration scripts
- ER diagram
- Integrity guarantees

Files:

- `schema/schema.sql`
- `migrations/`
- `docs/integrity.md`
- `docs/er-diagram.drawio`
- `diagrams/er-diagram.png`

---

## Task 2 – Query & Performance

Deliverables:

- Optimized settlement query
- Index strategy
- Partitioning strategy
- Performance validation

Files:

- `docs/performance.md`
- `migrations/007_indexes.sql`


---

## Task 3 – Zero-Downtime Migration

Deliverables:

- Expand–Contract migration plan
- Backfill strategy
- Dual-write deployment
- Rollback procedures

Files:

- `docs/zero-downtime-migration.md`



---

## Task 4 – Polyglot Modeling

Deliverables:

- MongoDB document model
- Neo4j graph model
- Design justification

Files:

- `docs/polyglot-modeling.md`



---

## Task 5 – Observability

Deliverables:

- Grafana dashboard design
- SLO definitions
- Alert thresholds

Files:

- `docs/observability.md`



---

## Task 6 – Architecture Decision Record (ADR)

Deliverables:

- Architecture decisions
- Modeling standards
- Consistency model
- Data contract strategy

Files:

- `docs/adr.md`



---

# Database Design Highlights

The schema includes the following core entities:

- Users
- Wallets
- Transactions
- Ledger Entries
- Idempotency Keys
- Audit Logs

Financial correctness is achieved through:

- ACID transactions
- Double-entry accounting
- Immutable ledger entries
- Foreign key constraints
- Unique idempotency keys
- Comprehensive audit logging

---

# Performance Considerations

The solution is designed for a production database containing approximately **50 million transactions** with continued monthly growth.

Performance optimizations include:

- Partial indexes
- Covering indexes
- Composite indexes
- Monthly partitioning
- Index-only scans
- Query plan validation using `EXPLAIN ANALYZE`

---

# Running the Schema

Create the database schema by executing:

```bash
psql -d wallet_db -f schema.sql
```

Alternatively, execute each migration in order:

```text
001_users.sql
002_wallets.sql
003_transactions.sql
004_ledger_entries.sql
005_idempotency.sql
006_audit_logs.sql
007_indexes.sql
```

