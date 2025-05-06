# PubSub Artifact Upload Callback

endpoint: [POST] `/notify/googlecloud/pubsub`

Body

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

- Send Signal `projects/swag-2c052/subscriptions/assets`
  - **args**
    - messageId   = messageId,
    - publishTime = dateutil.parser.parse(publishTime),
    - attributes  = attributes,
    - data
      - contentType
      - size
      - md5Hash
  - **receivers**
    - handle_asset_quarantine_events_from_google_cloud_storage **returned**
    - `handle_artifact_events_from_google_cloud_storage`

## `projects/swag-2c052/subscriptions/assets` -> `handle_artifact_events_from_google_cloud_storage`

- init `Asset` as `asset`
  - id (from parsed object_id: `assets/{asset_id}/{label}`)

- init `asset.Artifact` as artifact
  - label        = matched['label']
  - content_type = content_type
  - content_md5  = data.get('md5Hash')
  - statuses     = Asset.Artifact.Statuses(uploaded=now)

- !!!Update Asset by id (new = True)
  - set__artifacts__{artifact.label} = artifact

- Send Signal `artifact.uploaded`
  - **args**
    - asset_id     = asset.id,
    - owner_id     = asset.owner.id
    - label        = artifact.label
      (METADATA / SOURCE_vips)
    - content_type = artifact.content_type
  - **receivers**
    - copy_to_artifact_to_public **returned**
    - trigger_sync_message_artifacts_to_v3 **returned**
    - trigger_generate_artifacts **returned**
    - update_message_artifacts **returned**
    - `approve_quarantined_asset_via_metadata`
    - notify
      - event: artifact.uploaded
      - targets: "presence-asset@{asset_id}"

## `artifact.uploaded` -> `approve_quarantined_asset_via_metadata`

- init `Asset` as asset
  - id

- init `asset.Artifact` as artifact
  - label = "METADATA"
  - content_type = "application/json"
    - "application/json" if general asset
    - "application/yaml" if pdf

- field = ffprobe
  (pdfinfo if pdf)

- read artifact content from GCP blob as metadata

- !!!Update `Asset` by id: (new = True)
  - set__metadata__ffprobe = metadata

- fetch `User` as owner

- Send Signal `asset.metadata.updated`
  - **args**
    - asset_id       = asset.id
    - owner_id       = asset.owner.id
    - content_type   = asset.content_type
    - content_length = asset.content_length
    - metadata       = asset.metadata
  - **receivers**
    - update_message_asset_metadata
      loop through `asset._claims` to finish claim operation
      (Let's say asset is not claim yet)

- ...check is asset is valid based on metadata result
  - IF not valid: send signal `asset.failed`
    - **args**
      - asset_id       = asset.id,
      - owner_id       = asset.owner.id,
      - content_type   = asset.content_type,
      - content_length = asset.content_length,
      - metadata       = asset.metadata,
      - reasons        = [reason],
    - **receivers**
      - auto_claim_from_metadata **returned** for no auto-claim
      - track_asset_events
      - notify
      - `save_asset_failed_state`
        !!!Update Asset by id
        - set__statuses__failed
        - set__statuses__failed_reasons=reasons

- Trigger Task `approve_asset`
  - asset_id

## Task `approve_asset`

- !!!Update Asset by id (new=False)
  - unset__exp               = True
  - set__statuses__completed = now

- Send signal `asset.completed`
  - **args**
    - asset_id
    - owner_id
    - content_type
    - content_length
    - metadata
  - **receivers**
    - auto_claim_from_metadata **returned** for no auto-claim
    - track_asset_events
    - notify
      - event: `asset.completed`
      - target: "presence-asset@{asset_id}"
