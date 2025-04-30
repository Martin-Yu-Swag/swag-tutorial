# Delete Show Funding Goal

主播選擇開始進行募票直播

Endpoint: [DELETE] `/goals/<objectid:goal_id>`

Trigger Task `deactivate_goal`
- goal_id
- filter:
  - active = True
  - metadata__user_id = g.user.id
- triggerer = request.client.id
- metadata: None

## Task `deactivate_goal`

**SUMMARY**:
- set goal active = False
- set goal exp
- Send signal `goal.ended`

- exp      = now
- metadata = {}
- !!!Fetch goal and update (new=False)
  - filter:
    - id = goal_id
    - active = True
    - metadata__user_id = g.user.id
  - modify
    - active: False
    - min__exp: exp
- Send signal `feature.leaderboard` with sender `goal.ended`
  - **args**:
    - goal_id  = goal.id,
    - _cls     = ShowFundingGoal
    - active   = False,
    - progress = goal.progress,
    - levels.0
      - title
      - target
    - conditions (goal.conditions)
    - context (goal.context)
    - exp
    - triggerer (client_id)
    - metadata (goal.metadata)
  - Receivers:
    - trigger_exclusive_on_close_notification **returned**
    - notify_stream_authorized_for_agreed_trigger_goal **returned**
    - notify_stream_authorized_for_ended_exclusive_goal **returned**
    - trigger_exclusive_goal_escrow_refund **returned**
    - handle_trigger_private_goal_escrow **returned**
    - cleanup_expired_exclusive_goal_pairs **returned**
    - sync_trigger_goal_session_viewer **returned**
    - snapshot_rtc_sources **returned**
    - `track_goals`
    - `set_embedded_goal_ended`
    - `notify_goal_ended`
    - `trigger_show_escrow_refund`
    - invalidate_cached_pusher_channel_data

### `goal.ended` -> `set_embedded_goal_ended`

- !!!Update Session:
  - filter
    - id = session_id (from conditions)
    - show_goal_pairs__funding_goal = goal_id
  - update:
    - set__show_goal_pairs__S__funding_ended = now

### `goal.ended` -> `notify_goal_ended`

- targets:
  - f'private-stream@{session.user.id}'
  - f'presence-stream@{session.user.id}'
  - f'private-user@{session.user.id}'
- events:
  - goal.ended

### `goal.ended` -> `trigger_show_escrow_refund`

- ...IF progress > levels.0.target -> return
- ...ELSE -> trigger Task `check_funding_goal_refundable`
  (先設定募票成功情境)
