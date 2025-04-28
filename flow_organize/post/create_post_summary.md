# Create Post Summary

## POST /posts

- payload

```json
{
    "title": "",
    "caption": "",
    "text": "",
    "categories": [""],
    "unlock_price": 0,
    "assetIds": [
        "id"
    ],
    "ttl": "",
    "nbf": "",
    "includes": [""] // Set of user objectId
}
```

- init `Post.asset` with `id`, `content_type`, `duration` (`metadata.ffprobe.format.duration`)
- Create Post
- Send signal `post.created` sender, trigger only receiver `claim_post_assets`
- Return Post response

NOTE:

Define in Message Model, if object is created, then send `created` signal sender

Receivers

- `track_message_status`: trigger `analytics.tasks.track` task
- `trigger_draft_completed`

### `trigger_draft_completed`

- Skip auto approving for messages with `assets.metadata.source` exist.
- trigger `creator_approve_message` Task
  - send `draft.completed` sender signal
    receivers:
    - `track_message_status`: trigger `analytics.
    - `update_message_status`
      with arg `message_id` only

### `draft.completed` -> `update_message_status`

- !!!Update Message:
  - set `status_transitions.draft_completed` timestamp

- send `status.updated` sender signal
  Receivers:
  - `generate_creator_outbox_feed` (returned)
  - `send_session_voice_message` (returned)
  - `add_to_auto_voice` (returned)
  - `add_to_auto_message` (returned)
  - `disable_voice_message_on_review_failed` (returned)
  - `track_message_sent` (returned)
  - `trigger_draft_completed` (returned)
  - `submit_message_for_review` (returned)
  - `trigger_draft_started` (proceed only after `processing.completed`, return)
  - `notify_message_status_updated`: trigger notify
  - `start_message_delivery` (proceed only after `status_transitions.processing_completed` exist, return)

Receiver `start_message_delivery`

- proceed with following status:
  - draft.completed (YES)
  - processing.completed
  - review.completed

- Trigger Task `deliver_message`
  - filter message by:
    - message_id
    - `nbf` None or passed
    - `posted_at` None
    - `status_transitions.draft_completed` exist
    - `status_transitions.processing_completed` exist
    - `status_transitions.processing_reason` DONT exist
  - SINCE i haven't reach `processing_completed` yet, so take this signal as stopping here...

END OF SIGNAL

---

## `claim_post_assets`

Trigger `assets.tasks.claim_asset` Task with
- claim_id from `Claims.message` formatted
  (`message-{message_id}:{index}`) which index = idx number of asset in list
- asset_id

## `claim_asset`

- !!!Update `Asset`:
  - unset exp
  - set Asset._claims.{claim_id} = now

- Send `asset.claimed` sender signal with bunch of asset fields and claim_id, claim_time
    Receivers                            : 
  - `copy_aup_to_assets_artifacts`       : (returned, for `Claims.message_aup`)
  - `cleanup_previous_assets`            : (returned, for `Claims.user_picture`, `Claims.user_background`)
  - `trigger_generate_thumbnail_artifact`: (returned, for `Claims.user_picture`, `Claims.user_background`)
  - `track`                              : (returned, for `Claims.user_picture`, `Claims.user_background`)
  - `track_asset_events`                 : trigger `analytics.tasks.track` task
  - `update_message_asset_metadata`      : !!!Update: set Message.assets.{idx}.[id, content_type, duration]
  - `update_message_artifacts`           : copy Asset file with message_claim to storage `gs://asia.public.swag.live/messages/{message_id}/{asset_id}/{destination}`
  - `trigger_encode_message`             : encode Claim.message with image-type asset (NOTE)
  - `trigger_encode_gcp_transcoder`      : encode Claim.message with non-img-type asset (NOTE)

## Signal `asset.claimed`

### Receiver `update_message_asset_metadata`

- fetch `Asset` by asset_id
- Init Message.Asset with [id,content_type,duration]
- !!!Update Message with bulk_write

END OF SIGNAL

### Receiver `update_message_artifacts`

SUMMARY: This is for re-used Asset or freshly-uploaded artifact, where Artifact is already prepared and recorded in `asset.artifacts`, so just copy it from storage

- fetch `Asset` by asset_id

