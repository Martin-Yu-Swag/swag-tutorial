# W1-W2

## [API best practices](https://stackoverflow.blog/2020/03/02/best-practices-for-rest-api-design/)

This article is aiming for best practices in REST.

#### Accept and respond with JSON

- Set `Content-Type` to `application/json` (`application/json; charset=utf-8`)

#### Use nouns instead of verbs in endpoint paths

- Noun represents the entity that endpoint retrieving.
- Verb is illustrated in HTTP Method already.
- CRUD - POST/GET/PUT/DELETE

#### Use logical nesting on endpoints

- Parent / Children Relationships

#### Handle errors gracefully and return standard error codes

- Respond with meaningful and informative status code.

#### Allowing filtering, sorting, and pagination

- Return too many resources at a time may slow down systems.
- Implemented through query parameters.
- eg. sorting with directions:\
  `http://example.com/articles?sort=+author,-datepublished` -> "+" = ascending / "-" = descending

#### Maintain good security practices

- using SSL/TLS for security
- Role-based access control -> implementation of **Least Privilege Principle**

#### Cache data to improve performance

- Include [`Cache-Control`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) in headers if using caching

#### Versioning our APIs

## Idempotency (冪等性)

#### By wiki:

> Idempotency is the property of certain operations in mathematics and computer science whereby they can be **applied multiple times without changing the result** beyond the initial application.

-> Repeated requests produce same result.

#### By MDN:

Safe methods:

- doesn't alter the state of the server (eg. read-only operation)
- GET, HEAD, OPTIONS

Idempotent HTTP methods: `GET`, `HEAD`, `OPTIONS`, `PUT`, `DELETE` (`POST` excluded)

To be idempotent, only the **state of the server** is considered.

#### [By Temporal](https://temporal.io/blog/idempotency-and-durable-execution)

- It is nice to be able to retry things safely without causing unintended duplicate effects.

## What are some patterns that we used in our application ?

---

# W3-W4

## Common authorization strategies

### [JWT](https://jwt.io/introduction)

- JWT = JSON Web Token
- Signed using a secret (HMAC alog) or a public/private key pair using RSA/ECDSA
- Signed tokens
  can verify the integrity of the claims
- Encrypted tokens
  hide those claims from other parties

#### When to use

- Authorization
- Information Exchange (between parties, signature prevents tampering)

#### Structure

xxxx.yyyy.zzzz

**Header**

```json
{
"algo": "HS256",
"typ": "JWT"
}
```

- type & signing algo
- base64Url encoded


**Payload**
```json
{
"sub": "1234567890",
"name": "John Doe",
"admin": true
}
```

- claims = statements about user data
- base64Url encoded

- *Registered claims*
  - set of predefined claims, not mandatory but recommended
  - `iss` = issuer
  - `iat` = issue at
  - `exp` = expiration time
  - `sub` = subject
  - `aud` = audience

- *Public claims*
  - defined at will

- *Private claims*
  - custom claims to share info between parties

- **Signature**

```js
HMACSHA256(
    base64UrlEncode(header) + "." + base64UrlEncode(payload),
    secret,
)
```

- Take encoded header, encoded payload, secret, algo in header to signed.

#### How it works

- should not store sensitive session data in browser storage due to lack of security
- Typically in **`Authorization`** header using **`Bearer`** schema
- Some servers don't accept more than 8 KB in headers

#### Why JWT over SWT / SAML

SWT = Simple Web Tokens
SAML = Security Assertion Markup Language

More compact than SAML:
- JWT less verbose than XML
- JWT is encoded -> smaller in size
- XML don't have native parser in most programming language, JWT is easier to work with

More secure-wise than SWT:
- SWT use symmetrical signature
- JWT signing using public/private key pair

#### Diff between Validating & Verifying a JWT

JWT validation

- Checking the structure / format / content of JWT
- Structure -> check 3 dot-separated part
- Format -> correctly encoded with Base64URL
- Content -> claims in the payload are correct

JWT verification

- Confirming the authenticity and integrity of JWT
- Signature Verification
- Issuer Verification
- Audience Check

### What is the overall authorization flow in our API server ?

- Redirect to Google OAuth, Acquire OAuth token
- login through `POST /social/login/<string:backend>`, acquire refresh token with scopes:

```json
{
  "jti": "foPtNLtd2xWKeb6N",
  "iss": "api.swag.live",
  "aud": "api.swag.live",
  "sub": "67ceabecc82b8fd6cf63d6d6",
  "iat": 1742885661,
  "scopes": [
    "-DEFAULT",
    "token:refresh"
  ],
  "version": 2,
  "metadata": {
    // from ClientRequestMixin
    "client_id": "ac9cd42b-2982-430f-bdd0-18b0ce505d0a",
    // from ClientRequestMixin
    "fingerprint": "d2793dd4",
    "original": {
      "iat": 1742885661,
      "method": "google-oauth2"
    },
    "user_agent": {
      "flavor": "swag.live"
    }
  }
}
```

- login through  `POST /auth/token` with refresh token, acquire access token (or token)

