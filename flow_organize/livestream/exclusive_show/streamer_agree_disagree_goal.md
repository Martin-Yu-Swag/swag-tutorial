# Streamer Agree Goal

主播接受 1-1 直播

Endpoint: [DELETE] `/goals/<objectid:goal_id>`

body:

- agree: true

func flow

- Trigger Task `deactivate_goal`
  - goal_id
  - filters:
    - active            = true
    - metadata__user_id = streamer_id
  - triggerer = request.client.id
  - metadata:
    - agreed: now

## Task `deactivate_goal`

- !!!modify `Goal` (new=False)
  - filter
    - id = goal_id
    - active = true
    - metadata.user_id = user_id
  - modify
    - active: False
    - min__exp: exp

- Send signal `goal.ended`
  - **args**:
    - goal_id
    - _cls     = TriggerExclusiveGoal
    - active   = False
    - progress = 1
    - levels   = []
    - conditions
      - session_id   = session_id
      - exclusive_to = user_id
    - context
      - type         = trigger-exclusive
      - exclusive_to = user_id
    - exp        = min(goal.exp or exp, exp),
    - triggerer  = client_id,
    - metadata
      - user_id: streamer_id
      - prepaid_duration: duration
      - agreed: now
  - **receivers**
    - trigger_exclusive_on_close_notification **returned**
    - notify_stream_authorized_for_ended_exclusive_goal **returned**
    - trigger_show_escrow_refund **returned**
    - handle_trigger_private_goal_escrow **returned**
    - snapshot_rtc_sources **returned**
    - track_goals
    - `set_embedded_goal_ended`
    - `notify_goal_ended`
      - events: `goal.ended`
      - targets:
        - f'private-stream@{session.user.id}',
        - f'presence-stream@{session.user.id}',
        - f'private-user@{session.user.id}',
    - `notify_stream_authorized_for_agreed_trigger_goal`
      - events: 'stream.authorized'
      - targets: 
        - presence-stream-viewer@{streamer_id}.preview.{viewer}
          (for viewer in goal.breakdown) -> only exclusive user
    - `trigger_exclusive_goal_escrow_refund`
    - `cleanup_expired_exclusive_goal_pairs`
    - `sync_trigger_goal_session_viewer`
      Put `goal.breakdown` user list into `session.viewers`
    - invalidate_cached_pusher_channel_data

### `goal.ended` -> `set_embedded_goal_ended`

- !!!Update Session:
  - filter:
    - id = condition['session_id']
    - exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal = context['exclusive_to']
  - modify
    - set__exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal__goal_ended = True
    - set__exclusive_goal_pairs__{exclusive_to}__trigger_exclusive_goal__trigger_exclusive_goal_agreed = metadata['agreed']
    - set__status__exclusive_to = [exclusive_to]

- Execute `invalidate_get_session_token_view_cache`

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

### `goal.ended` ->  `sync_trigger_goal_session_viewer`

- duration   = 60 + metadata['prepaid_duration]
- nbf        = agreed
- session_id = conditions['session_id']

- !!!Update Session:
  - filter: session_id
  - modify raw $set
    viewer = loop through goal.breakdown
    - 'viewers.{viewer_id}.nbf', f'$viewers.{viewer_id}.nbf' OR nbf
    - 'viewers.{viewer_id}.duration'
    - viewers.{viewer_id}.exp

- Execute invalidate_get_session_token_view_cache

### `goal.ended` ->  `trigger_exclusive_goal_escrow_refund`

- set eta = goal.exp + 65 sec (prevent early refund)
- Trigger Task `check_trigger_exclusive_goal_refundable`
  (預期 eta 到時 Exclusive 已經建立，所以不會觸發 refund)

---

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