- proceed if Assets has labeled artifact:
  possible labels (dest):
  - thumbnail (sd.jpg)
  - thumbnail-sd-clear-watermarked-h264 (sd.jpg)
  - thumbnail-blurred (sd-preview.jpg)
  - thumbnail-sd-blurred-watermarked-h264 (sd-preview.jpg)
  - trailer (sd.mp4 )
  - trailer-10s-sd-clear-watermarked-h264 (sd.mp4 )
  - trailer-blurred (sd-preview.mp4)
  - trailer-10s-sd-blurred-watermarked-h264 (sd-preview.mp4)

- lopping through `asset._claims` to get `message_id`:
  - Copy asset content to 'gs://asia.public.swag.live/messages/{message_id}/{asset_id}/{destination}'

### Receiver `trigger_encode_message`

- only proceed with:
  - Claims.message
  - asset.content_type = image
- collect task_kwargs:
  - asset_id, message_id, claim_id
  - bundle_name = 'minimal'
  - watermark = metadata['watermark'] (IF EXIST)
- Trigger `encode_message` Task

#### Task `encode_message`

SUMMARY: Encode video/audio asset, the result will be `Artifact`. Whole process is run by docker

- Collect param:
  - encode_artifact_pattern, package_artifact_pattern (by bundle_name)
  - asset (by asset_id)
  - owner (by asset.owner_id)
  - duration (by asset.metadata.ffprobe.format.duration)
  - watermark_filename (by watermark or 'blank')
