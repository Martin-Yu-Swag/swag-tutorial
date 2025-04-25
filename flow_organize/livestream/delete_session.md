# Delete session

endpoint: [DELETE] `/sessions/<objectid:session_id>`

func `deactivate_session` flow:

- fetch session by session_id
- Trigger task `disconnect`
  args:
  - streamer_id
  - session_id
  - device_disconnect_countdown = None
- return response OK

## disconnect

- fetch session:
  filter:
  - user=streamer_id
  - id=session_id
  - active=True
- Execute Task `deactivate_session`
  args: session_id

## deactivate_session

**SUMMARY**: set active False, timestamped statuses.ended, byteplus BanRoomUser, send `session.ended` signal

- fetch session and modify:
  - filter by session_id and active
  - !!!UPDATE: modify: (new=False,upsert=False)
    - active = False
    - statuses.ended = now
- Find first and aggregate `Source`:
  - filter by user id
  - `$match` metadata.provider = byteplus
  - IF found -> Execute byteplus.tasks.rtc.BanRoomUser
- Send signal `features.livestream` with sender `session.ended`
  - args
    - session_id      = session.id,
    - streamer_id     = session.user.id,
    - preset          = session.status.preset,
    - price           = session.get_price(),
    - show_goal_pairs = p.to_mongo().to_dict() for p in session.show_goal_pairs
  - Receivers
    - `generate_livestream_feed`
    - `notify_viewers_livestream_online`
    - `track_session_status`
    - `deactivate_goals_in_session`
    - `invalidate_cached_pusher_channel_data`

### `session.ended` -> `deactivate_goals_in_session`

- fetch and aggregate session:
  - `$match`: session_id
  - `addFields`
    - exclusive_pairs: objectToArr exclusive_goal_pairs
      [{k: user_id, v: ExclusiveGoalPair}]
  - `$project`:
    - user
    - statuses
    - goals: concatArrays
      - show_goal_pairs.show_goal
      - show_goal_pairs.funding_goal
      - trigger_private_goals.goal
      - exclusive_pairs.v.trigger_exclusive_goal
      - exclusive_pairs.v.exclusive_goal
  - `$lookup`: Goal collection on goals
    pipeline:
    - `$project`
      - id = $_id
      - type: $switch by $_cls
        - ShowGoal -> show
        - ShowFundingGoal -> funding
        - TriggerPrivateGoal -> trigger-private
        - TriggerExclusiveGoal -> trigger-exclusive
        - ExclusiveGoal -> exclusive
      - target: first levels.target
      - progress
      - nbf
- goal = bucketsize session["goals"] by goal["type]

- loop through "funding" goals:
  - Trigger task `deactivate_goal`

  - ...IF goal['progress'] >= goal['target']:
    Trigger task check_funding_goal_refundable
    - ...IF funding goals possess `context.show_goal_id` -> no need to return
    - ...ELSE: trigger `escrow_refund`

- loop through "show" goals:
  - Trigger Task `deactivate_goal` with eta (5min later)

- loop through "trigger-private", "trigger-exclusive", "exclusive" goals:
  - Trigger Task `deactivate_goal`

END of `deactivate_goals_in_session`

#### deactivate_goal

- fetch Goal and modify: (new=False)
  - filter: goal_id
  - !!!UPDATE:
    - active=False
    - min.exp = now

- IF goal is already not active -> return

- Send signal `features.leaderboards` with sender `goal.ended`

####
