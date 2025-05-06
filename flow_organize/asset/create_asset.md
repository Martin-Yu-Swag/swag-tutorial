# Create Asset

Entrypoint: [POST] `/assets`

Body:

```json
{
    "content_type"    : "str",
    "content_length"  : "int",
    "content_md5"     : "str",
    "content_language": "str",
}
```

- create Asset
  - id
  - owner
  - content_md5
  - content_type
  - content_length
  - content_language
  - exp = now + 1 hours
  - metadata: get from task.get_metadata
    - ip
    - country
    - request_id
    - session_id
    - client_id
    - platform
    - browser
    - os
    - version
    - language
    - flavor (...IF value is not None)

- NOTE: Asset queryset `create` method is specified,
  to check whether Asset of following exists:
  - filter
    - owner
    - content_md5
    - statuses__completed__exists
  - If already exists, update rather than insert

- IF asset is newly created:
  - Send Signal `asset.created`
    - **args**
      - asset_id        = asset.id,
      - owner_id        = asset.owner.id,
      - content_type    = asset.content_type,
      - content_length  = asset.content_length,
      - content_md5_b64 = asset.content_md5_b64,
    - **receivers**
      - track_asset_events
