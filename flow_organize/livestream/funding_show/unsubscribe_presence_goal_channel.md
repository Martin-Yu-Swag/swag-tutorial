# Unsubscribe presence goal channel

表演結束後，WS client 會 push event: unsubscribe `presence-enc-goal@{goal_id}` channel

```json
{
    "event": "pusher:unsubscribe",
    "data": { 
        "channel":"presence-enc-goal@68143584d6945d32e732cc21"
    }
}
```

Endpoint: [POST] `/notify/pusher`

- event name = `member_removed`
  -> state_changed_event = `channel_vacated`
- Send Signal `ext.pusher` with Sender `channel_vacated`
  - **args**
    - channel
    - user_id
  - **Receivers**
    - track_channel_presence
    - trigger_user_enter
    - trigger_online
    - `karaoke_control`

## `channel_vacated` -> `karaoke_control`

- parse vars by sender:
  - `action`    = paused
  - `fetch_new` = False

- !!!fetch and modify `Goal` (new = False)
  - filter:
    - id = goal_id
    - _cls in KaraokeGoal, ShowGoal, ExclusiveGoal
  - modify
    - max__context__last_updated = now
    - max__context__paused = now

- set vars by sender
  - started = goal.context.get('started')
  - amount = (now - started) -> to second
  - Trigger Task `increment_goal_progress`
    - goal_id
    - amount

### Task `increment_goal_progress`

- !!!filter and modify goal (new=True)
  - filter: id = goal_id
  - modify
    - `inc__progress` = amount (表演秒數)

- Send signal 'features.leaderboards' with sender `goal.progressed`:
  - **args**:
    - goal_id
    - _cls = ShowGoal
    - amount (秒數)
    - conditions
    - context
    - progress
    - breakdown_id
    - levels
      - title
      - target
    - metadata = goal.metadata
    - exp = exp
  - **Receivers**:
    - update_and_notify_session_karaoke_goal **returned**
    - notify_viewer_change_stream_for_show **returned**
    - trigger_exclusive_goal_escrow_refund **returned**
    - track_goals
    - `notify_goal_progress_updated`
      - events: `goal.progress.updated`
      - targets:
        - 'private-stream@{streamer_id}'
        - 'presence-stream@{streamer_id}'
        - 'private-user@{streamer_id}'
    - `invalidate_cached_pusher_channel_data`
      - invalidate channels data in cache:
        - 'private-user@{streamer_id}'
        - 'private-enc-user@{streamer_id}'
        - 'private-stream@{streamer_id}'
        - 'private-enc-stream@{streamer_id}'
    - `trigger_goal_complete`
      - IF new_goal.level > old_goal.level
        -> Send signal `goal.completed`

#### `goal.completed`

- **args**
  - goal_id
  - _cls = ShowGoal
  - conditions
  - context
  - progress
  - levels
  - metadata

- Receivers:
  - trigger_exclusive_escrow_transfer **returned**
  - notify_livestream_mvps **returned**
  - `track_goals`
  - `set_embedded_goal_ended`
  - `deactivate_goal`
  - `produce_livestream_clip_from_goal`
  - `record_show_with_rtc`
  - `trigger_show_escrow_transfer`

##### `goal.completed` -> `set_embedded_goal_ended`

**SUMMARY**: set `session.show_goal_pairs.$.show_ended` timestamp

- !!!update Session:
  - filter
    - id = conditions[session_id]
    - show_goal_pairs__show_goal: goal_id
  - modify
    - set__show_goal__S__show_ended = now

##### `goal.completed` -> `deactivate_goal`

- Trigger Task `deactivate_goal`
  - `goal_id`

- !!!Fetch and modify Goal: (new = False)
  - filter: id = goal_id
  - modify:
    - active   = False
    - min__exp = now

- Send Signal sender `goal_ended`
  - **args**:
    - goal_id
    - cls = `ShowGoal`
    - active = False
    - progress
    - levels
      - title
      - target
    - conditions
    - context
    - exp
    - triggerer = None
    - metadata
  - **Receivers**
    - trigger_exclusive_on_close_notification **returned**
    - notify_stream_authorized_for_agreed_trigger_goal **returned**
    - notify_stream_authorized_for_ended_exclusive_goal **returned**
    - trigger_exclusive_goal_escrow_refund **returned**
    - handle_trigger_private_goal_escrow **returned**
    - cleanup_expired_exclusive_goal_pairs **returned**
    - sync_trigger_goal_session_viewer **returned**
    - snapshot_rtc_sources **returned**
    - set_embedded_goal_ended **returned**
    - notify_goal_ended **returned**
    - trigger_show_escrow_refund **returned** becuz progress complete
    - track_goals
    - invalidate_cached_pusher_channel_data
    
##### `goal.completed` ->  `produce_livestream_clip_from_goal`

- fetch user by metadata['user_id']
- IF 'banned:livestream:create_clip' in `user.tags` -> returned
- fetch byteplus source by user
- Trigger Task `create_post_from_livestream`
  - session_id
  - caption  = levels[0]['title']
  - duration = config['LIVESTREAM_CLIP_GOAL_DURATION']
  - rewind_seconds = levels[0]['target'] // 2
  - tags = 
    - 'feed:shorts_livestream'
    - 'bypass:review'

**create_post_from_livestream**

- fetch `session` by session_id
- fetch `user` by session.user_id
- init `Asset`
  - id           = bson.ObjectId()
  - content_type = video/mp4
  - duration     = duration
  - metadata
    - source
      - cls: 'Session'
      - id: session.id

- Create `Post`
  - sender = user_id
  - tags =
    - 'drafts'
    - 'beta'
    - 'no_exposure'
    - ...user.tags
    - 'feed:shorts_livestream'
    - 'bypass:review'

- Trigger Task `clip_livestream_as_asset`
  - session_id
  - rewind_seconds
  - duration
  - asset_id
  - metadata
    - 'auto_claimed_by:{post.id}': 'message-{post.id}:0'
  
**clip_livestream_as_asset**

Prepare clip and upload to quarantine bucket

##### `goal.completed` -> `record_show_with_rtc`

Trigger Task `StopRecord`

##### `goal.completed` -> `trigger_show_escrow_transfer`

Trigger Task `escrow_out`
  - escrow_id = 'show_funding:{funding_goal_id}'
  - user_id   = session.user_id
  - nbf       = session.statuses.started
  - exp       = now (if session not ended)

**escrow_out**

- set exp = exp + 1 hour
- fetch `Earning` as targets
  - user_id = user_id
  - "_show_funding:{funding_goal_id}": `$exits`
- Trigger task chain for each target:
  - `update_bi_escrow`
  - `transfer_escrow`
    - to_user_id = user_id
    - escrow_id  = 'show_funding:{funding_goal_id}'
    - event      = escrow.completed
    - metadata
      - doc_id = target.id
      - user_id = user_id

**transfer_escrow**

- Trigger task chian transfer
  - `transfer`
    - transfer_id  = 'escrow-show_funding:{funding_goal_id}-{doc_id}-{user_id}'
    - from_user_id = None
    - to_user_id   = user_id
    - amount       = amount
    - tags         = 'escrow::show_funding:{funding_goal_id}'
  - Send wallet signal with sender `escrow.completed.individual`
    - to_user_id
    - escrow = show_funding:{funding_goal_id}
- Send wallet signal with sender `escrow.completed`
