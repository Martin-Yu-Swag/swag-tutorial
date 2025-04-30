# Delete Session Before Show End

Send Signal Sender `session.ended`
- **args**:
  - session_id
  - streamer_id
  - preset          = session.status.preset
  - price           = session.get_price()
  - show_goal_pairs = session.show_goal_pairs
- **Receivers**:
  - notify_viewers_livestream_online
  - track_session_status
  - invalidate_cached_pusher_channel_data
  - `deactivate_goals_in_session`

## `session.ended` -> `deactivate_goals_in_session`

- Aggregate session:
  - $match: _id = session_id
  - $addField:
    - exclusive_pairs: $objectToArray exclusive_goal_pairs
  - $project
    - user
    - statuses
    - goals: concatArray
      - show_goal_pairs.show_goal
      - show_goal_pairs.funding_goal
      - trigger_private_goals.goal
      - exclusive_pairs.v.trigger_exclusive_goal
      - exclusive_pairs.v.exclusive_goal
  - lookup
    - localField: goals
    - as: goals
    - pipeline:
      - $project
        - id: $_id
        - type: $switch show / funding / trigger-private / trigger-exclusive / exclusive
        - target: $first levels.target
        - progress
        - nbf
- bucketsize session['goals'] by type
- FOR show: Trigger Task `deactivate_goal`
  - goal_id = id
  - eta = goal['nbf'] + goal['target']

### deactivate_goal

- Modify Session:
  - active = False
  - min__exp = exp

- Send `goal.ended`
   - **Receivers**:
     - trigger_show_escrow_refund
       -> show_goal_should_process
       progress > target (ShowGoal 的 Target 是表演時數)
       (QUESTION: who update ShowGoal progress????)
