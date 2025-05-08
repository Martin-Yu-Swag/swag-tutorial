# Frequently used expression in Aggregation

## $unwind

- treat non-array field as single element array

> When using this syntax, `$unwind` does not output a document if the field value is null, missing, or an empty array

## $addField

## $facet

## $group

special use: group by null

> If you specify an _id value of null, or any other constant value,
> the `$group` stage returns a single document that aggregates values across all of the input documents.

```py
{
    '$group': {
        '_id': None,    # Actually take whole as group
        'items': {
            "$push": "$ROOT"
            # collapse all aggregation results into 'items' field
        }
    }
}
```

## $project

- ignore field if not exist

## $replaceWith

Replaces the input document with the specified document.

---

## Expression

- `$dateSubtract`
  - startDate
  - unit
  - amount
  - timezone

- `$ifNull`
- `$toObjectId`
- `$mergeObject`
- `$concatArrays`
- `$arrayElemAt`
- `$regexMatch`
- `$setDifference`
- `$setUnion`
- `$switch`
- `$split`

Note: if split with starting sting:

{ $split: [ "astronomical", "astro" ] }
-> ["", "nomical"]

- date-related expression:
  - `$year`
  - `$month`

- `$objectToArray`: turn object into array of object []

eg: { item: "foo", qty: 25 }

```json
[
   {
      "k" : "item",
      "v" : "foo"
   },
   {
      "k" : "qty",
      "v" : 25
   }
]
```

- `$arrayToObject`

--- 

MapField

> A field that maps a name to a specified field type. Similar to a DictField, except the ‘value’ of each item must match the specified field type.

-> value must be specified type!

---

## `__S__` in mongoengine

- 源自於 Mongo positional operator `$`
  ([Reference](https://www.mongodb.com/docs/manual/reference/operator/update/positional/))

```js
db.students.updateOne(
   { _id: 1, grades: 80 },
   { $set: { "grades.$" : 82 } }
)
```

- 在 mongoengine 中，因 python key 不能有 `$`，故變成
  (See [Querying List](https://docs.mongoengine.org/guide/querying.html#querying-lists))

```py
Post.objects(comments__by="joe").update(inc__comments__S__votes=1)
```

---

## [Expressions Explained](https://www.practical-mongodb-aggregations.com/guides/expressions.html#expressions-explained)

**Aggregation expressions** come in one of three primary flavours:

- **Operators**
  Accessed as an obj with `$` prefix

- **Field Paths**
  Accessed as a string with `$` prefix followed by the field's path

- **Variables**
  Accessed as a string with a `$$` prefix followed by the fixed name and falling into three sub-categories

  - Context System Variables
    coming from the system environment
    (`$$NOW`, `$$CLUSTER_TIME`)

  - Marker Flag System Variables
    To indicate desired behavior to pass back to the aggregation runtime
    (`$$ROOT`, `$$REMOVE`, `$$PRUNE`)
   
  - Bind User Variables
    storing values you declare with a $let / $map / $lookup operator
    (`$$product_name_var`)

Example:

```js
"customer_info": {
   "$cond": {
      "$if"  : {"$eq": ["$customer_info.category", "SENSITIVE"]},
      "$then": "$$REMOVE",
      "$else": "$customer_info",
   }
}
```

### What Do Expressions Produce?

- expression can be either
  Operator ({`$concat`:...})
  Variable (`$$ROOT`)
  Field Path (`$address`)
  -> just something that **dynamically** populates and returns a new JSON/BSON data type element

- JSON/BSON types:
  - Number (int, long, float, double, decimal...)
  - String (UTF-8)
  - Boolean
  - DateTime
  - Array
  - Object

- specific expression can restrict the returning to specific types:
  eg: `$concat` -> string
      `$$ROOT` -> Object

- Field Paths & Bind User Variables are expressions that can return any JSON/BSON data type

### Can All Stages Use Expressions?

NO. There are many types of stages in the Aggregation Framework that **don't allow expressions to be embedded**. eg:

- $match
- $limit
- $skip
- $sort
- $count
- $lookup
- $out

> !!!The content of a `$match` stage is just a set of query conditions
  with the same syntax as MQL rather than an aggregation expression.

### What Is Using `$expr` Inside `$match` All About?

- the `$expr` operator allows you to embed within a `$match` stage (or in MQL)
  to leverage aggregation expressions when filtering records

> Inside a $expr operator, you can include any composite expression fashioned
  from $ operator functions, $ field paths and $$ variables.

eg.

```js
"$match": {
   "$expr": {
      "$gt": [
         {"$multiply": ["$width", "$height"]},
         12,
      ]
   }
}
```

