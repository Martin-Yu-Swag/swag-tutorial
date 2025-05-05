# Streamer Disagree Goal

主播拒絕 1-1 直播

Endpoint: [DELETE] `/goals/<objectid:goal_id>`

body:

- agree: false

func flow

- Trigger Task `deactivate_goal`
  - goal_id
  - filters:
    - active            = true
    - metadata__user_id = streamer_id
  - triggerer = request.client.id
  - metadata  = None

## Task deactivate_goal

- !!!Update `Goal` (new = False):
  - filter:
    - id     = goal_id
    - active = True
    - metadata__user_id = streamer_id
  - modify
    - active False
    - min__exp now

- cooldown = now + config(TRIGGER_EXCLUSIVE_COOLDOWN)

- !!!Update goal by id:
  - set__metadata__cooldown = cooldown

- metadata.add
  - "cooldown" = cooldown
  - **goal.metadata
    - insert_ids
    - user_id (streamer_id)
    - prepaid_duration

- Send signal `goal.ended`
  - **args**:
    - goal_id
    - _cls: TriggerExclusiveGoal
    - active = False
    - progress = goal.progress (1 after transfer)
    - levels = []
    - conditions
      - session_id
      - exclusive_to
    - context
      - type         = trigger-exclusive
      - exclusive_to = user_id
    - exp = min(goal.exp, now)
    - triggerer = request.client.id
    - metadata
      - cooldown
      - insert_ids
      - user_id (streamer_id)
      - prepaid_duration
  - **receivers**:
    - trigger_show_escrow_refund **returned**
    - handle_trigger_private_goal_escrow **returned**
    - snapshot_rtc_sources **returned**
    - notify_stream_authorized_for_agreed_trigger_goal **returned**
    - sync_trigger_goal_session_viewer **returned**
    - track_goals
    - `set_embedded_goal_ended`
    - `notify_goal_ended`
      - events: `goal.ended`
      - targets:
        - f'private-stream@{session.user.id}',
        - f'presence-stream@{session.user.id}',
        - f'private-user@{session.user.id}',
    - `trigger_exclusive_goal_escrow_refund`
    - `cleanup_expired_exclusive_goal_pairs`
    - invalidate_cached_pusher_channel_data
      - targets:
        - f'private-user@{streamer_id}'
        - f'private-enc-user@{streamer_id}'
        - f'private-stream@{streamer_id}'
        - f'private-enc-stream@{streamer_id}'

### `goal.ended` -> `set_embedded_goal_ended`

- !!!Update `Session`:
  - filter:
    - id
    - trigger_private_goals__goal = goal_id
  - modify:
    - set__trigger_private_goals__{exclusive_to}__trigger_exclusive_goal_ended = now
    - set__trigger_private_goals__{exclusive_to}__trigger_exclusive_goal_cooldown = metadata['cooldown']

- Execute `invalidate_get_session_token_view_cache`

### `goal.ended` -> `trigger_exclusive_goal_escrow_refund`

- Trigger task `check_trigger_exclusive_goal_refundable`
  - eta = goal.exp = now
  - args:
    - goal_id
  - link task `escrow_refund`
    - escrow_id = "trigger_exclusive:{goal_id}"
    - user_id   = session.user_id
    - nbf       = session.statuses.created
    - exp       = session.statuses.ended

### `goal.ended` -> `cleanup_expired_exclusive_goal_pairs`

unset 其他的 1 on 1 邀請

- use Aggregate to loop through `exclusive_goal_pairs`
  - $project
    - pairs: $objectToArray $exclusive_goal_pairs
  - $unwind: $pairs
  - $match: $or
    - pairs.v.exclusive_goal_ended: {$ne None}
    - $and
    - pairs.v.exclusive_goal: None
    - pairs.v.trigger_exclusive_goal_agreed: None
    - pairs.v.trigger_exclusive_goal_ended: None
  - $project:
    - _id: False
    - user_id: $pairs.k
    - goal_id: $pairs.v.trigger_exclusive_goal

- !!!Update session
  - filter from aggregate doc:
    - id = session_id
    - exclusive_goal_pairs__{doc['user_id']}__trigger_exclusive_goal: doc['goal_id]
  - modify:
    - unset__exclusive_goal_pairs__{doc['user_id']}: True
