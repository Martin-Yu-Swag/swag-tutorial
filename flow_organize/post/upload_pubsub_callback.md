# Upload Pubsub Callback

## artifact uploads

Possible labels from artifact buckets:

- Video assets
  - trailer
  - trailer-blurred
  - SOURCE-blurred
- Image assets
  - video-sd-clear-h264
  - video-sd-clear-watermarked-h264
  - video-sd-blurred-watermarked-h264
  - thumbnail-sd-clear-watermarked-h264
  - thumbnail-sd-blurred-watermarked-h264

Endpoint `/notify/googlecloud/pubsub`

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
    - handle_asset_quarantine_events_from_google_cloud_storage **returned**
    - `handle_artifact_events_from_google_cloud_storage`

## `handle_artifact_events_from_google_cloud_storage`

- init `asset.Artifact` as artifact
  - label (parsed from object_id)
  - content_type
  - content_md5
  - statuses = Asset.Artifact.Statuses(uploaded=now)

- !!!Update asset by id (new = True)
  - set__artifacts__{label}: artifact

- Send signal `artifact.uploaded`
  - **args**
    - asset_id
    - owner_id
    - label
    - content_type
  - **receivers**
    - copy_to_artifact_to_public **returned**
    (Above: for user_picture, user_background claims)
    - trigger_generate_artifacts **returned**
    - approve_quarantined_asset_via_metadata **returned**
    (for self-uploaded artifacts)
    - `trigger_sync_message_artifacts_to_v3`
    - `update_message_artifacts`
    - notify
      - event: artifact.uploaded
      - targets: "presence-asset@{asset_id}"

### `artifact.uploaded` -> `trigger_sync_message_artifacts_to_v3`

- trigger Task `sync_message_artifacts_to_v3`
  - asset_id
  - label

**sync_message_artifacts_to_v3**

- proceed with `thumbnail` or `tailer` label
  (in this case: `tailer`)

- fetch `Asset` by id

- artifact = asset["tailer"]

- for message_claims in asset._claims
  - message_id parsed from message_claims
  - trigger task `rewrite`
    - bucket_id        = 'asia.public.swag.live'
    - object_id        = f'messages_v3/{message_id}/{asset_id}/{target}'
    - source_bucket_id = artifact.uri.host
    - source_object_id = artifact.uri.path.removeprefix('/')

### `artifact.uploaded` -> `update_message_artifacts`

- proceed with following labels
  (video)
  - tailer
  - tailer-blurred
  (image)
  - thumbnail-sd-clear-watermarked-h264
  - thumbnail-sd-blurred-watermarked-h264

- fetch asset by id

- for message_claims in asset._claims
  - parsed message_id from claim
  - trigger task copy (for each `label` scenario):
    - `tailer`
      - destination = f'gs://asia.public.swag.live/messages/{message_id}/{asset_id}/sd.mp4',
      - overwrite   = True
    - `tailer-blurred`
      - destination = f'gs://asia.public.swag.live/messages/{message_id}/{asset_id}/sd-preview.mp4',
      - overwrite   = True
    - `thumbnail-sd-clear-watermarked-h264`
      - destination = f'gs://asia.public.swag.live/messages/{message_id}/{asset_id}/sd.jpg',
      - overwrite   = False
    - `thumbnail-sd-blurred-watermarked-h264`
      - destination = f'gs://asia.public.swag.live/messages/{message_id}/{asset_id}/sd-preview.jpg',
      - overwrite   = False
    
---

## encode message results

Init from Task: `trigger_encode_gcp_transcoder_cloud_run`

From cloudrun workflow
- https://github.com/swaglive/swag.cloudrun.message-transcode/blob/main/main.py

- Send Signal `projects/swag-2c052/subscriptions/encode-message-results`
  - **args**
    - messageId   = messageId,
    - publishTime = dateutil.parser.parse(publishTime),
    - attributes  = attributes,
    - data
      - content_type
      - size
      - md5Hash
  - **receivers**
    - `handle_events_from_google_cloud_transcoder`

### Receiver `handle_events_from_google_cloud_transcoder`

Send signal `message.processing.completed`

- **args**
  - message_id
  - asset_id
