# Subscribe presence goal channel

表演開始，WS client 會 push event: subscribe `presence-enc-goal@{goal_id}` channel

Endpoint: [POST] `/notify/pusher`

- event name = `member_removed`
  -> state_changed_event = `channel_occupied`

- Send Signal `ext.pusher` with Sender `channel_occupied`
  - **args**:
    - name: 'channel_occupied'
    - channel
    - user_id
  - **Receivers**
    - update_session_status_from_channel **returned**
    - trigger_user_enter **returned**
    - trigger_online **returned**
    - track_channel_presence
    - `karaoke_control`

## `channel_occupied` -> `karaoke_control`

- parse vars by sender:
  - `action`    = started
  - `fetch_new` = True

- !!!fetch and modify `Goal` (new = True)
  - filter:
    - id = object_id
    - _cls__in KaraokeGoal, ShowGoal, ExclusiveGoal
  - modify:
    - max__context__last_updated = now
    - max__context__started      = now

- Trigger Signal `goal.started`
  - **args**
    - goal_id
    - _cls       = ShowGoal
    - conditions = goal.conditions,
    - context    = goal.context,
    - progress   = goal.progress,
    - levels
      - target
      - title
    - metadata = goal.metadata
  - **Receivers**
    - trigger_external_command **returned**
    - update_and_notify_session_karaoke_goal **returned**
    - `notify_show_goal_started`
      - targets:
        - f'private-stream@{streamer_id}',
        - f'presence-stream@{streamer_id}',
        - f'private-user@{streamer_id}',
      - events: `goal.started`
    - `record_show_with_rtc`
      - Execute byteplus Task `StartRecord`
    - `invalidate_cached_pusher_channel_data`
    - `notify_stream_authorized`

