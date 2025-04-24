# Show goal creation

After show goal countdown end

-> endpoint [POST] `/goals`, with queries `goal_type` = show

payload:

- levels
- context
  - funding_goal_id
  - session_id
- nbf
- exp

routing func `create_new_goal`:

- execute create_show_goal
  - check `Goal` with funding_goal_id exist
  - check `Session` by session_id exist
  - Trigger Task create_goal with args:
    - active     = True
    - _cls       = ShowGoal
    - conditions = {session_id: session_id}
    - levels     = levels
    - context    = {type='show', **context}
    - metadata   = {user_id=g.user.id}
    - nbf        = nbf
  - return goal_id

### Tak `create_goal`

- create ShowGoal with args:
  - active     = active,
  - conditions = conditions,
  - levels     = levels,
  - nbf        = nbf,
  - exp        = exp,
  - context    = context,
  - metadata   = metadata, 

- Send signal `feature.leaderboards` with sender `goal.created`
  - goal_id    = goal.id,
  - active     = active,
  - _cls       = _cls,
  - conditions = goal.conditions,
  - context    = context,
  - levels     = levels,
  - nbf        = goal.nbf,
  - exp        = goal.exp,

### signal sender `goal.created`

Receivers:

- schedule_lifecycle_tasks
  Not for `KaraokeGoal` and `ShowGoal`, return

- bind_karaoke_goal_to_session
  for `KaraokeGoal`, return

- bind_exclusive_goal_to_trigger_exclusive_goal
  for `ExclusiveGoal`, return

- bind_exclusive_goals_to_session
  for `TriggerExclusiveGoal`, `ExclusiveGoal`, return

- bind_trigger_private_goal_to_session
  for `TriggerPrivateGoal`, return

- snapshot_rtc_sources
  with goal_id but not `ExclusiveGoal`, return

- track_goals
  Trigger Task analytics.tasks.track

- bind_show_goal_to_funding_goal
  **SUMMARY**: append show_goal_id on funding Goal record
  !!!Update `Goal` (id = context.funding_goal_id)
  - set:
    context.show_goal_id = goal_id

- bind_show_goals_to_session

#### `goal.created` -> `bind_show_goals_to_session`

- only for `ShowGoal`, `ShowFundingGoal`
- !!!Update Session:
  - filters:
    - id = condition.session_od
    - show_goal_pairs.funding_goal = context.funding_goal_id
  - set:
    - show_goal_pairs.S.show_goal = goal_id
- Trigger `features.livestream` signal with sender `goal.added`
  args:
  - goal_id     = goal_id,
  - _cls        = _cls,       (ShowGoal)
  - conditions  = conditions,
  - context     = context,
  - session_id  = session.id,
  - streamer_id = session.user.id

#### Signal `goal.added`

Receivers:

- `generate_livestream_feed`
- `trigger_notify_goal_added`
- `notify_stream_authorized`
- `invalidate_cached_pusher_channel_data`

presence-enc-stream-viewer@67d9847d566d0435771a730c.sd.67ceabecc82b8fd6cf63d6d6

---
