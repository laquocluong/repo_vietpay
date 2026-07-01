# Polyglot Data Modeling

Modern payment platforms often use multiple database technologies, selecting the best storage engine for each workload instead of forcing every use case into a relational database.

This design uses PostgreSQL as the system of record while introducing MongoDB and Neo4j for workloads where they provide clear advantages.

---

# 1. MongoDB Use Case
Raw Webhook Event Storage

Payment providers (Stripe, PayPal, Adyen, etc.) send webhook events containing large JSON payloads.

Example:

```json
{
  "event": "payment.succeeded",
  "provider": "Stripe",
  "created": 1748859032,
  "payload": {
    "id": "evt_123",
    "customer": "cus_001",
    "payment_method": {
      "type": "card",
      "brand": "visa",
      "last4": "4242"
    },
    "metadata": {
      "campaign": "summer_sale"
    }
  }
}
```

Each provider defines its own payload structure.

New fields are introduced frequently without notice.

---

## MongoDB Collection

```javascript
webhook_events

{
    _id,
    provider,
    event_type,
    received_at,
    payload
}
```

The entire provider payload is stored without modification.

---

## Why MongoDB?

MongoDB is a better fit because:

* Schema is flexible.
* Providers frequently change payload formats.
* Documents can contain deeply nested objects.
* No schema migration is required when new fields appear.
* High write throughput for append-only event ingestion.
* Easy to archive old events.


---

## Why Not PostgreSQL JSONB?

PostgreSQL JSONB can also store JSON documents, but it is not the ideal choice for this workload.

Reasons:

* Every JSONB update rewrites the entire row because of PostgreSQL's MVCC model.
* Large JSON documents increase table and index bloat.
* Mixing operational transaction data with large webhook payloads increases backup size and affects maintenance tasks such as VACUUM.
* JSONB indexing (GIN indexes) can consume substantial disk space.
* Operational transaction queries should not compete with append-only event storage.

JSONB is excellent for small, queryable JSON attributes, but a dedicated document database is a better choice for large, evolving event payloads.


---

# 2. Neo4j Use Case

## Fraud Ring Detection

Fraud detection relies on discovering relationships rather than individual records.

Example:

* Customer A owns Wallet A
* Wallet A sends money to Wallet B
* Wallet B belongs to Customer B
* Customer B shares a device with Customer C
* Customer C shares a bank account with Customer D

These interconnected relationships form a graph.


---

## Graph Model
(Customer)

    |
 OWNS

    |

(Wallet)

    |
TRANSFERRED_TO

    |

(Wallet)

    |
OWNED_BY

    |

(Customer)

    |
USES_DEVICE

    |

(Device)

Node Types

```
Customer
Wallet
Merchant
Device
BankAccount
IPAddress
```

Relationship Types

```
OWNS
TRANSFERRED_TO
USES_DEVICE
USES_IP
REGISTERED_WITH
REFERRED
```


---

# Example Cypher Queries

## Query 1

Find all customers within three hops of a suspicious customer.

```cypher
MATCH (c:Customer {id: $customerId})-[*1..3]-(related)
RETURN DISTINCT related;
```

This identifies indirectly connected accounts that may belong to the same fraud ring.


---

## Query 2

Find wallets involved in circular money transfers.

```cypher
MATCH p =
(w1:Wallet)-[:TRANSFERRED_TO*2..5]->(w1)
RETURN p;
```

This detects cycles where funds move through multiple wallets and return to the origin, a common money laundering pattern.



---

## Why Neo4j?

Neo4j is designed for relationship-heavy queries.

Typical fraud investigations involve:

- Multi-hop traversals: easy to "jump" from one node to another node.
- Network analysis: looking at the bigger picture to see how the various entities (users, devices, bank accounts, addresses) are interconnected.
- Community detection:  automatically categorizes nodes in a graph into groups based on the density of interactions between them.
- Cycle detection: Detecting cash flows in a loop and returns to its starting point (A → B → C → A).
- Shared identities:  when multiple different accounts share some identifying information (ex, the same phone number).

Graph databases execute these traversals efficiently without expensive joins.



---

## Why Not PostgreSQL?

The same investigation in PostgreSQL would require:

* Multiple self-joins
* Recursive Common Table Expressions (CTEs)
* Increasing query complexity as traversal depth grows

For example, finding customers within five relationship hops becomes increasingly difficult to express and optimize using SQL.

Neo4j stores relationships as first-class citizens, allowing graph traversals to execute efficiently regardless of graph size.


---

# Database Responsibilities

| Database   | Primary Responsibility                                                                     |
| ---------- | ------------------------------------------------------------------------------------------ |
| PostgreSQL | System of record for users, wallets, transactions, ledger entries, and financial integrity |
| MongoDB    | Raw webhook payload storage and append-only event ingestion                                |
| Neo4j      | Fraud detection, referral networks, and relationship analysis                              |


---

# Conclusion

Each database is selected according to its strengths:

* PostgreSQL  ensures ACID compliance and relational integrity for financial data.
* MongoDB     efficiently stores flexible, high-volume event documents with evolving schemas.
* Neo4j       enables fast traversal of complex relationships, making it well suited for fraud detection and  referral network analysis.

This polyglot approach keeps each workload in the database that is best suited to handle it, improving scalability, maintainability, and overall system performance.