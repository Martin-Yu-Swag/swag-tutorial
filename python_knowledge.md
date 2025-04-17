### ENV `PYTHONPATH`

add additional import source directory

eg. in swag project: `./libs`

!!! in vscode, pylance setup:

```json
{
    "python.analysis.extraPaths": [
        "./libs"
    ]
}
```

### tempfile module

### @dataclasses.dataclass

### boltons module

- [boltons.dictuils.FronzenDict](https://boltons.readthedocs.io/en/latest/dictutils.html#boltons.dictutils.FrozenDict)

- boltons.dictutils.subdict

- boltons.dictutils.OrderedMultiDict

- boltons.dictutils.OneToOne

- [boltons.cacheutils.cachedproperty](https://boltons.readthedocs.io/en/latest/cacheutils.html#boltons.cacheutils.cachedproperty)

- [boltons.iterutils.bucketize](https://boltons.readthedocs.io/en/latest/iterutils.html#boltons.iterutils.bucketize)
  - Group values in the src iterable by the value returned by key.
  - `bucketize(range(5), lambda x: x%2 == 1)` -> `{False: [0, 2, 4], True: [1, 3]}`

- boltons.iterutils.chunked

- boltons.iterutils.unique_iter

- boltons.iterutils.first

- boltons.iterutils.get_path

- boltons.namedutils.namedtuple

- boltons.urlutils.URL

### Flask

#### `after_app_request`

[Official doc](https://flask.palletsprojects.com/en/stable/api/#flask.Flask.after_request)

- `after_request` can register on app / blueprint level
- `after_app_request` however will execute after every request
  (equals to `app.after_request` even register on blueprint)

#### app.route("/url", default={})

default is passed kwargs in `werkzeug/routing/rules.py::Rule` constructor

> An optional dict with defaults for other rules with the same endpoint.
> This is a bit tricky but useful if you want to have unique URLs:
> ```py
> url_map = Map([
>    Rule('/all/', defaults={'page': 1}, endpoint='all_entries'),
>    Rule('/all/page/<int:page>', endpoint='all_entries')
>  ])
> ```

But this seems to be used for providing default url path params...
Why "validators" exist?

# Question:

add Etag in swag/core/__init__.py::update_cache_control.
but where does etag be modified to "Weak"???

A:

Nginx will automatically weaken etag if gzip is on.

https://stackoverflow.com/a/63311338/20307835

# Python `yield`
