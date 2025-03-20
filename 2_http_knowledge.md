# W1-W2

## Status Codes
<details>
<summary>1xx informational</summary>

The request was received and understood.\
It alerts the client to wait for a final response.

</details>

<details>
<summary>2xx: successful</summary>

- 200: OK
- 201: Created
- 202: Accepted
- 204: No Content

</details>

<details>
<summary>3xx: redirection</summary>

- 301: Moved Permanently
- 304: Not Modified\
  No need to retransmit the resource since the client still has a previously-downloaded copy.

</details>

<details>
<summary>4xx: client error</summary>

- 400 Bad Request
- 401 Unauthorized
- 403 Forbidden
- 404 Not Found
- 409 Conflict\
  conflict in the current state of the resource eg. edit conflict between multiple simultaneous updates.
- 422 Unprocessable\
  Form request validation fail.
- 429 Too Many Request\
  rate-limiting schemes

</details>

<details>
<summary>5xx: server error</summary>

- 500 Internal Server Error
- 502 Bad Gateway\
  The server was acting as a gateway or proxy and received an invalid response from the upstream server
- 503 Service Unavailable\
  The server cannot handle the request (eg. temporarily overloaded or down for maintenance)
- 504 Gateway Timeout\
  The server was acting as a gateway or proxy and did not receive a timely response from the upstream server.



</details>

---

## Methods

- GET
- POST / custom method
- PUT (full update) / PATCH (partial update)
- DELETE
- (OPTIONS)?
- (HEAD)?

#### [`Options` method](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/OPTIONS)

- requests permitted communication options for a given URL or server.
- A: used to test the allowed HTTP methods for a req url
- B: determine whether a req would succeed when making a CORS pre-flighted req

Eg. Allowed Request methods

```yaml
# REQUEST
OPTIONS / HTTP/2
Host: example.org
User-Agent: curl/8.7.1
Accept: */*

# RESPONSE
HTTP/1.1 204 No Content
Allow: OPTIONS, GET, HEAD, POST
Cache-Control: max-age=604800
Date: Thu, 13 Oct 2016 11:45:00 GMT
Server: EOS (lax004/2813)
```

Eg. Pre-flighted requests in CORS

```yaml
# REQUEST
OPTIONS /resources/post-here/ HTTP/1.1
Host: bar.example
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Connection: keep-alive
Origin: https://foo.example
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type,x-pingother

# RESPONSE
HTTP/1.1 200 OK
Date: Mon, 01 Dec 2008 01:15:39 GMT
Server: Apache/2.0.61 (Unix)
Access-Control-Allow-Origin: https://foo.example
Access-Control-Allow-Methods: POST, GET, OPTIONS
Access-Control-Allow-Headers: X-PINGOTHER, Content-Type
Access-Control-Max-Age: 86400
Vary: Accept-Encoding, Origin
Keep-Alive: timeout=2, max=100
Connection: Keep-Alive
```

#### [`HEAD` method](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/HEAD)

- requests the **metadata** of a resource in the form of headers that the server would have sent if the GET method was used instead
- CANT have message body
- used where a URL might produce a large download
- eg. read the Content-Length header to check the file size before downloading

```yaml
# REQUEST
HEAD / HTTP/1.1
Host: example.com
User-Agent: curl/8.6.0
Accept: */*

# RESPONSE
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Date: Wed, 04 Sep 2024 10:33:11 GMT
Content-Length: 1234567
```

---

## Find practical usages in our application and think about why are we using it like that.

## [RESTful APIs](https://konghq.com/learning-center/api-gateway/what-is-restful-api)

Representational State Transfer (REST)

- Find resources using URLs
- In JSON/XML format
- The Communication is stateless -> every req is independent
- Standard HTTP methods manage resources in a clear way
- Clients receive clear error messages

#### Comparison with SOAP

SOAP = Simple Object Access Protocol

- With strict rules for XML messaging
- More secured: eg. digital signature & encryption
- Make robust tools, but it can also feel complicated

REST: More like design style under certain principles

#### REST advantages

- Simplicity
- Flexibility
- Scalability
- Performance
- Portability

#### Role of Middleware in REST Integration

- authentication
- logging
- changing requests / responses (eg. Header)
- managing errors

## Explain what is the core concept for a restful API

## Exercise: Design a set of RESTful APIs for a e-commerce website

- Should be as detail as possible

## [API Auth Methods](https://konghq.com/blog/engineering/common-api-authentication-methods)

**Basic Authentication**

- send username & password every API call with HTTP header

**API Keys**

- an unique identification code used to auth API user
- cons:
    - Lacks authorization: when API key get hacked and hold by malicious users
    - User identification: API keys can only identify projects, not individual users

**Digest Authentication**

- verify an individual's credentials using a web browser.
- saves an encrypted version of a username and password to a server

**OAuth 2.0**

- is an authorization protocol and not an authentication protocol.

**JWT**

**OpenID Connect (OIDC)**

# W3-W4

- HTTP 1.1

- Common Request Headers
    - Authorization
    - Accept
    - User-Agent
    - Content-Type
        - json
        - form
    - ETag
    - Find practical usages in our application and think about why are we using it like that.

- Common Response Headers
    - Cache-Control
        - public/private
        - max-age/s-maxage
    - Expires
    - Content-Type
        - json
        - form
    - Find practical usages in our application and think about why are we using it like that.

# W5-W6

- Other HTTP variants
  - HTTP 2
  - HTTP 3

- Security
  - TLS
  - STS

# W7-W8

- Websockets

# Evaluations

- Must adequately understand each item.
- Must found enough practical usages to justify progress.
