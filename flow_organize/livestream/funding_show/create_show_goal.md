# Create Show Goal

Endpoint: [POST] `/goals?lang=zh-hant&type=show`

Body:

```json
{
    "levels": [
        {
            "title" : "Proceed",
            "target": 60
        }
    ],
    "context": {
        "funding_goal_id"    : "6811c05bf672c8b2cbdc2432",
        "session_id"         : "6811bfd5d273022b46570ae5",
        "ticket_product_id"  : "livestream-show-ticket_200",
        "ticket_product_type": "show"
    },
    "nbf": 1745993863
}
```

func `create_new_goal` flow:

Trigger Task `create_show_goal`

## Task `create_show_goal`

- fetch corresponding `ShowFundingGoal` by
  - goal_id                       = context['funding_goal_id']
  - exp__exists                   = True
  - exp__lt                       = now
  - context__show_goal_id__exists = False

- fetch `session` by context['session_id']

- Trigger Task `create_goal` with
  - active=True
  - _cls = ShowGoal
  - condition
    - session_id
  - levels.0
    - target
    - title
  - metadata
    - user_id = g.user.id (streamer)
  - nbf = nbf
  - context
    - type = "show"
    - funding_goal_id
    - session_id
    - ticket_product_id
    - ticket_product_type

## Task create_goal

- create `ShowGoal`
  - active = True
  - conditions
    - session_id
  - levels.0
    - target
    - title
  - nbf = nbf
  - exp = None
  - context
    - type = "show"
    - funding_goal_id
    - session_id
    - ticket_product_id
    - ticket_product_type
  - metadata
    - user_id = g.user.id (streamer)

- Send signal 'features.leaderboards' with sender `goal.created` 
  - **args**
    - goal_id    = goal.id,
    - active     = True,
    - _cls       = `ShowGoal`,
    - conditions
      - session_id
    - context
      - type = "show"
      - funding_goal_id
      - session_id
      - ticket_product_id
      - ticket_product_type
    - levels.0
      - title
      - target
    - nbf        = goal.nbf,
    - exp        = None
  - Receivers
    - bind_karaoke_goal_to_session **return**
    - bind_exclusive_goal_to_trigger_exclusive_goal **return**
    - bind_exclusive_goals_to_session **return**
    - bind_trigger_private_goal_to_session **return**
    - snapshot_rtc_sources **return**
    - `track_goals`
      Trigger Task analytics.tasks.track
    - `bind_show_goal_to_funding_goal`
    - `bind_show_goals_to_session`
    - `schedule_lifecycle_tasks`

### `goal.created` -> `bind_show_goal_to_funding_goal`

- !!!Update Goal
  - filter: id = context['funding_goal_id']
  - update: set__context__show_goal_id=goal_id

### `goal.created` -> `bind_show_goals_to_session`

- !!!Update Session
  - filter:
    - id conditions['session_id']
    - show_goal_pairs__funding_goal context['funding_goal_id']
  - modify (new = True)
    - set__show_goal_pairs__S__show_goal
- Send signal `goal.added`
  - **args**
    - goal_id     = goal_id,
    - _cls        = ShowGoal,
    - conditions
      - session_id
    - context
      - type = "show"
      - funding_goal_id
      - session_id
      - ticket_product_id
      - ticket_product_type
    - session_id  = session.id,
    - streamer_id = session.user.id,
  - **Receivers**:
    - `generate_livestream_feed`
    - `trigger_notify_goal_added`
    - `notify_stream_authorized`
      - invalidate_get_session_token_view_cache
    - `invalidate_cached_pusher_channel_data`

### `goal.created` -> `schedule_lifecycle_tasks`

- Trigger Task `activate_goal` with eta=nbf
  - goal_id
  - nbf

#### `activate_goal`

- Fetch `ShowGoal` and modify
  - filter:
    - id = goal_id
    - active = False
  - modify
    - active = True
    - nbf = nbf
- Send Signal `goal.started`
  - **args**:
    - goal_id    = goal.id,
    - _cls       = ShowGoal,
    - conditions
      - session_id
    - context
      - type = "show"
      - funding_goal_id
      - session_id
      - ticket_product_id
      - ticket_product_type
    - progress   = goal.progress,
    - levels.0
      - title
      - target
    - metadata
      - user_id
  - **Receivers**:
    - trigger_external_command **returned**
    - update_and_notify_session_karaoke_goal **returned**
    - `notify_show_goal_started`
      - targets:
        - f'private-stream@{streamer_id}',
        - f'presence-stream@{streamer_id}',
        - f'private-user@{streamer_id}',
      - events: `goal.started`
    - `record_show_with_rtc`
      - Execute byteplus Task `StartRecord`
    - `invalidate_cached_pusher_channel_data`
    - `notify_stream_authorized`

##### `goal.started` -> `notify_stream_authorized`

- Aggregate show vars:
  (for further batch notification)
  - $match: _id in [goal_id, context['funding_goal_id]]
  - $facet
    - funding_goal
      - $match: _cls = ShowFundingGoal
      - $project:
        - breakdown
    - show_goal
      - $match: _cls = ShowGoal
      - $addField
        - show_targets: $let
          - vars: level0 = $last $levels
          - in: $$llevel0.target
  - $unwind $funding_goal
  - $unwind $show_goal
  - $addField:
    - show_goal.conditions.session_id: $toObjectId $show_goal.conditions.session_id
  - $lookup:
    - localField: show_goal.conditions.session_id
    - as: session
    - pipeline
      - $project id = $_id, user = True
  - $unwind: session
    (currently: show_goal:obj, funding_goal:obj, session:obj)
  - $project
    - session_id (session.id)
    - streamer_id (session.user)
    - nbf (show_goal.nbf)
    - viewers: $let
      - vars breakdown = $objectToArray $funding_goal.breakdown
      - in: $$breakdown.k
    - exp: $let
      - vars:
        - remaining_seconds = 1000 * '$show_goal.show_target' - '$show_goal.progress'
          ???QUESTION: What's the meaning of this???
        - show_starts_at
          - $ifNull: $show_goal.context.started, $show_goal.nbf
      - in: $$remaining_seconds + $$show_starts_at

- batch notify (preview):
  - targets:
   'presence-stream-viewer@{show["streamer_id"]}.preview.{viewer}' for viewer in show.viewers
  - event: `stream.authorized`

- batch notify (sd)
  - targets:
    'presence-stream-viewer@{show["streamer_id"]}.sd.{viewer_id}' for viewer in show.viewers
  - event: `stream.authorized`
  - data with token, byteplus_token, byteplus_rtc_info