- **receivers**
  - `update_message_asset_status`
    - !!!Update_one `Message` by id
      - array_filters
        - $and
          - asset.id = asset_id
          - $or
            - asset.status_transitions.processing_completed = None
            - asset.status_transitions.processing_completed: $lt now
      - update
        - $set
          - assets.$[asset].status_transitions.processing_completed = now
          - assets.$[asset].status_transitions.processing_reason    = None

    - IF all assets is processing.completed
      Send Signal `processing.completed`
      - **args**
        - message_id
        - timestamp = now
        - reason = None
      - **receivers**
        - track_message_status
        - `update_message_status`

#### `processing.completed` -> `update_message_status`

- !!!Modify `Message` (new = True)
  - filter:
    - id
    - or
      - status_transitions__processing_completed = None
      - status_transitions__processing_completed lte now
  - modify
    - set__status_transitions__processing_completed = now
    - unset__status_transitions__processing_reason = True

- Send signal `status.updated`
  - **args**
    - user_id
    - message_id
    - status
    - timestamp
    - reason
    - current_status
  - **receivers**
    - generate_creator_outbox_feed **returned**
    - send_session_voice_message **returned**
    - add_to_auto_voice **returned**
    - add_to_auto_message **returned**
    - disable_voice_message_on_review_failed **returned**
    - start_message_delivery **returned**
    - submit_message_for_review **returned**
    - trigger_draft_completed **returned**
    - track_message_sent **returned**
    - `trigger_draft_started`
    - `notify_message_status_updated`
      - notify
        - targets: 'presence-message@{message_id}'
        - event: `processing.completed`
      - notify
        - targets: 'presence-user@{user_id}'
        - event: `message.processing.completed`









### subscription `assets` -> handle_artifact_events_from_google_cloud_storage

- parse required data
  - attributes.eventType
  - attributes.bucketId
  - attributes.objectId
  - data.contentType

- proceed only when
  - bucketId match re_ARTIFACTS_BUCKET
  - objectId match Paths.artifact (asset_id,label)

- fetch `asset` by asset_id

- init asset.`Artifact`
  - label
  - content_type
  - content_md5 (data.md5Hash)
  - statuses (Asset.Artifact.Statuses(uploaded=now))

- !!!Update asset:
  - set artifacts.[label] = init artifact

- Send signal `artifact.uploaded` sender with
  - asset_id
  - owner_id
  - label
  - content_type

Receivers:

- `approve_quarantined_asset_via_metadata` (only for METADATA artifact, returned)
- `notify`
- `trigger_generate_artifacts`: generate thumbnail and trailer from uploaded entrypoint artifact (`_thumbnail`, `_trailer`)
- `update_message_artifacts`: after artifact upload, copy to message public storage dir based on asset's claims
- `copy_to_artifact_to_public`
- `trigger_sync_message_artifacts_to_v3`

#### `artifact.uploaded` -> trigger_generate_artifacts

SUMMARY: Generate thumbnail and trailer from uploaded entrypoint artifact

- proceed only when label in (`_thumbnail`, `_trailer`)
  NOTE: `_thumbnail`, `_trailer` is derived from API endpoint `swag/features/assets/endpoints.py::upload_artifact`

- Trigger following task according to the label:
  - generate_thumbnail_artifact
  - generate_trailer_artifact

**generate_thumbnail_artifact**

- Generate `thumbnail` and `thumbnail-blurred` image from source `_thumbnail` and upload with Docker flow

**generate_trailer_artifact**

- Generate `trailer` and `trailer-blurred` video from source `_trailer` and upload with Docker flow

#### `artifact.uploaded` -> update_message_artifacts

SUMMARY: after artifact upload, copy to message public storage based on asset's claims

- proceed with following label (label (destination)):
  - thumbnail (sd.jpg)
  - thumbnail-sd-clear-watermarked-h264 (sd.jpg)
  - thumbnail-blurred (sd-preview.jpg)
  - thumbnail-sd-blurred-watermarked-h264 (sd-preview.jpg)
  - trailer (sd.mp4 )
  - trailer-10s-sd-clear-watermarked-h264 (sd.mp4 )
  - trailer-blurred (sd-preview.mp4)
  - trailer-10s-sd-blurred-watermarked-h264 (sd-preview.mp4)

