# Trigger Exclusive Session

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

- fetch `session` by
  - session_id
  - active = True

- IF one of any: FORBIDDEN
  判定 403: 1. 用戶被封鎖 2. 募票階段未結束 3. 募票演出未結束 4.已經在 1-1 直播
  - user.tags exist f"blocked-by:{streamer_id}"
  - session's last show_goal_pair not funding ended
    (`show_goal_pair.funding_ended` not None)
  - session's show not done
    (`show_goal_pair.show_goal` and `show_goal_pair.show_ended`)
  - session's already exclusive
    (`session.status.preset` == 'sd' AND `session.status.exclusive_to` Not None)

- check whether user in cool-down period
  判定 cooldown 條件：1. 上一場被拒絕 2. 被拒絕時間 + cd time > now
  - parse `exclusive_goal_pair` (session.exclusive_goal_pairs.{user_id})
    NOTE: `ExclusiveGoalPair` attr:
      - trigger_exclusive_goal (Goal)
      - trigger_exclusive_goal_ended (Datetime)
      - trigger_exclusive_goal_agreed (Datetime)
      - trigger_exclusive_goal_cooldown (Datetime)
      - exclusive_goal (Goal)
      - exclusive_goal_ended (Datetime)
  - ...IF all -> raise `LivestreamTriggerQuotaExceeded`
  - a. NOT `exclusive_goal_pair.trigger_exclusive_goal_agreed` // 沒接受
  - b. `goal_ended` from `exclusive_goal_pair.trigger_exclusive_goal_ended`
  - c. `goal_ended` + cooldown time > now

- parse `amount` from session.get_exclusive_sd_price(duration)

- IF user.balance: amount -> FORBIDDEN

- Trigger Task `create_goal` -> get `goal_id`
  - **args**:
    - active     = True
    - _cls       = `TriggerExclusiveGoal`
    - conditions
      - session_id   = session_id
      - exclusive_to = user_id
    - levels       = []
    - context
      - type         = trigger-exclusive
      - exclusive_to = user_id
    - metadata
      - user_id: streamer_id
      - prepaid_duration: duration
    - exp

- Trigger Task transfer with args:
  - transaction_id = `session:trigger-exclusive:{goal_id}`
  - from_user_id   = user_id,
  - to_user_id     = streamer_id,
  - amount         = amount,
  - tags
    - `swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}`
    (LIVESTREAM_SESSION_TRIGGER_EXCLUSIVE)
  - escrow_id      = `trigger_exclusive:{goal_id}`

## Task `create_goal`

- Create `TriggerExclusiveGoal`
  - active = True
  - nbf    = None
  - exp    = exp
  - levels = []
  - context
    - type         = trigger-exclusive
    - exclusive_to = user_id
  - conditions
    - session_id   = session_id
    - exclusive_to = user_id
  - metadata
    - user_id: streamer_id
    - prepaid_duration: duration

- Send Signal `goal.created`
  - **args**:
    - goal_id
    - active = True,
    - _cls = `TriggerExclusiveGoal`
    - context
      - type         = trigger-exclusive
      - exclusive_to = user_id
    - conditions
      - session_id   = session_id
      - exclusive_to = user_id
    - levels = []
    - nbf = None
    - exp = exp
  - **Receivers**
    - bind_karaoke_goal_to_session **return**
    - bind_exclusive_goal_to_trigger_exclusive_goal **return**
    - bind_trigger_private_goal_to_session **return**
    - snapshot_rtc_sources **return**
    - bind_show_goal_to_funding_goal **return**
    - bind_show_goals_to_session **return**
    - `track_goals`
    - `bind_exclusive_goals_to_session`
    - `schedule_lifecycle_tasks`

### `goal.created` -> `bind_exclusive_goals_to_session`

- !!!Update Session:
  - filter:
    - id = conditions['session_id']
    - exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal__ne goal_id
  - modify:
    - set__exclusive_goal_pairs__{exclusive_to} Session.ExclusiveGoalPair(trigger_exclusive_goal=goal_id)

- Send signal `goal.added`
  - **Receivers**:
    - notify_stream_authorized **returned**
    - `invalidate_cached_pusher_channel_data`
    - `generate_livestream_feed`
    - `trigger_notify_goal_added`
      - events: `goal.added`
      - targets:
        - 'presence-stream@{streamer_id}'
        - 'private-stream@{streamer_id}'
        - 'private-user@{streamer_id}'

