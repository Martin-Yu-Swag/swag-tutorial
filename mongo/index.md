# Mongo Index

## Index Types

## Index Property

### [Partial Index](https://www.mongodb.com/docs/manual/core/index-partial/)

> Partial indexes only index the documents in a collection that **meet a specified filter expression**.

> Partial indexes have lower storage requirements and reduced performance costs for index creation and maintenance.

When create Partial index, options `partialFilterExpression` for specifying following filter condition:

- $eq
- $exists: true
- $gt, $gte, $lt, $lte
- $type
- $and
- $or
- $in

eg:

```js
db.restaurants.createIndex(
   { cuisine: 1, name: 1 },
   { partialFilterExpression: { rating: { $gt: 5 } } }
)
```

#### Behavior

Query Coverage

> To use the partial index, a query must contain the filter expression
  (or a modified filter expression that specifies a subset of the filter expression)
  as part of its query condition.

```js
db.restaurants.createIndex(
   { cuisine: 1 },
   { partialFilterExpression: { rating: { $gt: 5 } } }
);

db.restaurants.find( { cuisine: "Italian", rating: { $gte: 8 } } );
// rating query hit the index

db.restaurants.find( { cuisine: "Italian", rating: { $lt: 8 } } )
// wont use index becuz rating index must use > 5
```

Comparison with Sparse Indexes

> Partial indexes should be **preferred over sparse indexes**.
  Partial indexes provide the following benefits:
  - Greater control over which documents are indexed.
  - A superset of the functionality offered by sparse indexes.

> NOTE: a partial index can also specify filter expressions on fields other than the index key

```js
db.contacts.createIndex(
   { name: 1 },
   { partialFilterExpression: { email: { $exists: true } } }
)
// order the document by name where doc exists email

// facilitated queries:
db.contacts.find( { name: "xyz", email: { $regex: /\.org$/ } } )

// query that cant use index
db.contacts.find( { name: "xyz", email: { $exists: false } } )
```

---

In swag-server case: Message Model

```py
class Message:
    meta = {
        'indexes': [
            {
                'cls': False,
                'fields': ['unlocks.user'],
                # create multiple filter on partial
                'partialFilterExpression': {
                    # Broadcast only
                    '_cls': 'Message',
                    # Non-free unlock price
                    'pricing.unlock': {'$gt': 0},
                    # Delivered Messages after June 1, 2017
                    'posted_at': {
                        '$gte': datetime.datetime(2017, 5, 31, 16, 0, 0, 0),
                    },
                },
            },
        ]
    }
```

---

### [Sparse Index](https://www.mongodb.com/docs/manual/core/index-sparse/#sparse-indexes)

> Sparse indexes only contain entries for documents that have the indexed field,
  even if the index field contains a null value.
  -> The index skips over any document that is missing the indexed field.

```js
db.addresses.createIndex(
    { "xmpp_id": 1 },
    { sparse: true },
);
```

#### Behavior

indexes that are Sparse by default

- 2d
- 2dsphere
- text
- wildcard

Example:

```js
db.scores.createIndex( { score: 1 } , { sparse: true } )

// this query will use sparse index
db.scores.find( { score: { $lt: 90 } } )

// this query won't use sparse index
db.scores.find().sort( { score: -1 } )

// use hint() to force index use, and return incomplete set of result
db.scores.find().sort( { score: -1 } ).hint( { score: 1 } )
```

---

In swag-server: `Feed.alias` use sparse index

```py
class Feed(db.Document)
    # ...
    meta = {
        'indexes': [
            {'fields': ['exp'], 'partialFilterExpression': {'exp': {'$exists': True}}},
            {'fields': ['aliases', 'nbf', '-exp']},
            {'fields': ['alias'], 'sparse': True, 'unique': True},
        ],
    }
```