- Create watermark content from jinja env template ('assets/watermarks/{watermark_filename}.svg)
- acquire encode_outputs Dict (`Artifact`, preset)
  - get `stream` based on asset.streams_by_codec_type, which is from asset.metadata.ffprobe.streams
    (return if no stream)
  - !!!NOTE!!!: image's streams_by_codec_type is "video"

  - create series of artifacts(label: content-type) Dict based on codec_type and preset
    eg: codec_type=video, preset=VIDEO_SD
      - video-sd-clear-h264                        : video/mp4
      - video-sd-clear-watermarked-h264            : video/mp4
      - video-sd-blurred-watermarked-h264          : video/mp4
      - thumbnail-video-sd-clear-watermarked-h264  : image/jpeg
      - thumbnail-video-sd-blurred-watermarked-h264: image/jpeg
      (IF duration > 3 min)
      - trailer-10s-video-sd-clear-watermarked-h264: video/mp4
      - trailer-10s-video-sd-blurred-watermarked-h264: video/mp4
  - Init asset.`Artifact`(label=label, content_type=content_type)
  - yield `Artifact`, preset

- acquire package_outputs based on encode_outputs' `Artifacts` (For DRM keys generation)

- Docker flow to encode (by `ffmpeg`)

- Finally upload content to (bucket-name::object-id)
  - `asia.public.swag.live::messages/{message_id}/{asset.id}.tar`
  - `asia.contents.swag.live::assets/{asset.id}.tar`

END OF ACTION

### Receiver `trigger_encode_gcp_transcoder`

SUMMARY: filter out image/* asset and trigger gcp encode task

- proceed only with
  - Claims.message
  - content_type NOT `image/*`
- Trigger `trigger_encode_v2` with
  - message_id
  - asset_id

#### trigger_encode_v2

- Send signal `message.processing.started` with
  - message_id
  - asset_id
- Trigger following tasks with same params: 
  - `trigger_upload_custom_thumbnail`        : rewrite if artifact `thumbnail` exist
  - `trigger_encode_trailer`                 : For video > 3 min, generate Artifact(label=`trailer`) & Artifact(label=`trailer-blurred`)
  - `trigger_encode_blurred_source`          : For video < 1 min, generate Artifact(label=`SOURCE-blurred`) & transcode SOURCE-blurred object
  - `trigger_encode_gcp_transcoder_cloud_run`: prepare drm, encode message asset 
  - IF EXCEPTION catch:
    Send signal `message.processing.failed` with
    - message_id
    - asset_id

**trigger_upload_custom_thumbnail**

- fetch asset by asset_id
- ...IF asset DONT have 'thumbnail' labeled artifact -> returned
- ...trigger rewrite to `asia.public.swag.live::messages_v3/{message_id}/{asset_id}/poster.jpg`

**trigger_encode_trailer**

SUMMARY: encode `trailer` and `trailer-blurred` Artifact for asset > 3 min

- fetch asset by asset_id
- ...IF has `trailer` labeled artifact -> rewrite to `asia.public.swag.live::messages_v3/{message_id}/{asset_id}/trailer.mp4`
- ...ELSE trigger `trigger_encode_trailer_cloud_run`
  - fetch asset
  - proceed with
    - `asset.streams_by_codec_type` has video
    - `asset.metadata.ffprobe.format.duration` >= 3
  - init asset.`Asset`(label="trailer", content_type="video/mp4")
  - trigger `trailer_generation` task (source: asset url)
    -> init CloudRun job
  - init asset.`Asset`(label="trailer-blurred", content_type="video/mp4")
  - trigger `video_blurrer` (source: trailer_artifact)
    -> init CloudRun job

**trigger_encode_blurred_source**

SUMMARY: encode `SOURCE-blurred` Artifact with asset < 1 min

- fetch asset by asset_id
- proceed with
  - `asset.streams_by_codec_type` has video
  - `asset.metadata.ffprobe.format.duration` < 1 min
- init asset.`Artifact` (label='SOURCE-blurred', content_type='video/mp4')
- trigger `video_blurrer` (source: asset.get_download_url)
- prepare param for `transcoder_v1.create_job` -> transcode video
  - video_es, audio_es (ElementaryStream) key = "[video|audio]-sd-blurred"
  - video_ms, audio_ms (MuxStream)
  - Manifest (blurred.m3u8, blurred.mpd)
  - input source: `blurred_artifact.uri.to_text`
  - output source: `asia.public.swag.live::messages_v3/{message_id}/{asset_id}`

**trigger_encode_gcp_transcoder_cloud_run**

- fetch `Asset` by asset_id
- generate drm_keys through `drm.tasks.generate_keys_by_kids`
- IF asset has video stream:
  - set video_height, video_width, and adopt default include_video_presets setting
- IF asset has audio stream:
  - set audio_stream_index, audio_stream_channels, and adopt default include_audio_presets setting
- fetch `User` by `asset.owner_id`
- trigger Task `googlecloud.cloudrun.tasks.encode_message` with
  - asset_id, message_id
  - source_uri = asset.uri
  - drm-related field
  - video, audio related field

##### Signal `message.processing.started`

Only Receiver: `update_message_asset_status`

- !!!UPDATE Message: (by message_id)
  - set `assets.$[asset].status_transitions.processing.started` = now
  - set `assets.$[asset].status_transitions.processing_reason` = None
  - unset `assets.$[asset].status_transitions.processing_completed`
- Looping message.assets to check whether to escape
  - IF there's already other asset been processing-started -> return
- Send signal `processing.started`

##### Signal `processing.started`

Receiver `track_message_status`

- trigger Task `analytics.tasks.track`

Receiver `update_message_status`

- !!!UPDATE Message:
  - set `message.status_transitions.processing_started` = now
- Send signal `status.updated`

##### Signal `status.updated`

Receiver `notify_message_status_updated`: notify

RETURNED:
Receiver `generate_creator_outbox_feed` (proceed only with `draft.started` sender, returned)
Receiver `send_session_voice_message` (return)
Receiver `add_to_auto_voice` (return)
Receiver `add_to_auto_message` (proceed only with `delivery.started` sender, returned)
Receiver `disable_voice_message_on_review_failed` (proceed only with `review.failed`, returned)
Receiver `trigger_draft_started` (trigger only after `processing.completed`, return)
Receiver `track_message_sent` (proceed only with `delivery.completed`, returned)
Receiver `trigger_draft_completed` (proceed only with `draft.started`, returned)
Receiver `submit_message_for_review` (proceed only with `delivery.completed`, returned)
Receiver `start_message_delivery` (not required status, returned)

END OF SIGNAL `message.processing.started` -> `processing.started` -> `status.updated`

---

## Upload Callback `/notify/googlecloud/pubsub`

- Parse related field from payload
  - subscription
  - message.messageId
  - message.publishTime
  - message.attributes
  - message.data

- Send signal with subscription sender and args:
  - messageId
  - publishTime
  - attributes
  - data

Receivers:

- `handle_asset_quarantine_events_from_google_cloud_storage`
  (for object PubSub from quarantine bucket, returned)

- `handle_artifact_events_from_google_cloud_storage`

- `handle_events_from_google_cloud_transcoder`

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