### `goal.created` -> `schedule_lifecycle_tasks`

- Trigger Task `deactivate_goal` with eta=exp

## Task `transfer`

- from_account = user.wallet_id
- from_amount  = amount
- to_account   = streamer.wallet_id
- to_amount    = amount

- tags =
  - 'swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}'
  - 'escrow::{b64_encode_streamer_wallet_id_b64}:swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}'

- to_account = None

- Trigger wallet Task `transfer`
  - transaction_id = 'session:trigger-exclusive:{goal_id}'
  - from_account
  - from_amount
  - to_account = None
  - to_amount
  - forced = False 
  - tags
    - 'swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}'
    - 'escrow::{b64_encode_streamer_wallet_id_b64}:swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}'
  - timestamp = None

### Callback after transfer

Endpoint: [POST] `/notify/wallet/transaction`

Body:

```json
{
    "id"         : "session:trigger-exclusive:{goal_id}",
    "ts"         : "",
    "fromAccount": "{viewer_id}",
    "fromAmount" : "amount",
    "toAccount"  : null,
    "toAmount"   : "amount",
    "tags": [
        "swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}",
        "escrow::{b64_encode_streamer_wallet_id_b64}:swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}"
    ]
}
```

- Send Signal `ext.wallet` with sender `transaction.created`
- **Receivers**
  - update_order **returned**
  - `trigger_user_balance_updated`

#### `transaction.created` -> `trigger_user_balance_updated`

- no to_user_id, so don't send `balance.incremented`

- send signal `balance.decremented`
  - **args**:
    - user_id               = from_user_id,
    - user_wallet_id        = from_user_wallet_id,
    - source_user_id        = None
    - source_user_wallet_id = None
    - amount                = amount
    - timestamp             = timestamp
    - transaction_id        = 'session:trigger-exclusive:{goal_id}'
    - tags
      - "swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}",
      - "escrow::{b64_encode_streamer_wallet_id_b64}:swag::livestream.session:{session_id}.trigger_exclusive:{goal_id}"
    - metadata:
      - user
        - id
        - username
        - tags
        - tagsv2
        - level

  - **receivers**:
    - borden::handle_bet_transaction_completions **returned**
    - giocogroup::handle_bet_transaction_completions **returned**
    - sic_bo::handle_bet_transaction_completions **returned**
    - record_penalty_points_to_earnings **returned**
    - track_points_activity
    - `progress_trigger_goals`
    - livestream_show_withdrawn
    - points_withdrawn
    - fetch_user_balance_when_changed

##### `balance.decremented` -> `progress_trigger_goals`

- trigger task `increment_goal_progress`
  - goal_id
  - amount       = 1
  - cost         = amount
  - breakdown_id = user_id
  - insert_id    = 'session:trigger-exclusive:{goal_id}'

**increment_goal_progress**

- !!!Update Goal: (new=True)
  - filter:
    - id = goal_id
    - metadata__insert_ids__ne = insert_id
  - modify:
    - inc__progress                            = 1
    - inc__breakdown__{breakdown_id}__progress = amount
    - inc__breakdown__{breakdown_id}__cost     = cost
    - push__metadata__insert_ids               = insert_id

- Send Signal `goal.progressed`
  - **args**
    - goal_id
    - _cls         = TriggerExclusiveGoal
    - amount       = 1
    - conditions   = goal.conditions,
    - context      = goal.context,
    - progress     = 1
    - breakdown_id = breakdown_id,
    - levels       = []
    - metadata     = goal.metadata,
    - exp          = goal.exp,
  - **receivers**
    - update_and_notify_session_karaoke_goal **returned**
    - trigger_goal_complete **returned**
    - invalidate_cached_pusher_channel_data **returned**
    - notify_viewer_change_stream_for_show **returned**
    - trigger_exclusive_goal_escrow_refund **returned**
    - track_goals
    - `notify_goal_progress_updated`
      - events: `goal.progress.updated`
      - targets:
        - f'private-stream@{streamer_id}'
        - f'presence-stream@{streamer_id}'
        - f'private-user@{streamer_id}'

