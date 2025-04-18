# Asset Upload Workflow

NOTE: Artifact possible labels

- poster.jpg
- trailer.mp4
- thumbnail
- METADATA -> ffprobe result
- SOURCE
- SOURCE_vips

## Upload Asset API

entrypoint: `/assets`
routing: `swag/features/assets/endpoints.py::create_asset`

- payload:

```json
{
    "content_type"    : "str",
    "content_length"  : "int",
    "content_md5"     : "str",
    "content_language": "str",
}
```

1. Asset.object.create

- set `exp` to now
- set `statuses.created` now
- set a bunch of `metadata` according to request metadata (eg. ip, country, browser etc)

NOTE:

In Asset QuerySet, create() function was specified:

- check whether `owner`, `content_md5` duplicate AND Statuses.completed exists.
- if exist -> retrieve from DB directly

2. After create/fetch
    1. If Asset is fetched -> return response with `uploadUrl` field empty, and not trigger created signal
    2. If Asset is created -> generate `uploadUrl`, and trigger `asset.created` signal

NOTE: here url is pre-signed url for **quarantine** bucket

3. `asset.created` receivers:

  - `track_asset_events`
    Simply xadd asset-creation related information in Redis Stream (config: `ANALYTICS_TRACK_STREAM_NAME`)

---

## Pubsub Signal: Quarantine Bucket OBJECT_FINALIZE

**SUMMARY**: Update Asset metadata-related field (eg. content, quarantine url, unset exp)

Then, after Quarantine bucket receive the uploaded file,
it send pubsub subscription signal `OBJECT_FINALIZE` to swag-server callback:

- reference: [Google Storage And PubSub Notification](https://cloud.google.com/storage/docs/pubsub-notifications#events)

- endpoint: [POST] `/notify/googlecloud/pubsub`
- payload

    ```json
    {
        "subscription": "projects/swag-2c052/subscriptions/assets",
        "message": {
            "messageId": "",
            "publishTime": "",
            "attributes": {
                "payloadFormat": "JSON_API_V1",
                "eventType": "OBJECT_FINALIZE",
                "bucketId": "",
                "objectId": ""
            },
            "data": "",  // b64encoded JSON string
            "data": {
                "contentType": "",
                "size": "",
                "md5Hash": "" // b64encoded, which is content_md5
            }
        }
    }
    ```

1. Trigger signal `ext.googlecloud.pubsub` on sender subscription (In this case, `projects/swag-2c052/subscriptions/assets`)

2. Receivers: taking care by `swag/features/assets/signals/__init__.py::handle_asset_quarantine_events_from_google_cloud_storage`

- `handle_asset_quarantine_events_from_google_cloud_storage`
  - Verify:
    - `event_type`, `bucket_id`, `object_id` exist
    - check event_type match
    - check bucket_id match re_QUARANTINE_BUCKET (`r'quarantine\.swag\.live$'`)
    - check object_id match (`r'^assets/(?P<asset_id>[a-f0-9]{24})$'`)

  - !!!Update Asset by asset_id:
    - set content_type         = data['contentType']
    - set content_length       = data['size']
    - set content_md5          = 64decoded data.get('md5Hash')
    - set storage.quarantine   = f'gs://{bucket_id}/{object_id}'
    - set statuses.quarantined = now
    - unset exp

  - Trigger signal: `asset.quarantine.created`

---

## signal `asset.quarantine.created`

1. Receiver `swag/features/assets/signals/__init__.py::notify`

Push target: `presence-asset@{asset_id}`

2. Receiver `swag/features/assets/signals/__init__.py::trigger_asset_analyze`

SUMMARY: Trigger task docker steps, analyze assets, then upload **METADATA** artifact to `ASSETS_ARTIFACTS_BUCKET`

- Trigger Task `swag/features/assets/tasks/flows.py::analyze`
  - Fetch `Asset` by ID

  - ...if `asset.content_type` ~= "image/*"
    - Init asset.`Artifact` (label=SOURCE, content_type image/jpeg)
    - Init asset.`Artifact` (label=SOURCE_vips, content_type=image/jpeg)
    - Docker steps: 
        downloads (asset) 
        -> vips 
        -> ffprobe
        -> uploads a. metadata Artifact b. source_vips Artifact     (to `ASSETS_ARTIFACTS_BUCKET`)

  - ...elif `asset.content_type` is `application/pdf`
    - Init metadata asset.`Artifact` (label METADATA, content_type application/yaml)
    - Docker steps
        downloads (asset)
        -> pdfinfo
        -> uploads (metadata artifact)

  - ...else
    - Init asset.`Artifact` (label METADATA, content_type application/json)
    - Docker steps
        ffprobe (asset)
        -> uploads metadata artifact

---

## After METADATA Artifact uploaded

Receive pubsub signal, and specifically trigger downstream signal task `swag/features/assets/signals/__init__.py::approve_quarantined_asset_via_metadata`

### approve_quarantined_asset_via_metadata

SUMMARY: Verify ffprobe result, then save it to Assets.metadata and Message.assets.[id]

- result field in `ffprobe` / `pdfinfo` (based on content type)
- load `metadata` from bucket blob object

- !!!Update Asset:
  set `metadata.ffprobe` field with metadata

- trigger signal `asset.metadata.updated`
  -> Update `Message.assets`.[asset_id] fields, for sync
  (id, content_type, duration)
- IF NOT _should_approve
  - asset.failed
- ELSE: Task approve_asset

### approve_asset

SUMMARY: 1. update Asset status complete time 2. send `asset.completed`

- !!!Update Asset:
  - unset exp
  - statuses.completed = now !!!
- (return if statuses.completed already stamped)
- send `asset.completed`

### `asset.completed` Signal

Receivers:

- track_asset_events
- `notify`
  `asset.completed` event to `presence-asset@{asset_id}` channel
- auto_claim_from_metadata!!!

### Task `auto_claim_from_metadata`

SUMMARY: pluck auto_claim from asset metadata and trigger `asset.claim` signal

- Quick Hint: auto claim is made in
  - send_chat_message
  - create_post_from_livestream
  - create_clip_from_post

- collect auto_claim from passed metadata (from `Asset.metadata`)
- trigger `claim_asset` with claim_kwargs if sender is `asset.completed`
- !!!Update Asset:
  - unset `metadata.claim_id` of auto_claim (WHY)

---

## QUESTION: What if Asset Fail???

- `track_asset_events`
- `notify`
- `auto_claim_from_metadata`

- save_asset_failed_state
  SUMMARY: update asset.statuses fail-related field
  - Asset.`statuses.failed` = now
  - Asset.`statuses.failed_reasons` = reason_of_fail

### auto_claim_from_metadata

---

# Overview

Summary of asset processing:

1. POST API 建立 Asset Record, 並透過 pre-signed URL 上傳
2. 上傳完成後，透過 PubSub API，更新 Asset Object field
3. 觸發 analyze，透過 ffprobe 彙整 Asset metadata，建立 Artifact (label=METADATA) 並上傳
4. 上傳完成後，透過 PubSub API，load back Bucket 中的 METADATA
5. 根據 METADATA，定義 Asset 是否視為 approved 與 completed

Q:Statuses timestamp update in Asset:

- `statuses.created`
  when first uploaded
- `statuses.quarantined`
  when `handle_asset_quarantine_events_from_google_cloud_storage`
- `statuses.completed`
  when `approve_asset`
  - OR `statuses.failed`
    if any not pass _should_approve

---

Q: When is Asset considered "ready"?

A: Either posses `statuses.quarantined` or `statuses.completed` timestamp
