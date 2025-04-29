# Show Goal Flow

## Trigger Private Session

Viewer 發出私密直播邀請

Endpoint: [POST] `/sessions/<objectid:session_id>/trigger_private`

Body:

```json
{
    "exp": "timestamp",
    "duration": "sec-in-int"
}
```

func `trigger_private_session` flow:

- fetch active session by id

- IF any of following -> FORBIDDEN
  - `user.tags` exists "blocked-by:{streamer_id}"
  - `session.get_price('sd')` is None
  - exist show_goal_pair and funding / show not ended

- IF cooldown not finish -> raise LivestreamTriggerQuotaExceeded
  - session has previous trigger_private_goal
  - NOT `trigger_private_goal.goal_agreed`
  - `trigger_private_goal.goal_ended` + cooldown time > now

- IF user's balance < session's sd price -> FORBIDDEN

- Fetch goal_id:
  - ...IF trigger_private_goal exist and NOT trigger_private_goal.goal_ended
    (means there's an ongoing Goal)
    -> trigger_private_goal.goal.id
  - ...ELSE: Trigger Task `create_goal` with args:
    - active     = True
    - _cls       = TriggerPrivateGoal,
    - conditions = {"session_id": session_id}
    - levels     = []
    - context = {"type": 'trigger-private'}
    - metadata
      - user_id          = streamer_id
      - triggered_by     = viewer_id
      - prepaid_duration = duration
    - exp = exp

- Trigger Task `transfer` with args:
  - transaction_id = f'session:trigger-private:{goal_id}:{g.user.id}'
  - from_user_id   = viewer_id
  - to_user_id     = streamer_id
  - amount         = (session.get_price('sd', duration))
  - tags.*
    - 'swag::livestream.session:{session_id}.trigger_private:{goal_id}'
      (LIVESTREAM_SESSION_TRIGGER_PRIVATE)
  - escrow_id = 'trigger_private:{goal_id}'

- return accepted

### Task `create_goal`

- create `goal`
  - _cls       = TriggerPrivateGoal
  - active     = active,
  - conditions = conditions,
  - levels     = levels,
  - nbf        = nbf (none)
  - exp        = exp,
  - context    = context,
  - metadata   = metadata,

- Send Signal `features.leaderboards` with sender `goal.created`
  - args
    - goal_id    = goal.id,
    - active     = active,
    - _cls       = _cls,
    - conditions = goal.conditions,
    - context    = context,
    - levels     = levels,
    - nbf        = goal.nbf,
    - exp        = goal.exp,
  - Receivers:
    - bind_karaoke_goal_to_session **return**
    - bind_show_goal_to_funding_goal **return**
    - bind_show_goals_to_session **return**
    - bind_exclusive_goal_to_trigger_exclusive_goal **return**
    - bind_exclusive_goals_to_session **return**
    - snapshot_rtc_sources **return**
    - track_goals
    - `schedule_lifecycle_tasks`
      trigger task `deactivate_goal` with goal_id and exp

    - `bind_trigger_private_goal_to_session`
      - !!!Update:
        Push `session.trigger_private_goals` with Session.TriggerPrivateGoal(goal=goal_id)
      - Send signal `features.leaderboards` with `goal.added`
    
#### `goal.added`

Send from `bind_trigger_private_goal_to_session`

Args:

- goal_id=goal_id,
- _cls=_cls,
- conditions=conditions,
- context=context,
- session_id=session.id,
- streamer_id=session.user.id,

Receivers:

- `generate_livestream_feed`
- `trigger_notify_goal_added`
  - targets:
    - 'presence-stream@{streamer_id}'
    - 'private-stream@{streamer_id}'
    - 'private-user@{streamer_id}'
  - events: `goal.added`
- notify_stream_authorized **returned**
- `invalidate_cached_pusher_channel_data`
