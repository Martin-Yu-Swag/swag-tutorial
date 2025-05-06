# Create Post

Endpoint: [POST] `/posts`

Body

```json
{
    "title": "",
    "caption": "",
    "text": "",
    "categories": [""],
    "unlockPrice": 0,
    "assetIds": [
        "id"
    ],
    "ttl": "",
    "nbf": "",
    "includes": [""] // Set of user objectId
}
```

- init `Post.asset` as assets
  - id
  - content_type
  - duration = asset.metadata["ffprobe"]["format"]["duration"]

- Create `Post` as post
  - sender = g.user.id
  - caption = Message.Caption(text=caption) or None
  - nbf
  - exp = nbf + ttl
  - pricing = Message.Pricing(unlock_price)
  - assets = assets
  - hashtags.*
    (parsed from caption)
  - tags.*
    - *user_tags
    - flix (if all assets are video)
    - category:*
  - includes.*
  - metadata = Post.Metadata(ttl)

- Send Signal `post.created`
  - **args**
    - post_id
    - sender_id
    - asset_ids
  - **receivers**
    - `claim_post_assets`

NOTE:

- Define in Message Model, if object is created, then send `created` signal sender
  - **args**
    - message_id
  - **Receivers**
    - track_message_status
    - `trigger_draft_completed`

## `post.created` -> `claim_post_assets`

- for idx, asset in enumerate(asset_ids)
  - trigger Task `claim_asset`
    - claim_id = 'message-{message_id}:{index}'
    - asset_id

**claim_asset**

- !!!Update asset by id (new=True)
  - unset__exp = True
  - __raw__
    - $set: Asset._claims.{claim_id} = now

- Send signal `asset.claimed`
  - **args**
    - asset_id
    - owner_id
    - content_type
    - content_length
    - metadata
    - uri
    - claim_id = 'message-{message_id}:{index}'
    - claim_time = now
    - claim_metadata = None
  - **receivers**
    - track **returned**
    - trigger_generate_thumbnail_artifact **returned**
    - cleanup_previous_assets **returned**
    <!-- Above are for user_picture or user_background -->
    - copy_aup_to_assets_artifacts **returned** for message_aup
    - track_asset_events
    - [`trigger_encode_message`](./create_post_encode_image.md)
    - [`trigger_encode_gcp_transcoder`](./create_post_trigger_encode_gcp_transcoder.md)
    - [update_message_asset_metadata](#assetclaimed---update_message_asset_metadata)
    - [update_message_artifacts](#assetclaimed---update_message_artifacts)

### `asset.claimed` -> `update_message_asset_metadata`

- fetch Asset by id

- init `Message.Asset` as _asset
  - id           = asset.id
  - content_type = asset.content_type
  - duration     = asset.metadata[ffprobe][format][duration]

- !!!Update `Message` with UpdateOne
  - _id: message_id (parsed from claim_id)
  - array_filter:
    asset.id = _asset.id
  - `$set`:
    - `assets.asset.{field}`
      for field , value in _asset.to_mongo().items()
      (if value)

### `asset.claimed` -> `update_message_artifacts`

**SUMMARY**: copy message artifacts from asset artifacts
- sd.jpg
- sd-preview.jpg
- sd.mp4
- sd-preview.mp4

- ARTIFACT_LABELS:
  - "thumbnail"
  - "thumbnail-sd-clear-watermarked-h264"
  - "thumbnail-blurred"
  - "thumbnail-sd-blurred-watermarked-h264"
  - "trailer"
  - "trailer-10s-sd-clear-watermarked-h264"
  - "trailer-blurred"
  - "trailer-10s-sd-blurred-watermarked-h264"

- fetch `Asset` by id

- for message_claim in asset._claims:
  - parse message_id from claim_id
  - for `dest`, [labels] in SOURCES:
    `sd.jpg`        , ["thumbnail"        , "thumbnail-sd-clear-watermarked-h264"]
    `sd-preview.jpg`, ["thumbnail-blurred", "thumbnail-sd-blurred-watermarked-h264"]
    `sd.mp4'       `, ["trailer"          , "trailer-10s-sd-clear-watermarked-h264"]
    `sd-preview.mp4`, ["trailer-blurred"  , "trailer-10s-sd-blurred-watermarked-h264"]
    - proceed with asset.artifacts.[label] exist
    - trigger task `copy`
      - asset_id
      - label     = (one of exist labels)
      - dest      = gs://asia.public.swag.live/messages/{message_id}/{asset_id}/{destination}
      - overwrite = False

---

## `created` -> `trigger_draft_completed`

NOTE: 這裏目前好像不會觸發 (or 條件不符)

- Filter `Message`
  - or
    - assets__metadata__source__exists = True
    - tags                             = "draft"

- Trigger Task `creator_approve_message`
  - message_id

### `creator_approve_message`

- !!!Update `Message` by id
  - pull__tags = "draft"

- Send signal `draft.completed`
  - **args**: message_id
  - **receivers**:
    - track_message_status
    - `update_message_status`

#### `draft.completed` -> `update_message_status`

- !!!Update `Messages` (new = True)
  - filters:
    - id
    - status_transitions__draft_completed      = None
    - status_transitions__draft_completed__lte = now
  - modify
    - set__status_transitions__draft_completed = now
    - unset__status_transitions__draft_reason

- Send Signal `status.updated`
  - **args**
    - user_id
    - message_id
    - status         = "draft.completed"
    - timestamp      = now
    - reason         = None
    - current_status = list
      - `draft.completed`
      - int(now)
  - **receiver**
    - generate_creator_outbox_feed **returned**
    - send_session_voice_message **returned**
    - add_to_auto_voice **returned**
    - add_to_auto_message **returned**
    - disable_voice_message_on_review_failed **returned**
    - submit_message_for_review **returned**
    - trigger_draft_started **returned**
    - trigger_draft_completed **returned**
    - track_message_sent **returned**
    - `start_message_delivery`
    - `notify_message_status_updated`









## `created` -> `trigger_draft_completed`

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

