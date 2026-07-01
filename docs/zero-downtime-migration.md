# Zero-Downtime Migration

## Goal

Add a new column:

```sql
settlement_batch_id UUID NOT NULL
```

to the transactions table without downtime while the application continues serving traffic.

---

# Overview

The migration consists of five phases:

1. Expand
2. Backfill
3. Dual-Write
4. Constraint Validation
5. Contract

Each phase is independently deployable and reversible.

---

# Phase 1 – Expand

## Database Migration
Existing rows are never rewritten during the schema expansion.

Add the new column as nullable.

```sql
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS settlement_batch_id UUID;
```

No existing rows are modified.

No application changes are required.

Application Behavior

Reads: Old schema

Writes: Old schema

Rollback:

```sql
ALTER TABLE transactions
DROP COLUMN IF EXISTS settlement_batch_id;
```

---

# Phase 2 – Backfill

Historical data is updated incrementally in small batches.

Example batch update:

```sql
WITH batch AS (
    SELECT id
    FROM transactions
    WHERE settlement_batch_id IS NULL
    LIMIT 10000
)
UPDATE transactions t
SET settlement_batch_id = gen_random_uuid()
FROM batch
WHERE t.id = batch.id;
```

Repeat until:

```sql
SELECT COUNT(*)
FROM transactions
WHERE settlement_batch_id IS NULL;
```

returns zero.


Application Behavior

Reads: Old schema

Writes: Old schema

Rollback: Stop the backfill job.


---

# Phase 3 – Dual Write
Deploy a new application version.
Old and new application versions can run simultaneously during the dual-write phase.

Every new transaction writes both the old data and the new column.

Example:

```text
INSERT INTO transactions
(
    ...,
    settlement_batch_id
)
VALUES
(
    ...,
    generated_batch_id
);
```

Application Behavior

Reads: Old schema.

Writes: Old schema + new column.

The application continues reading the old representation while ensuring all newly created rows contain settlement_batch_id.

Rollback:
Deploy the previous application version.

The nullable column remains in place.

No database rollback is required.


---

# Phase 4 – Constraint Validation
The NOT NULL constraint is added only after every row has been populated.

Verify that every row has been populated.

```sql
SELECT COUNT(*)
FROM transactions
WHERE settlement_batch_id IS NULL;
```

Expected result: 0

Then promote the constraint.

```sql
ALTER TABLE transactions
ALTER COLUMN settlement_batch_id
SET NOT NULL;
```

At this point, the database guarantees the column is always populated.

Application Behavior

Reads: New schema.

Writes: New schema.

Rollback:

```sql
ALTER TABLE transactions
ALTER COLUMN settlement_batch_id
DROP NOT NULL;
```

---

# Phase 5 – Contract

Remove legacy application logic.

The application now depends entirely on the new column.

Old compatibility code is deleted.

Application Behavior

Reads: New schema only.

Writes: New schema only.

Rollback:
Deploy the previous application version.

Because the column still exists, rollback remains straightforward.


---

# 

Deployment Timeline
Phase	                Database	                Application Reads	Application Writes
Expand	                Add nullable column	        Old	                Old
Backfill	            Populate historical rows	Old	                Old
Dual Write	            No schema changes	        Old	                Old + New
Constraint Promotion	Add NOT NULL	            New	                New
Contract	            Remove legacy logic	        New	                New


---

# Idempotent Migration Scripts

Expand

ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS settlement_batch_id UUID;

Contract rollback

```sql
ALTER TABLE transactions
ALTER COLUMN settlement_batch_id DROP NOT NULL;
```

Column removal (only if migration is completely abandoned)

```sql
ALTER TABLE transactions
DROP COLUMN IF EXISTS settlement_batch_id;
```

---

# Validation

Before promoting the constraint:

```sql
SELECT COUNT(*)
FROM transactions
WHERE settlement_batch_id IS NULL;
```

Expected result:  0

After deployment:

```sql
SELECT COUNT(*)
FROM transactions
WHERE settlement_batch_id IS NULL;
```

should continue returning: 0

Application monitoring should also confirm that all newly inserted transactions include a non-null settlement_batch_id.

