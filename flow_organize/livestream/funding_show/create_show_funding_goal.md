# Show Funding Goal

## create_new_goal

主播開始募票

Endpoint: [POST] `/goals?type=show-funding`

body:

```json
{
    "levels": [
        {
            "title": "Test",
            "target": 10
        }
    ],
    "exp": 1745914628,
    "context": {
        "perform_duration": 60,
        "session_id": "681088cb95684fc0c6496546",
        "hesitation_countdown": 30,
        "ticket_product_id": "livestream-show-ticket_134",
        "ticket_product_type": "earlybird",
        "discount_percentage": 33
    }
}
```

func create_new_goal flow:

- Execute func `create_show_funding_goal`

### create_show_funding_goal

- fetch session by
  - session_id = context['session_id']
  - user       = g.user.id (streamer)
  - active     = True

- Trigger Task `create_goal` with args
  - active = True
  - _cls   = ShowFundingGoal
  - conditions
    - session_id = session_id
  - levels.0
    - title: "Test"
    - target: 10
  - context
    - type                 = 'show-funding'
    - perform_duration     = 60,
    - session_id           = "681088cb95684fc0c6496546",
    - hesitation_countdown = 30,
    - ticket_product_id    = "livestream-show-ticket_134",
    - ticket_product_type  = "earlybird",
    - discount_percentage  = 33
  - metadata
    - user_id = g.user.id
  - exp = exp

### Task `create_goal`

- create goal `ShowFundingGoal`
  - active
  - conditions
  - levels
  - nbf
  - exp
  - context
  - metadata

- Send Signal `features.leaderboards` with sender `goal.created`
  - **args**:
    - goal_id    = goal.id,
    - active     = True,
    - _cls       = ShowFundingGoal,
    - conditions
      - session_id = session_id
    - context
      - type                 = 'show-funding'
      - perform_duration     = 60,
      - session_id           = "681088cb95684fc0c6496546",
      - hesitation_countdown = 30,
      - ticket_product_id    = "livestream-show-ticket_134",
      - ticket_product_type  = "earlybird",
      - discount_percentage  = 33
    - levels.0
      - title: "Test"
      - target: 10
    - nbf = None
    - exp = goal.exp,

  - **receivers**
    - bind_karaoke_goal_to_session **return**
    - bind_exclusive_goal_to_trigger_exclusive_goal **return**
    - bind_exclusive_goals_to_session **return**
    - bind_trigger_private_goal_to_session **return**
    - snapshot_rtc_sources **return**
    - bind_show_goal_to_funding_goal **return**
    - track_goals
      Trigger Task analytics.tasks.track
    - **bind_show_goals_to_session**
    - **schedule_lifecycle_tasks**

### Signal `goal.created`

#### bind_show_goals_to_session

- !!!fetch and update `Session` (new=True)
  - filter:
    - id = conditions['session_id]
    - show_goal_pairs__funding_goal__ne goal_id
  - modify:
    - push__show_goal_pairs = Session.ShowGoalPair(funding_goal=goal_id)

- Send Signal `features.leaderboards` with sender `goal.added`
  - **args**:
    - goal_id     = goal_id
    - _cls        = ShowFundingGoal
    - conditions
      - session_id = session_id
    - context
      - type                 = 'show-funding'
      - perform_duration     = 60,
      - session_id           = "681088cb95684fc0c6496546",
      - hesitation_countdown = 30,
      - ticket_product_id    = "livestream-show-ticket_134",
      - ticket_product_type  = "earlybird",
      - discount_percentage  = 33
    - session_id  = session.id
    - streamer_id = session.user.id
  - **Receivers**:
    - `generate_livestream_feed`
    - `trigger_notify_goal_added`
      - targets:
        - f'presence-stream@{streamer_id}',
        - f'private-stream@{streamer_id}',
        - f'private-user@{streamer_id}',
      - events: goal.added
    - notify_stream_authorized **returned**
    - `invalidate_cached_pusher_channel_data`

#### schedule_lifecycle_tasks

- Trigger Task `deactivate_goal` with eta exp
  - goal_id
  - exp

---

## If ShowFundingGoal Expired...

Task `deactivate_goal`

- !!!fetch Goal and modify: (new=False)
  - active = False
  - min__exp

- Send Signal `features.leaderboards` with sender `goal.ended`
  - **args**:
    - goal_id
    - _cls     = ShowFundingGoal
    - active   = False
    - progress = goal.progress (0)
    - levels.0
      - 'title'
      - 'target'
    - conditions
      - session_id
    - context   = goal.context
      - type                 = 'show-funding'
      - perform_duration     = 60,
      - session_id           = "681088cb95684fc0c6496546",
      - hesitation_countdown = 30,
      - ticket_product_id    = "livestream-show-ticket_134",
      - ticket_product_type  = "earlybird",
      - discount_percentage  = 33
    - exp       = exp
    - triggerer = None,
    - metadata  = None,
  - **Receivers**:
    - trigger_exclusive_on_close_notification **returned**
    - notify_stream_authorized_for_agreed_trigger_goal **returned**
    - notify_stream_authorized_for_ended_exclusive_goal **returned**
    - `track_goals`
    - `notify_goal_ended`
      - events: `goal.ended`
      - targets:
        - private-stream@{session.user.id}
        - presence-stream@{session.user.id}
        - private-user@{session.user.id}
    - `set_embedded_goal_ended`
    - `trigger_show_escrow_refund`
    - trigger_exclusive_goal_escrow_refund
    - handle_trigger_private_goal_escrow
    - cleanup_expired_exclusive_goal_pairs
    - sync_trigger_goal_session_viewer
      Put `goal.breakdown` user list into `session.viewers`
    - invalidate_cached_pusher_channel_data
    - snapshot_rtc_sources

### `goal.ended`

#### `set_embedded_goal_ended`

- !!!Update Session:
  - filter:
    - show_goal_pairs__funding_goal = goal_id
  - modify:
    - set__show_goal_pairs__S__funding_ended = now

#### `trigger_show_escrow_refund`

- ...IF progress . levels.0.target (募票成功) -> returned
- eta = exp + context['hesitation_countdown'] + 5
- Trigger Task `check_funding_goal_refundable`
  - **args**
    - goal_id
  - **link**: `escrow_refund`
    - escrow_id = f'show_funding:{goal_id}'
    - user_id   = session.user.id
    - nbf       = session.statuses.created
    - exp       = session.statuses.ended
  
**check_funding_goal_refundable**

- Proceed with fetched Session:
  - id = goal_id
  - context__show_goal_id__exists = False

**escrow_refund**

- Fetch `Earning` as targets
  - filter:
    - user_id = user_id
    - _show_funding:{goal_id} exist

- Trigger Task `update_bi_escrow` by each earning:
  - link: `transfer_escrow` -> 後續會進行 wallet transfer
    - event: 'escrow.failed'
    - escrow_id = show_funding:{goal_id}
    - metadata
      - doc_id  = earning.id
      - user_id = user_id

-- 
