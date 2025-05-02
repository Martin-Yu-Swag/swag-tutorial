# Exclusive Session

- [DELETE] `/goals/{goal_id}`  接受邀請 = 刪除 `TriggerExclusiveGoal`
  (accepted)
- [POST] `/goal` 建立 `ExclusiveGoal`
  
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
