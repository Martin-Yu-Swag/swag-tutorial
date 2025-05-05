# Subscribe Goal Channel

Endpoint: [POST] `/notify/pusher`

Body:

```json
{
    "timestamp": "",
    "events": [
        {
            "name": "",
            "channel": "presence-enc-goal@{goal_id}",
            "user_id": ""
        }
    ]
}
```

- Send Signal `channel_occupied`
  - **args**:
    - channel
    - user_id
  - **receivers**:
    - update_session_status_from_channel **returned**
    - trigger_online **returned**
    - track_channel_presence
    - trigger_user_enter
    - `karaoke_control`

## `channel_occupied` -> `karaoke_control`

- !!!Update Goal by goal_id (new = True)
  - modify:
    - max__context__last_updated = now
    - max__context__started      = now

- Send Signal `goal.started`
  - **args**:
    - goal_id
    - _cls = ExclusiveGoal
    - conditions
    - context
      - last_updated
      - started
    - progress
    - levels.0
      - target = 300
      - title = none
    - metadata
      - user_id
  - **Receivers**:
    - trigger_external_command **returned**
    - update_and_notify_session_karaoke_goal **returned**
    - notify_show_goal_started
      - targets:
        - f'private-stream@{streamer_id}',
        - f'presence-stream@{streamer_id}',
        - f'private-user@{streamer_id}',
      - events: `goal.started`
    - record_show_with_rtc
    - `invalidate_cached_pusher_channel_data`
    - `notify_stream_authorized`
