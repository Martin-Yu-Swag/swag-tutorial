# Extend

```bash
curl 'https://api.swag.live/goals/6818339ed723c3b9a6c4cfe1/extend?lang=zh-hant' \
  -X 'PUT' \
  -H 'accept: */*' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJzdWIiOiI2ODAwYTkwNzNlMGMzNDY1MzE5NThiMDMiLCJqdGkiOiJmc2xORDQ1RGV4Y3I3S0lpIiwiaXNzIjoiYXBpLnN3YWcubGl2ZSIsImF1ZCI6ImFwaS5zd2FnLmxpdmUiLCJpYXQiOjE3NDY0MTU4NTQsImV4cCI6MTc0NjQxOTQ1NCwidmVyc2lvbiI6Miwic2NvcGVzIjpbIlBBSUQiLCJIVU1BTiIsIkNSRUFUT1IiXSwibWV0YWRhdGEiOnsiZmluZ2VycHJpbnQiOiJkMjc5M2RkNCIsImZsYXZvciI6InN3YWcubGl2ZSIsIm9yaWdpbmFsIjp7ImlhdCI6MTc0NTgwNzc5OSwibWV0aG9kIjoicGFzc3dvcmQifX19.YMxdftUERTBjcYuew2iWKjOLt0tZ8t7TEymSiSKoUqo' \
  -H 'cache-control: no-cache' \
  -H 'content-length: 0' \
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
  -H 'x-request-id: d3fb9ed9-7ace-4cb3-b7a8-bec085c8f019' \
  -H 'x-session-id: 9045460d-4eda-4089-b621-2acc22ed1d50'
```

1 on 1 超過預買的 300 秒後

- Endpoint: [PUT] `/goals/{goal_id}/extend`

func `extend_goal` flow:

- Fetch Goal by
  - id                 = goal_id
  - _cls               = ExclusiveGoal
  - active             = True
  - metadata__user__id = g.user.id (streamer)

- Trigger Task `update_session_viewer_permissions`
  - session_id        = goal.context['session_id']
  - viewers           = goal.context['exclusive_to']
  - nbf               = now
  - duration          = 60
  - notify_sd_viewers = True

Task **update_session_viewer_permissions**:

- !!!Update Session (new = True):
  - filter: session_id
  - modify __raw__:
    - $set:
      - viewers.{viewer_id}.nbf $ifNull [$viewers.{viewer_id}.nbf, $nbf]
      - viewers.{viewer_id}.duration: `$add`
        - `$max` [f'$viewers.{viewer_id}.duration', 0]
        - duration (60)
      - viewers.{viewer_id}.exp: `$add`
        - '$max': [nbf, f'$viewers.{viewer_id}.exp']
        - duration * 1000

- Batch Notify
  - events: `stream.authorized`
  - targets: presence-stream-viewer@{streamer_id}.sd.{viewer_id}
