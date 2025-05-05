# Create Exclusive Goal

```bash
curl 'https://api.swag.live/goals?lang=zh-hant&type=exclusive' \
  -H 'accept: */*' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJzdWIiOiI2ODAwYTkwNzNlMGMzNDY1MzE5NThiMDMiLCJqdGkiOiJmc2xORDQ1RGV4Y3I3S0lpIiwiaXNzIjoiYXBpLnN3YWcubGl2ZSIsImF1ZCI6ImFwaS5zd2FnLmxpdmUiLCJpYXQiOjE3NDY0MTU4NTQsImV4cCI6MTc0NjQxOTQ1NCwidmVyc2lvbiI6Miwic2NvcGVzIjpbIlBBSUQiLCJIVU1BTiIsIkNSRUFUT1IiXSwibWV0YWRhdGEiOnsiZmluZ2VycHJpbnQiOiJkMjc5M2RkNCIsImZsYXZvciI6InN3YWcubGl2ZSIsIm9yaWdpbmFsIjp7ImlhdCI6MTc0NTgwNzc5OSwibWV0aG9kIjoicGFzc3dvcmQifX19.YMxdftUERTBjcYuew2iWKjOLt0tZ8t7TEymSiSKoUqo' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'origin: https://swag.live' \
  -H 'pragma: no-cache' \
  -H 'priority: u=1, i' \
  -H 'referer: https://swag.live/' \
  -H 'sec-ch-ua: "Google Chrome";v="135", "Not-A.Brand";v="8", "Chromium";v="135"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-site' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36' \
  -H 'x-client-id: ac9cd42b-2982-430f-bdd0-18b0ce505d0a' \
  -H 'x-request-id: b3c220d5-02de-4a9b-91ae-0bd9643af014' \
  -H 'x-session-id: 9045460d-4eda-4089-b621-2acc22ed1d50' \
  --data-raw '{"levels":[{"target":300}],"context":{"session_id":"681831d3292549a5d91df267","trigger_exclusive_goal_id":"68183380860748ad566a6aca"},"nbf":1746416602.371}'
```

倒數結束後開始私密直播

Endpoint: [POST] `/goal?type=exclusive`

Body:

- levels.0
  - target = 300 (需預先購買5分鐘)
- context:
  - session_id
  - trigger_exclusive_goal_id
  - nbf

func flow:

- Execute `create_exclusive_goal` and return goal_id

## create_exclusive_goal

- receive json body from decorator injection
  - levels
  - context
    - session_id
    - trigger_exclusive_goal_id
  - nbf

- fetch session by
  - id = session_id
  - user = user.id (streamer)
  - active = True

- fetch Goal by
  - id = context['trigger_exclusive_goal_id']
  - exp exist
  - exp < now
  - context__exclusive_goal_id__exists False
    (not bound to exclusive goal)

- Trigger Task `create_goal` with args:
  - active     = True,
  - _cls       = ExclusiveGoal
  - conditions
    - session_id
  - levels.0
    - target = 300
  - metadata
    - user_id (streamer_id)
  - context
    - type = exclusive
    - exclusive_to = goal.conditions['exclusive_to']
    - session_id
    - trigger_exclusive_goal_id
  - nbf

## Task `create_goal`

- create goal: `ExclusiveGoal`
  - active = True
  - conditions
    - session_id
    - exclusive_to
  - levels.0
    - target = 300
  - nbf = nbf
  - exp = None
  - context
    - type = exclusive
    - exclusive_to
    - session_id
    - trigger_exclusive_goal_id
  - metadata
    - user_id (streamer_id)

- Send Signal `features.leaderboards` with sender `goal.created`
  - **args**:
    - goal_id    = goal.id
    - active     = active
    - _cls       = _cls
    - conditions
      - session_id
      - exclusive_to
    - context
      - type = exclusive
      - exclusive_to
      - session_id
      - trigger_exclusive_goal_id
    - levels.0
      - target = 300 sec
    - nbf
    - exp = None
  - **Receivers**:
    - bind_karaoke_goal_to_session **return**
    - bind_trigger_private_goal_to_session **return**
    - bind_show_goal_to_funding_goal **return**
    - bind_show_goals_to_session **return**
    - track_goals
    - `bind_exclusive_goal_to_trigger_exclusive_goal`
      !!!Update Goal:
      - set__context__exclusive_goal_id = goal_id

    - `bind_exclusive_goals_to_session`
      !!!Update Session
      - `set__exclusive_goal_pairs__{exclusive_to}__exclusive_goal` = goal_id

    - `snapshot_rtc_sources`
      Disable snapshot on exclusive start

    - `schedule_lifecycle_tasks`
      - `activate_goal` with eta = nbf

## `goal.created` -> `snapshot_rtc_sources`

**SUMMARY**: Disable snapshot on exclusive start, enable at end.

- proceed only with goal_id of `ExclusiveGoal`
- loop through user's sources:
  - get `room_id` and `session_id` from source
  - Trigger Task `byteplus.tasks.rtc.StopSnapshot`
    - RoomId=room_id
    - TaskId=task_id
  
---

After eta -> activate_goal

## Task `activate_goal`

- !!!Update `Goal`:
  - filter:
    - id = goal_id
    - active = False 

-> BUT ExclusiveGoal is already active, Noting to update, **returned**
