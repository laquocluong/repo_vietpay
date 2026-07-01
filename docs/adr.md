# ADR-001: Relational Core Model for Wallet Payments Platform

**Date:** 2026-07-01

---

# Context

The platform processes digital wallet transactions and maintains financial records. The system must guarantee data integrity, prevent duplicate payment processing, support auditing, and scale to tens of millions of transactions.

The database currently contains approximately 50 million transaction records and continues to grow by roughly 2 million records each month.

The solution must support:

* Strong financial consistency
* High write throughput
* Efficient reporting
* Zero-downtime schema evolution
* Microservice interoperability

---

# Decision 1 – Relational Data Model

## Decision

PostgreSQL is selected as the primary system of record.

The relational model includes:

* Users
* Wallets
* Transactions
* Ledger Entries
* Idempotency Keys
* Audit Logs

Financial operations follow a **double-entry accounting** model to ensure that every transaction remains balanced.

## Rationale

A relational database provides:

* ACID transactions
* Foreign key enforcement
* Referential integrity
* Mature indexing capabilities
* Reliable transactional guarantees

These characteristics are essential for financial systems where correctness is more important than eventual consistency.

---

# Decision 2 – Modeling Standards

The following modeling standards are applied throughout the schema.

## Primary Keys

* UUIDs are used for all business entities.
* BIGSERIAL is used only for internal audit log identifiers.

## Naming Convention

* Tables use plural nouns.
* Foreign keys follow the `<entity>_id` convention.
* Constraints and indexes use descriptive names.

Example:

```text
fk_wallet_user
idx_transactions_settled
chk_wallet_status
```

## Data Types

* `UUID` for identifiers.
* `NUMERIC(20,2)` for monetary values.
* `TIMESTAMPTZ` for timestamps.
* `JSONB` only for flexible metadata and audit snapshots.

## Ledger Design

Ledger entries are immutable.

Financial corrections are represented as reversing entries rather than updates or deletions.

---

# Decision 3 – Strong vs Eventual Consistency

## Strong Consistency

The following operations require immediate consistency:

* Wallet balance updates
* Transaction creation
* Ledger entry creation
* Idempotency checks
* Settlement status changes

These operations execute within a single PostgreSQL transaction.

This guarantees:

* Atomicity
* Consistency
* Isolation
* Durability

## Eventual Consistency

The following workloads tolerate eventual consistency:

* Reporting dashboards
* Analytics
* Fraud detection
* Notification delivery
* Search indexes

These services consume events asynchronously and do not affect financial correctness.

---

# Decision 4 – Data Contracts Between Microservices

Communication between microservices is based on explicit versioned data contracts.

Each published event includes:

```json
{
  "eventVersion": 1,
  "eventType": "TransactionSettled",
  "occurredAt": "...",
  "payload": {
    ...
  }
}
```

Consumers validate incoming messages against the published schema before processing.

---

## Versioning Strategy

Schema evolution follows backward-compatible rules.

Allowed changes:

* Add optional fields.
* Introduce new event versions.
* Extend enumerations where consumers can safely ignore unknown values.

Avoid:

* Renaming existing fields.
* Removing required fields.
* Changing field types.
* Reusing event names with different meanings.

Breaking changes require publishing a new event version (for example, `TransactionSettledV2`) while continuing to support the previous version during the migration period.

---

## Schema Validation

Event schemas are maintained in a shared repository.

Example technologies include:

* JSON Schema
* Protocol Buffers (Protobuf)
* Apache Avro

CI/CD pipelines validate producers and consumers against these schemas to detect incompatible changes before deployment.

---

# Decision 5 – Preventing Breaking Changes

To avoid silently breaking downstream services:

* All event schemas are version controlled.
* Contract compatibility is verified during continuous integration.
* Consumer-driven contract tests are executed before deployment.
* Deprecated fields remain available until all consumers have migrated.

This approach enables services to evolve independently while maintaining compatibility.

---

# Decision 6 – Polyglot Persistence

Different databases are selected according to workload characteristics.

| Database   | Responsibility                                          |
| ---------- | ------------------------------------------------------- |
| PostgreSQL | Financial transactions, wallets, ledger, audit metadata |
| MongoDB    | Raw webhook payloads and append-only event storage      |
| Neo4j      | Fraud detection and relationship analysis               |

PostgreSQL remains the authoritative source for financial data.

---

# Consequences

## Benefits

* Strong transactional guarantees for financial operations.
* Clear separation of operational and analytical workloads.
* Safe schema evolution through versioned contracts.
* Scalable architecture that supports future growth.
* Independent deployment of microservices.

## Trade-offs

* Increased operational complexity due to multiple database technologies.
* Additional effort required to maintain event schemas and compatibility.
* Eventual consistency introduces short delays for downstream consumers, although financial correctness is preserved.

---

# Summary

This architecture prioritizes correctness, auditability, and scalability.

Financial operations rely on PostgreSQL's ACID guarantees and an immutable double-entry ledger, while non-critical workloads leverage asynchronous processing and specialized databases. Versioned data contracts and compatibility testing ensure that schema evolution does not silently break dependent microservices, enabling safe, independent service evolution over time.
