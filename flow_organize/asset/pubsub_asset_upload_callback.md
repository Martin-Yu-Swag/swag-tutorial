# PubSub Asset Upload Callback

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
      - content_type
      - size
      - md5Hash
  - **receivers**
    - handle_artifact_events_from_google_cloud_storage **returned** not artifact
    - `handle_asset_quarantine_events_from_google_cloud_storage`

## `projects/swag-2c052/subscriptions/assets` -> `handle_asset_quarantine_events_from_google_cloud_storage`

- Handle pubsub `OBJECT_FINALIZE` from QUARANTINE_BUCKET

- !!!Update Asset by id (new=True)
  - set__content_type          = data['contentType']
  - set__content_length        = data['size']
  - set__content_md5           = data['md5Hash']
  - set__storage__quarantine   = 'gs://{bucket_id}/{object_id}'
  - set__statuses__quarantined = now
  - unset__exp                 = True

- Send Signal `asset.quarantine.created`
  - **args**
    - asset_id
    - owner_id
    - content_type
    - content_length
    - metadata
  - **receivers**
    - `trigger_asset_analyze`
    - notify
      - event: "asset.quarantine.created"
      - targets: "presence-asset@{asset_id}"

## `asset.quarantine.created` -> `trigger_asset_analyze`

- Trigger Task analyze
  - asset_id

Task `analyze`

- fetch asset by id

- Init asset.Artifact as artifact
  - label='METADATA'
  - content_type='application/json'

- ...If asset is `image/*`
  - init asset.Artifact as source
    - label='SOURCE'
    - content_type='image/jpeg'
  - init asset.Artifact as source_vips
    - label='SOURCE_vips'
    - content_type='image/jpeg'
  - docker steps: 
    - downloads
    - vips
    - ffprobe
    - uploads (artifact, source_vips)

- ...ELIF asset is application/pdf
  (NOTE: 如果上傳影片，可 optionally 上傳版權說明 -> 通常是 pdf)

  - Init asset.Artifact as artifact
    - label='METADATA'
    - content_type='application/yaml'
  - docker steps:
    - downloads
    - pdfinfo
    - uploads (artifact)

- ...ELSE
  - docker steps:
    - ffprobe
    - uploads (artifact)

- Run docker Workflow

## workflow

- Before workflow task, send signal `workflow.started`
  - **args**
    - workflow = "analyze"
    - asset_id
    - context
      - label: METADATA
      - uri = artifact.uri
  - **receivers**
    - trigger_message_processing_event **returned**

- After workflow task, send signal `workflow.completed`
  - **args**
    - workflow = "analyze"
    - asset_id
    - context
      - label: METADATA
      - uri = artifact.uri
  - **receivers**
    - trigger_message_processing_event **returned**
    - trigger_asset_status_from_normalize **returned**
    - auto_approve_asset_by_workflow **returned**
