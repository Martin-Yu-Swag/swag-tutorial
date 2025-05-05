# Patch Session Settings

```bash
curl 'https://api.swag.live/sessions/681831d3292549a5d91df267/settings?lang=zh-hant' \
  -X 'PATCH' \
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
  -H 'x-request-id: 51343cde-3333-4a56-a567-7ddeb0f559b7' \
  -H 'x-session-id: 9045460d-4eda-4089-b621-2acc22ed1d50' \
  --data-raw '{"trigger_private":true,"trigger_exclusive":true,"exclusive_sd_price":360,"sd_price":90}'
```

Session created 後，更新 session settings

Endpoint: [PATCH] `/sessions/<session_id>/settings`

Body:

```json
{
    "trigger_private"   : true,
    "trigger_exclusive" : true,
    "exclusive_sd_price": 360,
    "sd_price"          : 90
}
```

func flow:

- !!!Update Session:
  - filter:
    - id
    - user = g.user.id
  - update:
    - set__settings__sd_price = 90 / 60
    - set__settings__exclusive_sd_price = 360 / 60
    - set__settings__trigger_exclusive
    - set__settings__trigger_private

- Send signal `session.settings.updated`
  - **args**
    - session_id
    - updated:
      - trigger_private    = true,
      - trigger_exclusive  = true,
      - exclusive_sd_price = 360,
      - sd_price           = 90
  - **receivers**:
    - notify_session_updated
    - invalidate_cached_pusher_channel_data
