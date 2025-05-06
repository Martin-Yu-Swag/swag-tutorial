# Create Post: Trigger encode message

Artifact labels involved:

- video-sd-clear-h264
- video-sd-clear-watermarked-h264
- video-sd-blurred-watermarked-h264
- thumbnail-sd-clear-watermarked-h264
- thumbnail-sd-blurred-watermarked-h264

## `asset.claimed` -> `trigger_encode_message`

**NOTE**: For encode Image Asset

- process `image/*` asset claim

- Trigger task `encode_message`
  - asset_id
  - message_id
  - bundle_name = minimal
  - claim_id    = 'message-{message_id}:{index}'
  - watermark (not provided -> "default")

Task **encode_message**

- according to bundle name
  - encode_artifact_pattern = re.compile(r'-(?P<quality>sd)-')
  - package_artifact_pattern = re.compile(r'^(?P<artifact_type>(video(?=.*-watermarked))|audio)-(?P<quality>sd)-')

- Fetch `Asset` by id as asset
- fetch `User` by id as owner
- watermark_filename = "default"
- encode_outputs:
  - `asset.Artifacts` (label: content_type)
    - 'video-sd-clear-h264'                  : 'video/mp4'
    - 'video-sd-clear-watermarked-h264'      : 'video/mp4'
    - 'video-sd-blurred-watermarked-h264'    : 'video/mp4'
    - 'thumbnail-sd-clear-watermarked-h264'  : 'image/jpeg'
    - 'thumbnail-sd-blurred-watermarked-h264': 'image/jpeg'

- package_outputs (for drm)

- Execute `workflow`
  - asset_id
  - name = encode_message
  - context
    - message_id
    - claim_id
    - allow_existing_artifacts = True
    - bundle_name = minimal
    - asset_id
  - flows:
    - mkdir
    - downloads
    - encode_task
    - package_v2
    - pack and uploads
      - {asset.id}.message.tar
        -> asia.public.swag.live::messages/{message_id}/{asset.id}.tar
      - {asset.id}.assets.tar
        -> asia.contents.swag.live::assets/{asset.id}.tar
      (NOTE: GCP 上傳後 compressed tar 後 *可能* 會自動 untar)

- In workflow: Send Signal `workflow.started`
  - **args**
    - workflow = encode_message
    - asset_id
    - context
      - message_id
      - claim_id
      - allow_existing_artifacts = True
      - bundle_name              = minimal
      - asset_id
  - **receivers**
    - `trigger_message_processing_event`

- In workflow: Send Signal `workflow.completed`
  - **args**
    - workflow = encode_message
    - asset_id
    - context
      - message_id
      - claim_id
      - allow_existing_artifacts = True
      - bundle_name              = minimal
      - asset_id
  - **receivers**
    - trigger_asset_status_from_normalize **returned** 
    - auto_approve_asset_by_workflow **returned**
    - `trigger_message_processing_event`

### `workflow.started` -> `trigger_message_processing_event`

Send signal `message.processing.started`
- **args**
  - message_id
  - asset_id
- **receivers**
  - `update_message_asset_status`
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


### `workflow.completed` -> `trigger_message_processing_event`

Send signal `message.processing.completed`
- **args**
  - message_id
  - asset_id
- **receivers**
  - `update_message_asset_status`
    - !!!Update_one Message by id
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

- !!!Modify Message (new = True)
  - filter:
    - id
    - or
      - status_transitions__processing_completed = None
      - status_transitions__processing_completed lte now
  - modify
    - set__status_transitions__processing_completed = now
    - unset____status_transitions__processing_reason = True

- Send signal `status.updated`
  - **args**
    - user_id
    - message_id
    - status    = "processing.completed"
    - timestamp = now
    - reason    = None
    - current_status (list)
      - "processing.completed"
      - int(now_timestamp)
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

##### `status.updated` -> `trigger_draft_started`

- Send signal `draft.started`
  - **args**: message_id
  - **receivers**:
    - `update_message_status`

**update_message_status**

- Filter Message
  - or
    - assets__metadata__source__exists = True
    - tags                             = "draft"

- Trigger Task `creator_approve_message`
