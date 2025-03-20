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

- Common authorization strategies
    - [JWT](https://jwt.io/introduction)
    - What is the overall authorization flow in our API server ?

- Common caching strategies (x
    - Generate on miss
    - [Pre-heat/generate on update](https://www.fasterize.com/en/blog/cache-warming-why-and-how/)
    - What are some cache usages in our application ?

# W5-W6

- ACID
    - https://www.freecodecamp.org/news/acid-databases-explained/
    - https://www.mongodb.com/basics/acid-transactions

- Common DB things
    - Queries
    - Indexes
        - Why are indexes important
        - Why don’t we just index all the fields?
        - What are the differences between index types
    - Data modeling
    - What are some different types of queries that we use in our application?
    - Background asynchronous transport
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
