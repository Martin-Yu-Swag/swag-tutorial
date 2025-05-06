# Create Post: Trigger Encode GCP Transcoder

Artifacts labels involved:

- trailer
- trailer-blurred
- SOURCE-blurred

## `asset.claimed` -> `trigger_encode_gcp_transcoder`

- process non `image/*` asset claim
  (video, audio)

- trigger Task `trigger_encode_v2`
  - message_id
  - asset_id

## trigger_encode_v2

- Send signal `message.processing.started`
  - **args**
    - message_id
    - asset_id
  - **receivers**
    - [`update_message_asset_status`](#processingstarted---update_message_status)

- Trigger serial task:
  - [`trigger_upload_custom_thumbnail`](#trigger_upload_custom_thumbnail)
    - asset_id
    - message_id
  - [`trigger_encode_trailer`](#trigger_encode_trailer)
    - asset_id
    - message_id
  - [`trigger_encode_blurred_source`](#trigger_encode_blurred_source)
    - asset_id
    - message_id
  - [`trigger_encode_gcp_transcoder_cloud_run`](#trigger_encode_gcp_transcoder_cloud_run)
    - asset_id
    - message_id

### `message.processing.started` -> `update_message_asset_status`

- !!!Update_one Message by id
  - array_filters
    - $and
      - asset.id = asset_id
      - $or
        - asset.status_transitions.processing_started = None
        - asset.status_transitions.processing_started: $lt now
  - update
    - $set
      - assets.$[asset].status_transitions.processing_started = now
      - assets.$[asset].status_transitions.processing_reason = None
    - $unset
      - assets.$[asset].status_transitions.processing_completed = True

- IF this is the first asset in msg that processing.started:
  Send Signal `processing.started`
  - **args**
    - message_id
    - timestamp = now
    - reason = None
  - **receivers**
    - track_message_status
    - `update_message_status`

#### `processing.started` -> `update_message_status`

- !!!Modify Message (new = True)
  - filter:
    - id
    - or
      - status_transitions__processing_started = None
      - status_transitions__processing_started lte now
  - modify
    - set__status_transitions__processing_started = now
    - unset____status_transitions__processing_reason = True

- Send signal `status.updated`
  - **args**
    - user_id
    - message_id
    - status    = "processing.started"
    - timestamp = now
    - reason    = None
    - current_status (list)
      - "processing.started"
      - int(now_timestamp)
  - **receivers**
    - generate_creator_outbox_feed **returned**
    - send_session_voice_message **returned**
    - add_to_auto_voice **returned**
    - add_to_auto_message **returned**
    - disable_voice_message_on_review_failed **returned**
    - start_message_delivery **returned**
    - submit_message_for_review **returned**
    - trigger_draft_started **returned**
    - trigger_draft_completed **returned**
    - track_message_sent **returned**
    - `notify_message_status_updated`
      - notify
        - targets: 'presence-message@{message_id}'
        - event: `processing.started`
      - notify
        - targets: 'presence-user@{user_id}'
        - event: `message.processing.started`

---

## `trigger_upload_custom_thumbnail`

- fetch Asset by id

- proceed if asset.artifacts["thumbnail"] as custom_thumbnail
  (Which means this asset **already encoded**)

- Trigger Task `rewrite`
  - bucket_id        = 'asia.public.swag.live',
  - object_id        = f'messages_v3/{message_id}/{asset_id}/poster.jpg',
  - source_bucket_id = custom_thumbnail.uri.host,
  - source_object_id = custom_thumbnail.uri.path.removeprefix('/'),

## `trigger_encode_trailer`

- fetch Asset by id

- ...IF if asset.artifacts["trailer"] as custom_trailer
  Trigger Task `rewrite`
  - bucket_id        = 'asia.public.swag.live',
  - object_id        = f'messages_v3/{message_id}/{asset_id}/trailer.mp4',
  - source_bucket_id = custom_trailer.uri.host,
  - source_object_id = custom_trailer.uri.path.removeprefix('/'),

- ...ELSE trigger Task `trigger_encode_trailer_cloud_run`
  - asset_id
  - message_id

### Task `trigger_encode_trailer_cloud_run`

- fetch `Asset` by id

- init `asset.Artifact` as trailer_artifact
  - label        = 'trailer'
  - content_type = 'video/mp4'
- Trigger cloudrun task `trailer_generation`
  - download_url = asset.get_download_url()
  - upload_url   = trailer_artifact.get_upload_url
    (ASSETS_ARTIFACTS_BUCKET)

- init `asset.Artifact` as blurred_trailer_artifact
  - label        = 'trailer-blurred'
  - content_type = 'video/mp4'
- Trigger cloudrun task `video_blurrer`
  - download_url = trailer_artifact.get_download_url()
  - upload_url   = blurred_trailer_artifact.get_upload_url()
    (ASSETS_ARTIFACTS_BUCKET)

## `trigger_encode_blurred_source`

- fetch `Asset` by id

- init `asset.Artifact` as blurred_artifact
  - label        = 'SOURCE-blurred'
  - content_type = 'video/mp4'

- Trigger cloudrun task `video_blurrer`
  - download_url = asset.get_download_url(),
  - upload_url   = blurred_artifact.get_upload_url(),

- Trigger task `transcoder_v1.create_job`
  - parent = f'projects/{project_number}/locations/{location}'
  - job = transcoder_v1.Job()
    - input_uri  = blurred_artifact.uri.to_text()
    - output_uri = f'gs://asia.public.swag.live/messages_v3/{message_id}/{asset_id}/'

## `trigger_encode_gcp_transcoder_cloud_run`

- fetch `Asset` by id

- drm_keys = drm.tasks.generate_keys_by_kids
  - content_id=message_id

- get video_stream from asset.streams_by_codec_type.get('video')
  - video_height = video_stream['height']
  - video_width  = video_stream['width']

- get audio_stream from asset.streams_by_codec_type.get('audio')
  - audio_stream_index    = audio_stream['index']
  - audio_stream_channels = audio_stream['channels']

- fetch `User` by id

- execute cloudrun task `encode_message`
  (see [github](https://github.com/swaglive/swag.cloudrun.message-transcode/blob/main/main.py))
  - message_id
  - asset_id
  - source_uri            = asset.uri.to_text(),
  - total_duration        = int(asset.metadata[ffprobe][format][duration]),
  - drm_kid               = drm_kid,
  - drm_key               = drm_key,
  - drm_iv                = drm_iv,
  - video_height          = video_height,
  - video_width           = video_width,
  - include_video_presets = None,  (if exist video)
  - include_audio_presets = None,  (if exist audio)
  - audio_stream_index    = audio_stream_index,
  - audio_stream_channels = audio_stream_channels,
  - variant               = None (if user has beta tags, than `beta`)
