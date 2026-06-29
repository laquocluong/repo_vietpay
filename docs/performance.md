Query Optimization & Performance
Existing Query

The original settlement reporting query calculates the total settled transaction amount per wallet and currency for a given month.

SELECT
    wallet_id,
    currency,
    SUM(amount) AS total_amount
FROM transactions
WHERE status = 'SETTLED'
  AND created_at >= :month_start
  AND created_at < :month_end
GROUP BY wallet_id, currency;

The query is functionally correct. The primary optimization opportunity lies in reducing the amount of data PostgreSQL must scan.

=================================================================================================
Index Strategy
1. Partial Index

Since reporting only includes settled transactions, a partial index significantly reduces index size.

CREATE INDEX idx_transactions_settled
ON transactions (created_at, wallet_id, currency)
INCLUDE (amount)
WHERE status = 'SETTLED';

Benefits:
- Smaller than a full-table index.
- Faster index scans.
- Less memory consumption.
- Supports Index Only Scan because amount is included.

=================================================================================================
2. Wallet Lookup Index
CREATE INDEX idx_transactions_wallet
ON transactions(wallet_id);

Useful for wallet history queries.

=================================================================================================
3. Composite Reporting Index

If partial indexes are not permitted, a composite index can be used.

CREATE INDEX idx_transactions_reporting
ON transactions
(
    status,
    created_at,
    wallet_id,
    currency
)
INCLUDE (amount);

This index supports filtering, grouping, and aggregation.

=================================================================================================
Partitioning Strategy

The transactions table currently contains approximately 50 million rows and grows by roughly 2 million rows each month.

To improve long-term performance, partition the table by month using the created_at column.

Example:

transactions
│
├── transactions_2026_01
├── transactions_2026_02
├── transactions_2026_03
├── transactions_2026_04
└── ...

Example DDL:

CREATE TABLE transactions
(
    ...
)
PARTITION BY RANGE (created_at);

Monthly partition:

CREATE TABLE transactions_2026_07
PARTITION OF transactions
FOR VALUES FROM ('2026-07-01')
TO ('2026-08-01');

Benefits:
- Partition pruning
- Smaller indexes
- Faster VACUUM operations
- Easier archival
- Better cache utilization

When querying July data, PostgreSQL scans only the July partition instead of the entire table.

=================================================================================================
Optimized Query

The SQL query itself does not require changes.

SELECT
    wallet_id,
    currency,
    SUM(amount) AS total_amount
FROM transactions
WHERE status = 'SETTLED'
  AND created_at >= :month_start
  AND created_at < :month_end
GROUP BY wallet_id, currency;

The improvement comes from:

Partial index
Covering index (INCLUDE)
Monthly partitioning

These allow PostgreSQL to access significantly fewer rows while executing the same query.


=================================================================================================
Validation

Performance improvements should be verified using:

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    wallet_id,
    currency,
    SUM(amount)
FROM transactions
WHERE status = 'SETTLED'
  AND created_at >= DATE '2026-07-01'
  AND created_at < DATE '2026-08-01'
GROUP BY wallet_id, currency;
Expected Improvements
Before Optimization

Typical execution plan:

Seq Scan
    ↓
Hash Aggregate

Characteristics:

Sequential scan across the full transactions table.
Millions of rows read.
High I/O cost.
Long execution time.
After Optimization

Expected execution plan:

Index Only Scan
        ↓
Hash Aggregate



When partitioning is enabled:

Partition Pruning
        ↓
Index Only Scan
        ↓
Hash Aggregate

Expected improvements include:

- Far fewer rows scanned.
- Reduced buffer reads.
- Lower execution cost.
- Faster execution time.

=================================================================================================
Cost of the Index

Indexes improve read performance but introduce trade-offs.

Write Overhead

Each INSERT or UPDATE affecting indexed columns must also update the index.

Expected impact:

Slightly slower write performance.
Additional CPU usage during inserts.

Given approximately 2 million new rows per month, this overhead is acceptable because reporting queries are business-critical.

=================================================================================================
Storage Cost

Indexes require additional disk space.

Estimated size:
- Composite index: approximately 15–30% of table size.
- Partial index: substantially smaller because it only indexes settled transactions.

The partial index is preferred because reporting only targets settled records.

=================================================================================================

Future Optimizations

For larger datasets (hundreds of millions of rows), consider:

- Materialized views for monthly reports.
- Pre-aggregated summary tables.
- Automatic monthly partition creation.
- Parallel query execution.

These approaches can further reduce reporting latency while maintaining scalability.