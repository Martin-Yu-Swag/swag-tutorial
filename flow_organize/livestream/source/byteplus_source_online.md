# Byteplus Source Online

Endpoint: [POST] `/notify/byteplus`

Body:

- EventType (eg.) -> `UserVideoStreamStart`
  - UserAudioStreamStart / UserAudioStreamStop
  - UserVideoStreamStart / UserVideoStreamStop
  - UserJoinRoom / UserLeaveRoom
- EventData
- EventTime
- EventId
- AppId
- Version

func `notify` flow:

- Send Signal sender `UserVideoStreamStart`
  - **args**:
    - EventTime
    - EventId
    - AppId
    - Version
    - **EventData (dict)
      - RoomId
      - UserId
      - Timestamp
  - **receivers**:
    - `trigger_stream_source_online`

## `UserVideoStreamStart` -> `trigger_stream_source_online`

- var now = datetime.datetime.utcfromtimestamp(int(Timestamp) / 1000)

- fetch `Session` by RoomId

- fetch `User` by session.user as streamer

- token = streamer.tokens[UserId]
  (this should be JWT auth)

- init `Sources.Source` as source
  - id = UserId (type uuid)
  - statuses = `Sources.Source.Statuses`
    - started = now
    - publishing_started = now
  - metadata
    - session_id = RoomId
    - flavor = first
      - token.metadata.flavor
      - token.metadata.user_agent.flavor
    - provider = "byteplus"
    - provider_info
      - rtc
        - RoomId
        - room_id
      - media_live
        - base_url = BYTEPLUS_MEDIA_LIVE_PULL_URL
        - app_name = BYTEPLUS_MEDIA_LIVE_APP_NAME
        - stream_name = streamer.id

- !!!upsert Sources (new = False) as sources_doc
  - filter: user = streamer.id
  - modify
    - set__sources__{source.id}__id                           = source.id
    - set__sources__{source.id}__metadata                     = source.metadata
    - min__sources__{source.id}__statuses__started            = source.statuses.started,
    - min__sources__{source.id}__statuses__publishing_started = source.statuses.publishing_started,

- **return** if sources_doc and `sources_doc.sources.{id}.statuses.started` already exists

- Send Signal `source.online`
  - **args**
    - streamer_id
    - session_id
    - source_id
    - metadata
      - session_id
      - flavor
      - provider = "byteplus"
      - provider_info
        - rtc
          - RoomId
          - room_id
        - media_live
          - base_url
          - app_name
          - stream_name
  - **receivers**
    - track_sources
    - `notify_livestream_source_events`
      - event: `source.online`
      - targets:
        - presence-stream@{streamer_id}
        - private-stream@{streamer_id}
        - presence-session@{streamer_id}
    - `cleanup_sources`
    - invalidate_cached_pusher_channel_data
    - `enable_rtm_for_preview_byteplus_source`
    - snapshot_rtc_sources

## `source.online` -> `cleanup_sources`

- !!!Sources update_one by user_id by `$addField`
  - sources: `$arrayToObject`
    - `$filter`
      - input: `$objectToArray` $sources
      - as   : sources
      - cond : `$or`
        - `$and`
          // Keep sources that are not started yet but connected within the ttl.
          - `$eq`: $$source.v.statuses.started, None 
          - `gte`: $$source.v.statuses.connected, now - connected_ttl
        - `$gte`: $$source.v.statuses.started, now - LIVESTREAM_SOURCE_STARTED_TTL

## `source.online` -> `enable_rtm_for_preview_byteplus_source`

- fetch `Session` by
  - user           = streamer_id
  - active         = True
  - status__preset = "preview"

- trigger Task `update_byteplus_rtc_source`
  - session_id  = session.id,
  - stream_name = session.user.id,
  - source_id   = source_id,
  - preset      = 'preview'

**update_byteplus_rtc_source**

- Trigger Task `StartPushSingleStreamToCDN`
  - RoomId = session_id
  - TaskId = session_id
  - Stream
    - UserId     = source_id
    - StreamType = 0
  - PushURL = generate_push_url(stream_name)
  - Control
    - MediaType   = 0,
    - MaxIdleTime = 180,

## `source.online` ->  `snapshot_rtc_sources`

- Trigger Task `StartSnapshot`
  - RoomId      = metadata.provider_info.rtc.RoomId
  - TaskId      = snapshot_{session_id} (metadata.session_id)
  - MaxIdleTime = 10 min
  - ImageConfig
    - Interval = 1 min
  - StorageConfig
    - Type = 2
    - CustomConfig
      - Vendor    = 5,
      - Region    = 0,
      - Bucket    = asia.public.swag.live/sessions/{session_id}/snapshots
      - AccessKey = BYTEPLUS_RTC_SNAPSHOT_STORAGE_ACCESS_KEY
      - SecretKey = BYTEPLUS_RTC_SNAPSHOT_STORAGE_SECRET_KEY

---
