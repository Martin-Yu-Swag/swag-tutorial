# Exclusive Session

- [POST] `/sessions/<objectid:session_id>/trigger_exclusive` 發起一對一邀請
  - wallet 進行 transfer, 並透過 callback 更新 TriggerExclusiveGoal
- [DELETE] `/goals/{goal_id}`  接受邀請 = 刪除 `TriggerExclusiveGoal`
  (accepted)
- [POST] `/goal` 建立 `ExclusiveGoal`

## trigger_exclusive_session

viewer 發起 1-1 直播邀請

Endpoint: `/sessions/<objectid:session_id>/trigger_exclusive`

Body:

```json
{
    "exp"     : 1745810053,
    "duration": 60
}
```

func flow:

**SUMMARY**: create `TriggerExclusiveGoal` and make transfer from user_id to streamer_id

- fetch session by
  - session_id
  - active = True

- IF one of any: FORBIDDEN
  - user.tags exist f"blocked-by:{streamer_id}"
  - session's last show_goal_pair not funding ended
    (`show_goal_pair.funding_ended` not None)
  - session's show not done
    (`show_goal_pair.show_goal` and `show_goal_pair.show_ended`)
  - session's already exclusive
    (`session.status.preset` == 'sd' AND `session.status.exclusive_to` Not None)

- IF user in cool-down period LivestreamTriggerQuotaExceeded
  - parse `exclusive_goal_pair` (session.exclusive_goal_pairs.{user_id})
    NOTE: `ExclusiveGoalPair` attr:
      - trigger_exclusive_goal (Goal)
      - trigger_exclusive_goal_ended (Datetime)
      - trigger_exclusive_goal_agreed (Datetime)
      - trigger_exclusive_goal_cooldown (Datetime)
      - exclusive_goal (Goal)
      - exclusive_goal_ended (Datetime)
  - a. NOT `exclusive_goal_pair.trigger_exclusive_goal_agreed`
  - b. `goal_ended` from `exclusive_goal_pair.trigger_exclusive_goal_ended`
  - c. `goal_ended` + cooldown time > now

- parse `amount` from session.get_exclusive_sd_price(duration)

- IF user.balance: amount -> FORBIDDEN

- Trigger Task create_goal -> get `goal_id`
  - args:
    - active     = True
    - _cls       = TriggerExclusiveGoal
    - conditions = {"session_id": session_id, "exclusive_to": user_id}
    - levels     = []
    - context    = {"type": 'trigger-exclusive', "exclusive_to": user_id}
    - metadata   = {"user_id" :streamer_id, "prepaid_duration": duration}
    - exp

- Trigger Task transfer with args:
  - transaction_id = `session:trigger-exclusive:{goal_id}`
  - from_user_id   = user_id,
  - to_user_id     = streamer_id,
  - amount         = amount,
  - tags           = [`swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}`]
    (LIVESTREAM_SESSION_TRIGGER_EXCLUSIVE)
  - escrow_id      = `trigger_exclusive:{goal_id}`

### post-transfer event

Wallet 收到款項後，會處理 `TriggerExclusiveGoal` 後續的流程

wallet callback: `/notify/wallet/transaction`

- Trigger Signal `ext.wallet` with sender `transaction.created`
- Receivers
  - update_order **returned**
  - trigger_user_balance_updated

#### `transaction.created` -> trigger_user_balance_updated

- aggregate `to_user_metadata` and `from_user_metadata`
- Send signal `user` with sender individually:
  - `balance.decremented`
  - `balance.incremented`

`balance.incremented` receivers:

- track_points_activity
- fetch_user_balance_when_changed
- record_wallet_payment_earnings
- referral_code_diamond_received
- prepaidcard_diamond_received
- livestream_chat_received
- livestream_view_received
- points_deposited
- wallet_purchase_consumable
- escrow_show_transfer_received
- livestream_show_direct_received
- gift_received
- handle_bet_transaction_completions
- add_journal_entry
- handle_bet_transaction_completions
- record

`balance.decremented` receivers:

- track_points_activity
- fetch_user_balance_when_changed
- points_withdrawn
- livestream_show_withdrawn
- **progress_trigger_goals**
- record_penalty_points_to_earnings
- handle_bet_transaction_completions
- handle_bet_transaction_completions
- handle_bet_transaction_completions

#### `balance.decremented` -> `progress_trigger_goals`

- proceed only with tags has
  - LIVESTREAM_SESSION_TRIGGER_PRIVATE
  - LIVESTREAM_SESSION_TRIGGER_EXCLUSIVE
- Trigger Task increment_goal_progress with
  - goal_id
  - amount       = 1
  - cost         = amount
  - breakdown_id = user_id
  - insert_id    = transaction_id

`increment_goal_progress`

- query & modify `Goal`:
  - filter:
    - id=goal_id
  - modify:
    - `progress` + amount (1)
    - `breakdown.{breakdown_id}.progress` + amount (1)
    - `breakdown.{breakdown_id}.cost` + cost
    - push `metadata.insert_ids` with _insert_id
