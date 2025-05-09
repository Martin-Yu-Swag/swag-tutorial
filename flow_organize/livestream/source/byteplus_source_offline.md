# Byteplus Source Online

Endpoint: [POST] `/notify/byteplus`

Body:

- EventType (eg.) -> `UserVideoStreamStop`
- EventData
- EventTime
- EventId
- AppId
- Version

func `notify` flow:

- Send Signal sender `UserVideoStreamStop`
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
    - `trigger_stream_source_offline`

## `UserVideoStreamStop` -> `trigger_stream_source_offline`

- fetch `Session` by RoomId

- !!!update `Sources` as sources_doc (new = False)
  - filter:
    - user = session.user
    - sources__{source_id}__exists = True
      (source_id is UserId)
  - unset__sources__{source_id}: 1

- Send signal `source.offline`
  - **args**
    - streamer_id
    - session_id
    - source_id
    - metadata = source.metadata
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
  - **receivers**
    - track_sources
    - `notify_livestream_source_events`
      - event: `source.offline`
      - targets:
        - presence-stream@{streamer_id}
        - private-stream@{streamer_id}
        - presence-session@{session_id}
    - invalidate_cached_pusher_channel_data
    - `snapshot_rtc_sources`
      - trigger task `StopSnapshot`
        - RoomId
        - TaskId
