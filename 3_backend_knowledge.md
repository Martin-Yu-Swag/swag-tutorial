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