- Send Signal 'features.leaderboards' with sender `goal.progressed`
  - args:
    - goal_id      = goal.id,
    - _cls         = goal._cls (`TriggerExclusiveGoal`)
    - breakdown_id = breakdown_id
    - ...other field from `goal`
  - Receivers:
    - track_goals
    - notify_goal_progress_updated
    - update_and_notify_session_karaoke_goal **returned**
    - invalidate_cached_pusher_channel_data
    - trigger_goal_complete (no level, **returned**)
    - notify_viewer_change_stream_for_show
    - trigger_exclusive_goal_escrow_refund

##### `goal.progressed` -> `trigger_goal_complete`

- check whether goal reached (not used for TriggerExclusiveGoal)
- Trigger signal `features.leaderboards` with sender `goal.completed`
  - Receivers:
    - track_goals
    - set_embedded_goal_ended
    - deactivate_goal
    - produce_livestream_clip_from_goal
    - record_show_with_rtc
    - trigger_show_escrow_transfer
    - trigger_exclusive_escrow_transfer
    - notify_livestream_mvps

!!! 先觸發 `deactivate_goal`, 然後 send `goal.ended`, 在觸發 `set_embedded_goal_ended`

- `set_embedded_goal_ended`
- set vars: (bu Goal _cls)
  - root_field            = 'exclusive_goal_pairs'
  - set_field             = 'trigger_exclusive_goal_ended'
  - exclusive_to          = context["exclusive_to"]
  - array_filter_key      = f'{exclusive_to}__trigger_exclusive_goal'
  - array_item_identifier = exclusive_to
  - agreed = metadata["agreed]
  - agreed_field = 'trigger_exclusive_goal_agreed'
  - cooldown_field = 'trigger_exclusive_goal_cooldown'
- !!!Update Session:
  - filter: 
    - id = session_id
    - exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal = goal_id
  - modify:
    - set `exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal_ended` = now
    - set `exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal_agreed` = agreed
    - set `status.exclusive_to` = [exclusive_to]
- IF exclusive_to -> Execute func `invalidate_get_session_token_view_cache`

---

### Task `create_goal`

**SUMMARY**: create `TriggerExclusiveGoal` and send `goal.created` signal

- create goal `TriggerExclusiveGoal` with
  - active     = active
  - conditions = conditions
  - levels     = levels
  - nbf        = nbf
  - exp        = exp
  - context    = context
  - metadata   = metadata

- Send Signal `features.leaderboards` with sender `goal.created`
  - args:
    - goal_id    = goal.id
    - active     = active
    - _cls       = _cls
    - conditions = goal.conditions
    - context    = context
    - levels     = levels
    - nbf        = goal.nbf
    - exp        = goal.exp

  - Receivers:
    - bind_karaoke_goal_to_session
      for `KaraokeGoal`, **return**
    - bind_exclusive_goal_to_trigger_exclusive_goal
      for `ExclusiveGoal`, **return**

    - bind_exclusive_goals_to_session
      assign `ExclusiveGoalPair` to `session.exclusive_goal_pairs` by user_id

    - bind_trigger_private_goal_to_session
      for `TriggerPrivateGoal`, **return**

    - snapshot_rtc_sources
      with goal_id but not `ExclusiveGoal`, **return**
    
    - schedule_lifecycle_tasks

    - track_goals
      Trigger Task analytics.tasks.track

    - bind_show_goal_to_funding_goal
      **return**

    - bind_show_goals_to_session
      **return**

#### `goal.created` -> `bind_exclusive_goals_to_session`

**SUMMARY**: assign `ExclusiveGoalPair` to `session.exclusive_goal_pairs` by user_id

- Proceed only with `TriggerExclusiveGoal` or `ExclusiveGoal`

- !!!Update session:
  - filter:
    - id = condition["session_id"]
    - `exclusive_goal_pairs.{user_id}.trigger_exclusive_goal` not exist goal_id
  - modify:
    - set `exclusive_goal_pairs.{user_id}` = `Session.ExclusiveGoalPair`(trigger_exclusive_goal=goal_id)

- Send Signal `features.leaderboards` with sender `goal.added`
  - args:
    - goal_id     = goal_id,
    - _cls        = _cls,
    - conditions  = conditions,
    - context     = context,
    - session_id  = session.id,
    - streamer_id = session.user.id,
  - receivers: 
    - `generate_livestream_feed`
    - `trigger_notify_goal_added`
    - `notify_stream_authorized`
    - `invalidate_cached_pusher_channel_data`

#### `goal.created` -> `schedule_lifecycle_tasks` (eta: exp)

**SUMMARY**: de-active goal, set cooldown time, send signal `goal.ended` sender

- Trigger Task `deactivate_goal` with args:
  - goal_id
  - exp

`deactivate_goal`:

- !!!Update Goal by id:
  - active=False
  - min exp
    ([$min](https://www.mongodb.com/docs/manual/reference/operator/update/min/))

- IF NOT `goal.metadata.agreed` (if streamer turn down the request)
  - set `Goal.metadata.cooldown`

- Send `goal.ended` sender
  
---

## deactivate_goal (TriggerExclusiveGoal)

主播接受 1-1 直播

Endpoint: [DELETE] `/goals/<objectid:goal_id>`

body:

- agree: bool (false = 拒絕)

func `deactivate_goal` flow: (以 接受 為例)

- Trigger Task `deactivate_goal` with args:
  - goal_id = goal_id,
  - filters
    - active            = True,
    - metadata__user_id = str(g.user.id)
  - triggerer = request.client.id
  - metadata
    - agree = now
  
### `deactivate_goal`

- fetch and modify `Goal`:
  - filter:
    - id = goal_id
    - metadata.user_id = user_id
  - modify:
    - set active = False
    - min exp
    - set metadata.agree = now

- Trigger Signal sender `goal.ended`
  - args:
    - goal_id    = goal.id,
    - _cls       = goal._class_name,
    - active     = False,
    - progress   = goal.progress,
    - levels     = (from goal.levels)
    - conditions = goal.conditions,
    - context    = goal.context,
    - exp        = min(goal.exp or exp, exp),
    - triggerer  = triggerer,
    - metadata   = metadata,
  - receivers:
    - **set_embedded_goal_ended**
      Update Session fields:
      - exclusive_goal_pairs.{exclusive_to}.trigger_exclusive_goal_ended = now
      - exclusive_goal_pairs.{exclusive_to}.trigger_exclusive_goal_agreed = agreed
      - status.exclusive_to = [exclusive_to]
      - execute `invalidate_get_session_token_view_cache`

    - notify_goal_ended
    - track_goals
    - trigger_exclusive_on_close_notification **returned**
    - notify_stream_authorized_for_agreed_trigger_goal
    - notify_stream_authorized_for_ended_exclusive_goal **returned**
    - trigger_show_escrow_refund
    - trigger_exclusive_goal_escrow_refund
    - handle_trigger_private_goal_escrow **returned**
    - cleanup_expired_exclusive_goal_pairs
    - **sync_trigger_goal_session_viewer**
      - Update `Session.viewers` field: (viewer_id from `goal.breakdown`)
        - `viewers.{viewer_id}.nbf`
        - `viewers.{viewer_id}.duration`
        - `viewers.{viewer_id}.exp`
      - execute `invalidate_get_session_token_view_cache`

    - invalidate_cached_pusher_channel_data
    - snapshot_rtc_sources **returned**


---

## create_new_goal

倒數結束後開始私密直播

Endpoint: [POST] `/goals`

Queries:

- `type` (show-funding / show / `exclusive`)

Body:

- context:
  - levels.*
    - target
  - session_id
  - trigger_exclusive_goal_id
  - nbf

func flow:

- Execute `create_exclusive_goal` and return goal_id

### create_exclusive_goal

- receive json body from decorator injection
  - levels
  - context
  - nbf

- fetch session by
  - id = session_id
  - user = user.id (streamer)
  - active = True

- fetch Goal by
  - id = context['trigger_exclusive_goal_id']
  - exp exist
  - exp < now
  - context.exclusive_goal_id don't exist

- Trigger Task `create_goal` with args:
  - active     = True,
  - _cls       = ExclusiveGoal._class_name,
  - conditions = {session_id = context['session_id'], levels=levels}
  - metadata = {user_id=user.id}
  - nbf = nbf

### Task create_goal

- create goal: `ExclusiveGoal`
  - active     = active
  - conditions = conditions
  - levels     = levels
  - nbf        = nbf
  - exp        = exp
  - context    = context
  - metadata   = metadata

- Send Signal `features.leaderboards` with sender `goal.created`
  - args:
    - goal_id    = goal.id
    - active     = active
    - _cls       = _cls
    - conditions = goal.conditions
    - context    = context
    - levels     = levels
    - nbf        = goal.nbf
    - exp        = goal.exp
  - Receivers:
- Receivers:
  - bind_karaoke_goal_to_session **return**
  - bind_trigger_private_goal_to_session **return**
  - bind_show_goal_to_funding_goal **return**
  - bind_show_goals_to_session **return**

  - bind_exclusive_goal_to_trigger_exclusive_goal
    Update (`TriggerExclusiveGoal`) `Goal.context.exclusive_goal_id` = goal_id

  - bind_exclusive_goals_to_session
    Update `session.exclusive_goal_pairs.{user_id}.exclusive_goal` = goal_id

  - `snapshot_rtc_sources`
    Disable snapshot on exclusive start

  - `schedule_lifecycle_tasks`

  - track_goals
    Trigger Task analytics.tasks.track

#### `goal.created` -> snapshot_rtc_sources

**SUMMARY**: Disable snapshot on exclusive start, enable at end.

- proceed only with goal_id of `ExclusiveGoal`
- loop through user's sources:
  - get `room_id` and `session_id` from source
  - Trigger Task `byteplus.tasks.rtc.StopSnapshot`
    - RoomId=room_id
    - TaskId=task_id

---

進入 1 on 1 直播後，透過 `/pay` 來付款

- body:

```json
{
    "duration": 60
}
```

func `authorize_livestream` flow:

- fetch session
  - active  = True
  - user_id = streamer_id

- get amount by session.get_price
  - preset (load from default "sd")
  - duration
