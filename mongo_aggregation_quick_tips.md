# Frequently used expression in Aggregation

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

## $replaceWith

Replaces the input document with the specified document.

---

## Expression

- `$mergeObject`
- `$concatArrays`
- date-related expression:
  - `$year`
  - `$month`