```json
{
  "sub": "67ceabecc82b8fd6cf63d6d6",
  "jti": "foPtNLtd2xWKeb6N",
  "iss": "api.swag.live",
  "aud": "api.swag.live",
  "iat": 1742885662,
  "exp": 1742889262,
  "version": 2,
  "metadata": {
    "fingerprint": "d2793dd4",
    "flavor": "swag.live",
    "original": {
      "iat": 1742885661,
      "method": "google-oauth2"
    }
  }
}
```

## Common caching strategies (x

### Generate on miss

### [Pre-heat/generate on update](https://www.fasterize.com/en/blog/cache-warming-why-and-how/)

- `cold cache`: empty cache
- `warm cache`
- `cache miss`
- `cache hit`

#### Challenges in Cache warming

Too many cache servers to warm

- Solution: target only certain nodes of the CDN (principle nodes)
- eg. regional edge cache in Cloudfront

Page lifespans that are too short

- Solution: only pre-loading key site pages.

An origin server that can’t cope with regular crawling (Stress/loading aspect)

- reduce the number of pages crawled,
- reduce the crawling speed,
- carry out crawling at quieter times.

Too many possible variations per page

- determine which versions to prioritize

### What are some cache usages in our application ?

- language-level cache
  - `boltons.cacheutils.cachedproperty`

- app-level: db query result cache by `CachedQuerySet`
  - cross-request query cache
  - 以 query 語句結構作為 cache key
  - cache `first` / `aggregate` result

- app-level:
  - `swag/decorators/caches.py::cache`
    主要作為 view function cache
  - `swag/decorators/caches.py::memoized`
    使用在 instance function cache，處理 cache key 時移除 mutable (aka non-hashable) arg (eg. self, task)

---

# W5-W6

## ACID

### [ACID Databases – Atomicity, Consistency, Isolation & Durability Explained](https://www.freecodecamp.org/news/acid-databases-explained/)

> while a lot of DBMS may say they are ACID compliant,
> the implementation of this compliance can vary.

#### What are Transactions?

> Transactions serve a single purpose: they make sure a system is fault tolerant

> Transaction is a collection of operations (reads and writes)
> that are treated as a "single" logical operation.

#### What Does Atomicity Mean?

> all queries in a transaction must succeed for the transaction to succeed.

-> All or None, Partial failures not allowed.

#### What Does Consistency Mean?

> consistency in data (integrity)
> Referential integrity is a method of ensuring that relationships between tables remain consistent.

-> Usually enforced through the use of **foreign keys**.

- In comparison with A/I/D, consistency is actually not a property
  intrinsic to the DB.

#### What Does Isolation Mean?

> A guarantee that concurrently running transactions should not interfere with each other.

**Read Committed**

- No Dirty Reads
- No Dirty Writes

**Repeatable Read**

> guarantees that if a transaction reads a row of data, any subsequent reads of that same row of data within the same transaction will yield the same result, regardless of changes made by other transactions.

- The repeatable read isolation level prevents "fuzzy reads".
  (read a diff value after other transaction commit made)

- Fuzzy reads are bad for long-running, read-only transactions
  (eg. Backup or analytical queries)

- usually implemented by the DBMS by reading from a snapshot

#### What Does Durability Mean?

> guarantee that changes made by a committed transaction must not be lost.

---

## [数据库管理系统 ACID 属性指南](https://www.mongodb.com/basics/acid-transactions)

### 什么是 ACID 事务？

事务 = transaction

單個事務 / 多事務

### 原子性 Atomicity

In MongoDB:

- 写入操作在**单个文档级别上**是原子性的
- 分布式事务才支持多个文档读写操作原子性 (replica / shard)

### 一致性 Consistency

In MongoDB:

- 灵活地规范化或复制数据
- 若模式中存在重复数据，则开发人员必须决定如何在多个集合中保持重复数据的一致性

Solution:

- Transaction
- Embedded Document
- Atlas Database Triggers
  - latency occur, but guarantee Eventual consistency

### 隔離性 Isolation

In MongoDB:

