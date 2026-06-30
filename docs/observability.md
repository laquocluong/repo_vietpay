Observability

Overview

A payment platform requires comprehensive monitoring to ensure financial transactions are processed reliably, settlement deadlines are met, and database performance remains stable under increasing load.

The monitoring strategy combines infrastructure metrics, database metrics, and business-level metrics into a Grafana dashboard, with alerts configured to notify operators before service degradation affects customers.


Service Level Objectives (SLOs)
Category	                SLO
Transaction API Latency	    95% of requests complete within 200 ms
Settlement Query Latency	95% complete within 2 seconds
Database Availability	    99.95% monthly uptime
Replication Lag	Less than   5 seconds
Settlement Processing	    99% of transactions settled within 5 minutes
Failed Transaction Rate	    Less than 0.1%
Database Lock Wait	        Less than 500 ms


================================================================
Grafana Dashboard
1. Query Latency

Metrics

Average query latency:  the average response time of all query statements.
P95 query latency:      95% of a query statements response time faster than this value.
P99 query latency:      99% of a query statements response time faster than this value.
Slow query count:       The total number of statements whose execution time exceeds a specified threshold.

Purpose

Detect inefficient SQL queries, missing indexes, or unexpected load.

================================================================
2. Throughput

Metrics

Transactions per second (TPS)
Inserts per second
Reads per second
Updates per second

Purpose

Measure system load and identify traffic spikes.

================================================================
3. Replication Lag

Metrics

Replica replay delay:   the delay time on Replica
WAL replay delay:       WAL log file processing latency
WAL generation rate:    The amount of log data (in MB/second).

Purpose

Ensure read replicas remain synchronized with the primary database.

Large replication lag can result in stale reporting data.

================================================================
4. Lock Contention

Metrics

Lock wait time
Number of blocked sessions
Deadlock count
Long-running transactions

Purpose

Identify blocking operations that may delay payment processing.

================================================================
5. Settlement Lag

Business Metrics

Pending settlements
Average settlement time
Maximum settlement time
Settlement success rate

Purpose

Monitor whether financial settlements are being completed within expected timeframes.

This is one of the most important business health indicators.

================================================================
6. Capacity

Metrics:

Database size
Table growth
Index growth
Disk usage
Free storage
Connection pool utilization
Active connections
CPU usage
Memory usage

Purpose:

Forecast capacity needs and avoid resource exhaustion.

================================================================
7. Alerting Strategy

Critical Alerts: Database Unavailable

Condition:  Database unavailable for >30 seconds

Severity:   Critical

Reason:     Payment processing cannot continue.

================================================================
8. Replication Lag

Condition:  Replication lag >10 seconds

Severity:   Critical

Reason:     Reporting data becomes stale, and failover may result in data loss.

================================================================
9. Settlement Lag

Condition:  Average settlement time >5 minutes

Severity:   Critical

Reason:     Delayed settlements directly impact customers and may violate financial service commitments.

================================================================
10. Deadlocks

Condition: Deadlocks > 5 within 5 minutes

Severity:  Critical

Reason:    Frequent deadlocks indicate application or transaction design issues that can block payment processing.

================================================================
11. Warning Alerts
Slow Queries

Condition:  P95 query latency >500 ms for 10 minutes

Reason:     May indicate missing indexes, poor execution plans, or increasing database load.


================================================================
12. Connection Pool

Condition:  Connection pool utilization >80%

Reason:     The application is approaching the database connection limit.

================================================================
13. Table Growth

Condition:  Transactions table exceeds expected monthly growth by 20%

Reason:     Unexpected growth may indicate increased business activity or duplicate event ingestion.

================================================================
14. Disk Usage

Condition:  Disk utilization >80%

Severity:   Warning

At 90%

Severity:   Critical

Reason:     Low disk space can cause write failures and database outages.
================================================================
15. WAL Generation

Condition:  WAL generation rate doubles expected baseline

Reason:     May indicate excessive updates, bulk operations, or abnormal workloads.

================================================================
16. Business KPIs

In addition to infrastructure metrics, the dashboard should include key business indicators.

Metrics

Payments processed per minute
Settlement success rate
Failed payment percentage
Average payment amount
Active wallets
Daily transaction volume
Monthly settlement volume

These metrics help distinguish between technical failures and business-related issues.

================================================================
17. Dashboard Layout
Overview
System health
Database availability
Active alerts

================================================================
18. Performance
Query latency
TPS- Transactions Per Second
Slow queries
Buffer cache hit ratio


================================================================
19. Database Health
Lock contention
Deadlocks
Active sessions
Replication lag

================================================================
20. Capacity
Database size
Disk usage
CPU
Memory
Connection pool

================================================================
21. Business Metrics
Settlement lag
Payment success rate
Pending settlements
Daily transaction volume



================================================================
Conclusion

The observability strategy combines technical monitoring with business metrics to provide complete visibility into the payment platform.

Technical metrics ensure the database remains healthy and performant, while business metrics verify that customers receive timely payment processing and settlements.

By monitoring both dimensions, operators can detect performance regressions early, respond quickly to incidents, and maintain the reliability expected of a production-grade fintech platform.