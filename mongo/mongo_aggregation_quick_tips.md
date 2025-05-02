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

- `$ifNull`
- `$toObjectId`
- `$mergeObject`
- `$concatArrays`
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