- 快照隔离 (Snapshot Isolation)
- [Transactions and Read Concern](https://www.mongodb.com/docs/manual/core/transactions/#transactions-and-read-concern)
- [Transactions and Write Concern](https://www.mongodb.com/docs/manual/core/transactions/#transactions-and-write-concern)
  -> 设定适当的读关注和写关注级别

### 持久性 Durability

In MongoDB:

> 创建一个 **OpLog**，其中包含每次“写入”的磁盘位置和更改的字节。
> 如果在写入事务期间发生不可预见的事件（例如停电），则可以在系统重新启动时使用 **OpLog** 来重放关机前未刷新到磁盘的所有写入操作。
> **OpLog** 具有幂等性，可以多次重试。

---

## Common DB things

### Queries

### Indexes

- Why are indexes important
  A: To avoid scanning the entire table for every queries.

- Why don’t we just index all the fields?
  A: 
    - index take space for storage
    - most of the time an query will only start scanning from certain index

- What are the differences between index types

#### [SQL Index](https://reliasoftware.com/blog/types-of-indexes-in-sql)

##### Clustered Indexes

- A clustered index **sorts and stores the data rows** of the table based on the key values
- There can be only 1 clustered index per table since data rows already sorted and stored by the index key
  -> the actual data is **stored in the leaf nodes** of the index!
- The clustered index key is typically table's PK

- Advantages:
  - Efficient for range queries (on index)
  - Faster data retrieval for queries that require sorted data 
    (since index leaf itself stored the hole row data)
  
- Disadvantages:
  - Slower performance C,U,D operations as the physical order of rows needs to be maintained
  - Only 1 clustered index per table

##### Non-Clustered Indexes

- Creates a separate structure that points to the actual data rows
- Multiple non-clustered indexes can be created on a single table
- The data rows are not physically sorted to match the index;
  index contains pointers to the actual data rows

- Advantages
  - Faster retrieval of data for queries involving columns other than the primary key:
  - Multiple non-clustered indexes can be created per table

- Disadvantages
  - Takes up additional storage space
  - Can slow down data modification operations due to the need to update the index

##### Unique Indexes

> A unique index ensures that the values in the indexed column(s) are unique across the table, which helps maintain data integrity.

- Prevents duplicate values in the indexed columns
- Often used to enforce unique constraints on tables
- can be created on a combination of columns to enforce uniqueness across multiple fields.

Advantages:

- Data Integrity
- Efficient Data Retrieval

Disadvantages:

- Overhead on Data Modifications
- Storage Requirements

##### Full-Text Indexes

- used for text-searching capabilities.
- allow for efficient searching of large text columns and are useful for implementing search functionality
- Optimized for searching text data
- Supports advanced search options like 
  - full-text search
  - prefix searches
  - proximity searches
- Support for Natural Language Queries

Advantages:

- Efficient Text Searches
- Advanced Search Capabilities

Disadvantages:

- Resource Intensive (for CPU & RAM)
- Maintenance Overhead

##### Composite Indexes

> Composite indexes are indexes on multiple columns.

- Column Order Matters!

Advantages:

- Optimizes Multi-Column Queries
- Reduces the Number of Indexes Needed

Disadvantages:

- Larger Index Size
- Complexity in Index Management

##### Filtered Indexes

> Filtered indexes are non-clustered indexes that include rows that meet a specific condition.

-> Basically just index created with `WHERE` clause, to reduce query data size

```sql
CREATE INDEX idx_active_users ON Users (UserID) WHERE IsActive = 1;
```

- Indexes a Subset of Rows
- Selective Indexing

Advantages

- Improved Performance For Specific Queries
- Reduced Index Maintenance

Disadvantages

- Limited Use Cases
- Complex Index Design (optimized through query patterns and data distribution)

#### [MongoDB Index](https://www.mongodb.com/docs/manual/core/indexes/index-types/#std-label-index-types)

- With index, MongoDB need not to scan every document in a collection to return query results
- Adding an index has negative performance impact for write operations.
  For collections with a high write-to-read ratio, indexes are expensive.
- MongoDB indexes use a B-tree data structure
- The ordering of the index entries supports efficient equality matches and range-based query operations
- Index has [limitations](https://www.mongodb.com/docs/manual/reference/limits/#std-label-index-limitations).
- `_id` field as default unique index
- CANT rename an index; instead, drop it and recreate one.
- Applications may encounter reduced performance during index builds

##### Single Field Index

- Can create a single-field index on any field in a document,
  - Top-level document fields
  - Embedded documents
  - Fields within embedded documents

- Can specify index when create:
  - The field on which to create the index
  - The sort order for the indexed values (ascending or descending).

##### Compound Index

> Compound indexes collect and sort data from two or more fields in each document in a collection.

- Data is grouped by the first field in the index and then by each subsequent field.

> A **covered query** is a query that can be satisfied entirely using an index
> and does not have to examine any documents, leading to greatly improved performance

##### MultiKey Indexes

> Multikey indexes collect and sort data from fields containing array values.
> Multikey indexes improve performance for queries on array fields.

- no need to specify the multikey type, just create an index on array field.
- can create multikey indexes over arrays that hold both scalar values (for example, strings and numbers) and embedded documents

- Unique Multikey Index / Compound Multikey Index

##### Wildcard Indexes

> Use wildcard indexes to support queries against arbitrary or unknown fields.

- queries a collection where field names vary between documents
- queries an embedded document field where the subfields are not consistent
- queries documents that share common characteristics with Compound Wildcard Index

##### Hashed Indexes

> Support sharding using hashed shard keys

---

### Data modeling

### What are some different types of queries that we use in our application?

### Background asynchronous transport

- What are background asynchronous transport?

- What use cases do we have for background transport in our application?

# W7-W8

- [Task Queues](https://dev.to/sarbikbetal/task-queues-and-why-do-we-need-them-26mj)
    - Broker
    - Producer
    - Consumer
    - List out a few usages for task queue in our application and trace the overall flow to the best you can.

# Evaluations

- Must adequately understand each item.
- Must found enough practical usages to justify progress.
