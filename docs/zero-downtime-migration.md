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

# Phase 2 – Dual Write

CRITICAL FIX: This phase must run BEFORE backfilling to trap all new incoming writes so that no new NULL values can be generated.  

Deploy a new application version. Every new transaction written to the system must generate and include a settlement_batch_id.  


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

# Phase 3 – Backfill

Historical data is updated incrementally in small batches.

With Dual-Write active, the number of records where settlement_batch_id IS NULL is now static. We backfill historical data incrementally in safe, low-overhead transaction batches.

CRITICAL FIX: Instead of assigning a unique random UUID to every individual row (which destroys batch semantics), we cluster rows by historical context (e.g., grouping by created_at date boundaries or grouping chunks of 10,000 records into unified semantic batches).  

Example batch update:

```sql
-- Throttled Batch Backfill Script (Run iteratively via migration worker)
DO $$
DECLARE
    v_rows_updated INT;
    v_batch_id UUID;
BEGIN
    LOOP
        -- Generate a SINGLE meaningful UUID per semantic block of 10,000 rows
        v_batch_id := gen_random_uuid();

        WITH target_batch AS (
            SELECT id 
            FROM transactions 
            WHERE settlement_batch_id IS NULL 
            LIMIT 10000
            FOR UPDATE SKIP LOCKED -- Prevent lock contention with operational queries
        )
        UPDATE transactions t
        SET settlement_batch_id = v_batch_id
        FROM target_batch
        WHERE t.id = target_batch.id;

        GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
        COMMIT; -- Release row locks immediately
        
        EXIT WHEN v_rows_updated = 0;
        
        PERFORM pg_sleep(0.5); -- Throttle execution to avoid replication lag spikes
    END LOOP;
END $$;
```



Application Behavior

Reads: Old schema

Writes: Old schema

Rollback: Stop the backfill job.



---

# Phase 4 – Constraint Validation
The NOT NULL constraint is added only after every row has been populated.

CRITICAL FIX: Executing SET NOT NULL on a 50M table enforces an ACCESS EXCLUSIVE lock while Postgres fully scans the table. 
To mitigate this, we employ the CHECK NOT VALID $\rightarrow$ VALIDATE pattern.  


Verify that every row has been populated.

```sql
SELECT COUNT(*)
FROM transactions
WHERE settlement_batch_id IS NULL;
```

Expected result: 0


Step 4.1: Add Constraint as Not Valid
This instantly attaches the constraint definition without scanning the 50 million rows, requiring only a brief metadata lock.

```sql
ALTER TABLE transactions 
ADD CONSTRAINT chk_settlement_batch_id_not_null 
CHECK (settlement_batch_id IS NOT NULL) NOT VALID;
```

Step 4.2: Validate the Constraint Concurrently
PostgreSQL scans the table to verify data integrity using a weak lock (SHARE UPDATE EXCLUSIVE), allowing full, uninterrupted read/write operations from production traffic.

```sql
ALTER TABLE transactions 
VALIDATE CONSTRAINT chk_settlement_batch_id_not_null;
```

Step 4.3: Structural Optimization (Optional but Recommended)
Now that the constraint is fully validated safely, we can formally convert it to a standard column-level property in a quick catalog update.

```sql
ALTER TABLE transactions 
ALTER COLUMN settlement_batch_id SET NOT NULL;

ALTER TABLE transactions 
DROP CONSTRAINT chk_settlement_batch_id_not_null;
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

# Refactored Timeline Verification MATRIX

| Phase | Database Modification | App Reads | App Writes | Lock Profile |
| --- | --- | --- | --- | --- |
| **1. Expand** | Add nullable column

 | Old

 | Old

 | Metadata Only (< 1ms) |
| **2. Dual-Write** | No schema changes

 | Old

 | **Old + New**<br> | None |
| **3. Backfill** | Catch up historical data

 | Old

 | Old + New

 | Row-level only (Throttled) |
| **4. Promotion** | CHECK NOT VALID $\rightarrow$ VALIDATE | New

 | New

 | **Zero Operational Downtime** |
| **5. Contract** | Remove legacy compatibility code | New

 | New

 | None |


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

