# Query Optimization & Performance

## Existing Query

The original settlement reporting query calculates the total settled transaction amount per wallet and currency for a given month.


```sql
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
```

### Execution Plan
```text
 GroupAggregate  (cost=12.81..12.84 rows=1 width=64) (actual time=0.005..0.005 rows=0.00 loops=1)
   Group Key: wallet_id, currency
   ->  Sort  (cost=12.81..12.82 rows=1 width=52) (actual time=0.005..0.005 rows=0.00 loops=1)
         Sort Key: wallet_id, currency
         Sort Method: quicksort  Memory: 25kB
         ->  Seq Scan on transactions  (cost=0.00..12.80 rows=1 width=52) (actual time=0.002..0.002 rows=0.00 loops=1)
               Filter: ((created_at >= '2026-07-01'::date) AND (created_at < '2026-08-01'::date) AND ((status)::text = 'SETTLED'::text))
 Planning:
   Buffers: shared hit=1
 Planning Time: 0.044 ms
 Execution Time: 0.019 ms
```

The query is functionally correct. The primary optimization opportunity lies in reducing the amount of data PostgreSQL must scan.

Characteristics:

* Sequential scan across the full transactions table.
* Millions of rows read.
* High I/O cost.
* Long execution time.

---


Expected improvements include:

* Far fewer rows scanned.
* Reduced buffer reads.
* Lower execution cost.
* Faster execution time.

---

# 1. Wallet Lookup Index

```sql
CREATE INDEX idx_transactions_wallet
ON transactions(wallet_id);
```

Useful for wallet history queries.


---

# 2. Concurrent Reporting Index

Because the transactions table contains approximately 50 million rows and remains under continuous write traffic, indexes must be created without blocking inserts or updates.
Use PostgreSQL's concurrent index build.

```sql
CREATE INDEX CONCURRENTLY idx_transactions_settled
ON transactions
(
    created_at,
    wallet_id,
    currency
)
INCLUDE (amount)
WHERE status = 'SETTLED';
```

This index supports filtering, grouping, and aggregation.

### Execution Plan

```text
GroupAggregate  (cost=8.15..8.18 rows=1 width=64) (actual time=0.036..0.036 rows=0 loops=1)
  Group Key: wallet_id, currency
  Buffers: shared hit=5
  ->  Sort  (cost=8.15..8.16 rows=1 width=52) (actual time=0.035..0.035 rows=0 loops=1)
        Sort Key: wallet_id, currency
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=5
        ->  Index Only Scan using idx_transactions_settled on transactions
              (cost=0.12..8.14 rows=1 width=52)
              (actual time=0.028..0.029 rows=0 loops=1)
              Index Cond:
                (created_at >= '2026-07-01'::date)
                AND
                (created_at < '2026-08-01'::date)
              Heap Fetches: 0
              Index Searches: 1
              Buffers: shared hit=5

Planning:
  Buffers: shared hit=9
Planning Time: 0.164 ms
Execution Time: 0.066 ms
```

---

# 3.Materialized View

A Materialized View (MV) stores the result of a query physically on disk.
Instead of executing SQL every time,
PostgreSQL stores the result.

```sql
CREATE MATERIALIZED VIEW mv_monthly_wallet_settlement AS
SELECT
    date_trunc('month', created_at) AS month,
    wallet_id,
    currency,
    SUM(amount) AS total_amount
FROM transactions
WHERE status='SETTLED'
GROUP BY
    date_trunc('month', created_at),
    wallet_id,
    currency;
```

Query becomes
```sql
SELECT *
FROM mv_monthly_wallet_settlement
WHERE month = DATE '2026-07-01';
```

Instead of scanning 50M rows, PostgreSQL may read only a few hundred or thousand rows.


---

## Refresh

* Materialized Views do not update automatically.

### Refresh manually:

REFRESH MATERIALIZED VIEW mv_monthly_wallet_settlement;

### For production:

* REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_wallet_settlement;

* CONCURRENTLY allows reads during the refresh, but requires a unique index on the materialized view.

Example:
```sql
CREATE UNIQUE INDEX
ON mv_monthly_wallet_settlement
(
    month,
    wallet_id,
    currency
);
```

---

Advantages
* Very easy to build.
* No application changes.
* Fast reporting.
* Excellent for dashboards.
* PostgreSQL maintains storage.

---

Disadvantages
* Data becomes stale until refreshed.
* Refresh can still be expensive on very large datasets.
* Incremental refresh is not built into PostgreSQL (as of PostgreSQL 16).

### Execution Plan

```text
 Seq Scan on mv_monthly_wallet_settlement  (cost=0.00..20.12 rows=4 width=72) (actual time=0.002..0.002 rows=0.00 loops=1)
   Filter: (month = '2026-07-01'::date)
 Planning:
   Buffers: shared hit=18
 Planning Time: 0.045 ms
 Execution Time: 0.009 ms
```

---

# Optimized Query

The SQL query itself does not require changes.

```sql
SELECT
    wallet_id,
    currency,
    SUM(amount) AS total_amount
FROM transactions
WHERE status = 'SETTLED'
  AND created_at >= :month_start
  AND created_at < :month_end
GROUP BY wallet_id, currency;
```

The improvement comes from:

* Covering index (INCLUDE)
* Materialized View

These allow PostgreSQL to access significantly fewer rows while executing the same query.


---

# Cost of the Index

Indexes improve read performance but introduce trade-offs.

## Write Overhead

Each INSERT or UPDATE affecting indexed columns must also update the index.

Expected impact:

* Slightly slower write performance.
* Additional CPU usage during inserts.

Given approximately 2 million new rows per month, this overhead is acceptable because reporting queries are business-critical.


---

## Storage Cost

Indexes require additional disk space.

Estimated size:
* Composite index: approximately 15–30% of table size.
* Materialized View: Instead of scanning 50M rows, PostgreSQL may read only a few hundred or thousand rows.

The partial index is preferred because reporting only targets settled records.


---

# Future Optimizations

For larger datasets (hundreds of millions of rows), consider:

* Materialized views for monthly reports.
* Pre-aggregated summary tables.
* Automatic monthly partition creation.
* Parallel query execution.

These approaches can further reduce reporting latency while maintaining scalability.