# Mongo Query Note

[2.5 Querying the database](https://docs.mongoengine.org/guide/querying.html)

- `model.objects` -> QuerySetManager, creates and return new `QuerySet` object on access

- queryset utilize a local cache.
  Use `Model.objects.no_cache()` to return a non-caching queryset.

## 2.5.1. Filtering queries

```py
# Filter Document by field
uk_users = User.objects(country='uk')

# Fields on embedded documents
uk_pages = Page.objects(author__country='uk')

# if field name is like mongodb operator name: (etc type)
# use __ at the end of lookup keyword
Model.objects(user__type__='admin')
```

## 2.5.2 Query Operators

- `ne` (not equal to)
- `lt`, `lte`
- `gt`, `gte`
- `not` (eg. `Q(age__not__mod=(5,0))`)
- `in`
- `nin`
- `mod`
- `all`: every item in list of values provided is in array
- `size`
- `exists`

### 2.5.2.1. String queries

- `exact`, `iexact`
- `contains`, `icontains`
- `startswith`, `istartswith`
- `endswith`, `iendswith`
- `wholeword`, `iwholeword`: string field contains whole word
- `regex`, `iregex`
- `match`: performs an `$elemMatch`

### 2.5.2.3. Querying lists

```py
# match all pages that has "coding" in the tags list
Page.objects(tags="coding")

# query by position
Page.objects(tags__0="db")s

# string queries operators can be used for querying list field
Page.objects(tags__iexact='db')

# slice list field with `slice` operator
Page.objects.fields(slice__comments=[5,10])

# updating documents with `$` positional arguments
Page.objects(comments__by="joe")
    .update(**{'inc__comments__$__votes': 1})
# equals to
Page.objects(comments__by="joe")
    .update(inc__comments__S__votes=1)
```

> [!NOTE]
> Due to Mongo, currently the $ operator only applies to the **first** matched item in the query.

### 2.5.2.3. Raw queries

Provide a raw PyMongo query as a query parameter.

```py
# raw query
Page.objects(
    __raw__={"tags": "coding"},
)

# raw update
Page.objects(tags="coding")
    .update(__raw__={
        "$set": {"tags": "coding"}
    })
```

### 2.5.2.5 Update with Aggregation Pipeline

```py
Page.objects(tags='coding')
    .update(__raw__=[
        "$set": {
            "tags": {"$concat": ["$tags", "is fun"]}
        }
    ])
```

### 2.5.2.6. Update with Array Operator

Update specific value in array by use `array_filters` operator.

```py
Page.objects()
    .update(
        __raw__={
            '$set': {"tags.$[element]": 'test11111'}
        },
        array_filters=[{"element": {'$eq': 'test2'}}],
    )
```

## 2.5.3. Sorting/Ordering results

```py
blogs = BlogPost.objects().order_by('date')
blogs = BlogPost.objects().order_by('+date', '-title')
```

## 2.5.4. Limiting and skipping results

- `limit()`, `skip()` or array-slicing syntax
- `first()`

```py
users = User.objects[:5]
users = User.objects[5:]
users = User.objects[10:15]
```

### 2.5.4.1. Retrieving unique results

- To retrieve a result that should be unique in the collection, use `get()`
- raise `DoesNotExist` if not doc match
- raise `MultipleObjectsReturned` if more than one doc match

## 2.5.5. Default Document queries¶

```py
class BlogPost(Document):
    title     = StringField()
    date      = DateTimeField()
    published = BooleanField()


    @queryset_manager
    def objects(doc_cls, queryset):
        return queryset.order_by('-date')

    @queryset_manager
    def live_posts(doc_cls, queryset):
        return queryset.filter(published=True)
```

## 2.5.6. Custom QuerySets

```py
class AwesomerQuerySet(QuerySet):

    def get_awesome(self):
        return self.filter(awesome=True)

class Page(Document):
    meta = {'queryset_class': AwesomerQuerySet} # Here define the custom query manager

# To call:
Page.objects.get_awesome()
```

## 2.5.7. Aggregation

```py
num_users      = User.objects.count()

yearly_expense = Employee.objects.sum('salary')

mean_age       = User.objects.average('age')

# Special operator: item_frequencies
tag_freqs = Article.objects.item_frequencies('tag', normalize=True)

from operator import itemgetter
top_tags = sorted(tag_freqs.items(), key=itemgetter(1), reverse=True)[:10]
```

### 2.5.7.3. MongoDB aggregation API

- `aggregate()`

```py
pipeline = [
    {"$sort": {"name" : -1}},
    {"$project": {"_id": 0, "name": {"$toUpper": "$name"}}}
]
data = Person.objects().aggregate(pipeline)
```

## 2.5.8. Query efficiency and performance

### 2.5.8.1. Retrieving a subset of fields

- To select only a subset of fields, use `only()`, specifying the fields you want to retrieve as its arguments
- if fields that are not downloaded are accessed, return default value or None
- opposite: `exclude()`
- call `reload()` on your document if you later need the missing fields.

```py
Film.objects.only('title').first()
```

### 2.5.8.2. Getting related data

> When iterating the results of ListField or DictField,
> we automatically dereference any DBRef objects as efficiently as possible,
> reducing the number the queries to mongo.

- To limit the number of queries, use `select_related()`
  which converts the QuerySet to a list and dereferences as efficiently as possible.
- increasing the `max_depth` will dereference more levels of the document

### 2.5.8.3. Turning off dereferencing

- use `no_dereference()` or context manager on the queryset

```py
post = Post.objects.no_dereference().first()

with no_dereference(Post):
    post = Post.objects.first()
```

## 2.5.9. Advanced queries

> A Q object represents part of a query, and can be initialised using the same keyword-argument syntax you use to query documents.

- To build a complex query, you may combine Q objects using the `&` (and) and `|` (or) operators

```py
from mongoengine.queryset.visitor import Q

# Get published posts
Post.objects(
    Q(published=True) | \
        Q(publish_date__lte=datetime.now())
)

# Get top posts
Post.objects(
    (Q(featured=True) & Q(hits__gte=1000)) | \
        Q(hits__gte=5000)
)
```

## 2.5.10. Atomic updates

- Documents may be updated atomically by using following methods on a `QuerySet`
  - `update_one()`
  - `update()`
  - `modify()`
- or `modify()` and `save()` (with save_condition argument) on a `Document`

Modifiers use with these methods:

- `set`
  (default if no operator provided in kwargs)
- `set_on_insert`
- `unset`
- `max`
- `min`
- `inc`
- `dec`
- `push`
- `push_all`
- `pop`
- `pull`
- `add_to_set`
- `rename`

```py
# positional operator allows you to update list items without knowing the index position
BlogPost.objects(id=post.id, tags='mongo').update(set__tags__S='mongodb')

# push values with index:
post.update(push__tags__0=["database", "code"])
```
