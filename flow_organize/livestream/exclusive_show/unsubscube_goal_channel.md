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

- Send Signal `channel_vacated`
  - **args**:
    - channel
    - user_id
  - **Receivers**
    - trigger_online **returned**
    - trigger_user_enter **returned**
    - track_channel_presence
    - `karaoke_control`

## `channel_vacated` -> `karaoke_control`

- !!!Update Goal by id (new = False):
  - modify:
    - max__context__last_updated now
    - max__context__paused now

- Trigger Task `increment_goal_progress`
  - gold_id
  - amount = now - goal.context['started'] (in seconds)

## Task `increment_goal_progress`

- !!!Update Goal by id:
  - inc__progress amount
- Send signal `goal.progressed`
  - **args**
    - goal_id
    - _cls = ExclusiveGoal
    - amount
    - conditions
    - context
    - progress
    - breakdown_id
    - levels.0
      - target = 360
    - metadata
    - exp = None
  - **Receivers**
    - notify_goal_progress_updated **returned**
    - update_and_notify_session_karaoke_goal **returned**
    - notify_viewer_change_stream_for_show **returned**
    - track_goals
    - `trigger_goal_complete`
    - `trigger_exclusive_goal_escrow_refund`
      returned if 
    - invalidate_cached_pusher_channel_data

### `goal.progressed` -> `trigger_goal_complete`

- Check new_goal.level > old_goal.level
- Send Signal `goal.completed`
  - **args**:
    - goal_id
    - _cls = ExclusiveGoal
    - conditions
    - context
    - progress
    - levels.0
      - target = 360
    - metadata
  - **Receivers**:
    - notify_livestream_mvps **returned**
    - set_embedded_goal_ended **returned**
    - produce_livestream_clip_from_goal **returned**
    - record_show_with_rtc **returned**
    - trigger_show_escrow_transfer **returned**
    - track_goals
    - `trigger_exclusive_escrow_transfer` **returned** becuz goal.level > 0
    - `deactivate_goal`

#### `goal.completed` -> `deactivate_goal`

- Trigger Task `deactivate_goal`
- !!!Update Goal by id (new=False):
  - active = False
  - min__exp = now
- Send Signal `goal.ended`
  - **args**:
    - goal_id
    - _cls     = ExclusiveGoal
    - active   = False
    - progress
    - levels.0
      - target = 360
    - conditions
    - context
    - exp = now
    - triggerer = None
    - metadata
  - **Receivers**:
    - trigger_show_escrow_refund **returned**
    - handle_trigger_private_goal_escrow **returned**
    - notify_stream_authorized_for_agreed_trigger_goal **returned**
    - track_goals
    - `snapshot_rtc_sources`
      - Trigger Task `StartSnapshot`
    - `sync_trigger_goal_session_viewer`
      - !!!update `Session`
        - viewers.{viewer_id}.nbf
        - viewers.{viewer_id}.duration
        - viewers.{viewer_id}.exp
      - execute `invalidate_get_session_token_view_cache`
    - `set_embedded_goal_ended`
      - !!!Update `Session`:
        - exclusive_goal_pairs__{exclusive_to}__exclusive_goal_ended = now
        - unset__status__exclusive_to True
      - execute `invalidate_get_session_token_view_cache`
    - `notify_goal_ended`
    - `trigger_exclusive_goal_escrow_refund`
       - returned if progress meet target
    - `cleanup_expired_exclusive_goal_pairs`
    - `invalidate_cached_pusher_channel_data`