- fetch Asset by asset_id

- loop message_id through asset._claims (Claims.message):
  - ...IF label in aforementioned & posses `asset.artifact[label]`
    - re-write to `gs://asia.public.swag.live/messages/{message_id}/{asset_id}/{destination}`

#### `artifact.uploaded` -> trigger_sync_message_artifacts_to_v3

SUMMARY: rewrite thumbnail & trailer labeled artifact to bucket `asia.public.swag.live`:

- `messages_v3/{message_id}/{asset_id}/poster.js`
- `messages_v3/{message_id}/{asset_id}/trailer.mp4`

- Trigger Task `sync_message_artifacts_to_v3` with
  - asset_id
  - label

In `sync_message_artifacts_to_v3`

- proceed with one of labels:
  - `thumbnail` -> target = `poster.jpg`
  - `trailer` -> target = `trailer.mp4`

- Fetch asset by asset_id

- Init asset.artifacts[label]

- looping through `asset._claims` to find matched `Claims.message`:
  - parse message_id from claim
  - rewrite to `asia.public.swag.live::messages_v3/{message_id}/{asset_id}/{target}`

### subscription `encode-message-results` -> handle_events_from_google_cloud_transcoder

- with args:
  - attributes
  - data

- parse required fields:
  - event = attributes.event (`completed` / `fail`)
  - message_id = attributes.message_id
  - asset_id = attributes.asset_id

- Sending `features.asset` signal with sender `message.processing.completed`
  Receivers:
  - update_message_asset_status

#### `message.processing.completed` -> update_message_asset_status

- !!!Update `Message.asset.{asset_id}.status_transitions.processing_completed` = now

- IF ALL message.asset is processing completed
  -> send `features.message` signal with sender `processing.completed`
  Receivers:
  - track_message_status: Trigger Task `analytics.tasks.track` 
  - update_message_status
    - !!!Update: TIMESTAMPED `Message.status_transitions.processing_completed`
    - Trigger `status.updated`

---

## Overview

Message status change

1. When create post, trigger `on_post_save` signal
  -> trigger following `update_message_status`
  -> TIMESTAMPED `status_transitions.draft_completed`

2. When send `asset.claimed` signal
  -> `trigger_encode_gcp_transcoder`
  -> send `message.processing.started` signal
  -> receiver `update_message_asset_status`
  -> TIMESTAMPED `assets.$[asset].status_transitions.processing`
  -> send following `processing.started` (If is first asset enter processing)
  -> receiver `update_message_status`
  -> TIMESTAMPED `status_transitions.processing_started`

(Asset status change)
3. When receive bucket OBJECT_FINALIZE notify callback
  -> In `handle_artifact_events_from_google_cloud_storage`
  -> TIMESTAMPED `assets.artifacts.[label].statuses.uploaded`

4. When receive bucket OBJECT_FINALIZE notify callback
  -> In `handle_events_from_google_cloud_transcoder`, trigger `message.processing.completed`
  -> In `update_message_asset_status`
  -> TIMESTAMPED `message.asset.[asset_id].status_transitions.processing_completed`

5. After `update_message_asset_status`, if "All" message's artifacts are status processing_completed
  -> Trigger message signal `processing_completed`
  -> TIMESTAMPED `status_transitions.processing_completed`

---

Concept of idempotent:

- Update Post.Asset.[id,content_type,duration] in several part?
  - create_post
  - update_message_asset_metadata

---

If Asset video > 3 min:
  - create `trailer` Artifact
  - create `trailer-blurred` Artifact
else
  - create `SOURCE-blurred` Artifact

---

Quick note:

目前的 voice-related service:
- 個人私訊 
- 直播結束後，直播主群發 voice message (`create_voice_message`)

---

Question:

How does `poster.jpg` thumbnail, `trailer.mp4` create?

A: After artifact uploaded, pubsub callback trigger `handle_artifact_events_from_google_cloud_storage` and further ``artifact_uploaded`.

In `trigger_sync_message_artifacts_to_v3`, for artifact "thumbnail" and "trailer", rewrite to `asia.public.swag.live::messages_v3/{message_id}/{asset_id}/{target}`, where message_id is parsed from `asset._claims`.

---