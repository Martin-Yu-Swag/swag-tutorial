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

### transfer callback

Send signal `ext.wallet` with sender `transaction.created` with args:
- transaction_id
- timestamp
- tags
- from_account
- from_amount
- to_account
- to_amount

Receivers:

- update_order **returned**
- `trigger_user_balance_updated`

#### `transaction.created` -> `trigger_user_balance_updated`

- aggregate `to_user_metadata` and `from_user_metadata`

- Send signal `user` with sender individually:
  - `balance.decremented`
  - `balance.incremented`

##### `balance.decremented` -> `progress_trigger_goals`

Args:

- user_id       
- amount        
- transaction_id
- tags

Func flow:

- Trigger Task `increment_goal_progress` with
  - goal_id      = matched['goal_id'],
  - amount       = 1,
  - cost         = amount,
  - breakdown_id = user_id,
  - insert_id    = transaction_id,

**increment_goal_progress**

- !!!Update
  - `progress` + amount (1)
  - `breakdown.{breakdown_id}.progress` + amount (1)
  - `breakdown.{breakdown_id}.cost` + cost
  - push `metadata.insert_ids` with _insert_id

- Send Signal 'features.leaderboards' with sender `goal.progressed`
  - Receivers:
    - track_goals
    - notify_goal_progress_updated
    - update_and_notify_session_karaoke_goal **returned**
    - invalidate_cached_pusher_channel_data
    - trigger_goal_complete (no level, **returned**)
    - notify_viewer_change_stream_for_show
    - trigger_exclusive_goal_escrow_refund

---

## Deactivate Goal

主播同意私密直播請求

Endpoint: [DELETE] `/goals/<objectid:goal_id>`

Body:
  - `agree`: bool

func `deactivate_goal` flow

- Trigger Task `deactivate_goal` with args:
  - goal_id = goal_id,
  - filters
    - active            = True,
    - metadata__user_id = str(g.user.id) (streamer_id)
  - triggerer = request.client.id
  - metadata
    - agreed = now
  
### Task `deactivate_goal`

- vars exp = now
- !!!Update Goal (new = False):
  - filter:
    - id = goal_id
    - active = True
    - metadata.user_id = streamer_id
  - modify
    - active = False
    - min(exp)
    - metadata.agreed = now

- Send Signal 'features.leaderboards' with sender `goal.ended`
  - args:
    - goal_id    = goal.id
    - _cls       = TriggerPrivateGoal
    - active     = False
    - progress   = goal.progress
      (0)
    - levels     = []
    - conditions = goal.conditions
      {"session_id": session_id}
    - context    = goal.context
      ({"type": 'trigger-private'})
    - exp        = min(goal.exp or exp, exp),
    - triggerer  = triggerer,
    - metadata   = metadata
      - user_id          = streamer_id
      - triggered_by     = viewer_id
      - prepaid_duration = duration
      - agreed           = now
  - Receivers:
    - **set_embedded_goal_ended**
    - notify_goal_ended
    - track_goals
    - trigger_exclusive_on_close_notification
    - **notify_stream_authorized_for_agreed_trigger_goal**
    - notify_stream_authorized_for_ended_exclusive_goal
    - trigger_show_escrow_refund
    - trigger_exclusive_goal_escrow_refund
    - **handle_trigger_private_goal_escrow**
    - cleanup_expired_exclusive_goal_pairs
    - **sync_trigger_goal_session_viewer**
      Put `goal.breakdown` user list into `session.viewers`
    - invalidate_cached_pusher_channel_data
    - snapshot_rtc_sources

#### `goal.ended` -> `set_embedded_goal_ended`

**SUMMARY**: Update session's embedded goal field. For `TriggerPrivateGoal`:
  - `trigger_private_goals.$.goal_ended`
  - `trigger_private_goals.$.agreed`

- root_field            = trigger_private_goals
- set_field             = goal_ended
- array_filter_key      = goal
- array_item_identifier = 'S'
- agreed                = now timestamp
- agreed_field          = goal_agreed
- cooldown              = None
- cooldown_field        = goal_cooldown

- !!!Update Session:
  - filter:
    - id = session_id
    - `trigger_private_goals.goal` = goal_id
      (query array filter)
  - Update:
    - `trigger_private_goals.$.goal_ended` = now timestamp
    (NOTE: here `S` is special usage for `$`, see [ref](https://docs.mongoengine.org/guide/querying.html#querying-lists))
    - `trigger_private_goals.$.goal_agreed` = agreed
  
- Execute `invalidate_get_session_token_view_cache`

#### `goal.ended` -> `notify_stream_authorized_for_agreed_trigger_goal`

**SUMMARY** notify user in goal.breakdown by channel `presence-stream-viewer@{streamer_id}.preview.{viewer_id}`

- proceed only when
  - metadata.agreed
  - metadata.streamer_id
  - metadata.prepaid_duration
  - _cls = `TriggerPrivateGoal` OR `TriggerExclusiveGoal`

- fetch goal by id

- batch-Notify
  - targets:
    - presence-stream-viewer@{streamer_id}.preview.{viewer}
      (for viewer in goal.breakdown)
  - event: `stream.authorized`

#### `goal.ended` -> `handle_trigger_private_goal_escrow`

- Trigger Task `handle_agreed_trigger_private_goal_escrow` with goal_id
  - countdown = 60

**handle_agreed_trigger_private_goal_escrow**

- fetch goal by goal_id
- fetch session by goal.condition["session_id"]
- IF following -> Task = escrow_out
  1. session.active = True
  2. session.status.preset == 'sd'
- Trigger Task with args:
  - escrow_id = f'trigger_private:{goal_id}',
  - user_id   = session.user.id,
  - nbf       = session.statuses.created,
  - exp       = session.statuses.ended,

---

## Create Counter

切換私密直播 OR 切換公開直播，發起 batch-notify

Endpoint: [POST] `/sessions/<objectid:session_id>/counters`

Body:

```json
{
  "id": "", //QUESTION: What is this id for???
  "nbf": "",
  "exp": "",
  "context": {
    "preset": "sd",
    "price": 90
  }
}
```

func flow:

- Init Session:
  - id = session_id
  - pricing = Session.SessionPricing(**{preset:price})
- batch-notify:
  - targets:
    - 'private-stream@{g.user.id}'
    - 'presence-stream@{g.user.id}'
  - events: `counter.added`

--- 

## Update Livestream

將 streaming 切換成 preview/sd

endpoint: [PATCH] `/streams/me/preset/<any("sd", "preview"):preset`

- fetch active user's session
- Trigger Task `change_session_preset`

### Task `change_session_preset`

- IF source fetched -> `update_byteplus_rtc_source`
- !!!Update Session by session_id (new=False):
  - `status.preset` = preset
- Send Signal `features.livestream` with sender `session.preset-changed`
  - args:
    - streamer_id = session.user.id,
    - session_id  = session.id,
    - preset      = preset,
    - from_preset = session.status.preset,
    - price       = session.get_price(preset=preset,duration=60)
  - receivers:
    - notify_viewers_livestream_online
    - generate_livestream_feed
    - track_session_status
    - invalidate_cached_pusher_channel_data
