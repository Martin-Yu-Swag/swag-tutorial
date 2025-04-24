# Get session token

Endpoint: [GET] `/streams/<objectid:session_id>/token` 取得直播 token

SUMMARY: 主動取得 session byteplus token

- cache key = LIVESTREAM_TOKEN_CACHE_KEY
  (`features.livestream.get_token_by_session:{session_id}:{user_id}`)
- 如果有 cache hit -> 直接把 cache pickle.loads(result) 回傳
  (cache 的是一整個 Response object)
- Trigger Task tasks.`get_stream_token`, 取得 token
  - `user_id`
  - `session_id`
- 建立 response 物件
- 將 Response 物件 cache
- 回傳 Response

## get_stream_token

- fetch user
- fetch session (by id and active=True)
- Check at least one permission:
  - user_id = streamer_id (直播主本人)
  - scopes passed into task has Role.moderator
  - user.tags exist `curator:*`: company-related tags
  - check whether user posses valid livestream_pass
  - IF session has show_goal (last elem of show_goal_pairs)
    - IF funding_goal and show_goal: (which means show started)
    - Check whether user id in breakdown list
  - Check whether user in session.viewers list (This is mainly for authorize_livestream payer)
  IF NOT permission -> return NONE
- parse `nbf` and `exp` from permission
- generate
  - token
  - byteplus_token
  - byteplus_rtc_info_token
- return three token info

---
