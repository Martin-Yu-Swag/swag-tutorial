# authorize_livestream

進入直播後每過一個 duration (60s) 就會 trigger 一次

SUMMARY:
  - wallet 付款
  - 建立 `byteplus_token`, `byteplus_rtc_info` 並回傳
  - 透過 pusher 推送 `stream.authorized` event, 並夾帶 `byteplus_token` 與 `byteplus_rtc_info`, 如果重新載入頁面，可從 pusher message 中 parse 出 token，而不需要重新 POST /pay request 一次
  - NOTE: response 與 notification 的 `byteplus_rtc_info` user_id 的 timestamp 組成有差異，因 byteplus 用一樣的會有 error

- Endpoint: [POST] `/sessions/{session_id}/pay`
- data:

```json
{
    "duration": 60
}
```

func flow:

- ...IF auth user has one of tags: STATS / SIGNED ()
  -> return 403
- fetch `Session` by session_id
- Get `amount` of session by reset (always "sd") and duration
  - Defined in `SessionPrice` EmbeddedDocument
- IF `session.status.exclusive_to` exist AND != user.id
  -> means 1 on 1 stream, and user is not the one, return 403
- Get user `balance` and check is enough

- Async Trigger Task `pay`, link task sending signal `payment.succeeded` if success

- return response:
  - token
    (from Task `generate_token`)
  - byteplus_token
    (from Task `generate_byteplus_token`)
  - byteplus_rtc_info
    - user_id
      (`{g.user.id}__{request.endpoint}__{int(time.time())}`)
      (eg. 67ceabecc82b8fd6cf63d6d6__features.livestream.authorize_livestream__1745311596)
    - token
      (from Task `generate_byteplus_token`)
  - nbf
    (now)
  - exp
    (now + duration)

---

## Task `pay`

SUMMARY: init request to wallet service for transaction, and signal `payment.succeeded` sender

with args:
  - streamer_id
  - session_id
  - user_id
  - amount
  - exclusive (bool)

- tags = 
  - ...IF exclusive [f"swag::livestream.session:{session_id}.exclusive"]
  - ...ELSE [f"swag::livestream.session:{session_id}.view]

- execute Task function `transfer` with args:
  - from_user_id (viewer)
  - to_user_id (streamer)
  - amount
  - tags
  - timestamp=now

**transfer**

- fetch `from_user` by from_user_id:
  - from_account = from_user.wallet_id
  - from_amount = amount

- fetch `to_user` by to_user_id:
  - to_account = to_user.wallet_id
  - to_amount = amount

- Trigger `wallet.tasks.transfer`

- Return transaction id

...After `transfer`, Sending `feature.livestream` signal with `payment.succeeded` sender.

Receivers:

- `track_mixpanel`
  trigger `analytics.tasks.track`

- `session_payment_received`: generate auth token then batch-notify

### `payment.succeeded` -> `session_payment_received`

SUMMARY:
  - create auth token
  - batch notification for `stream.authorized` event

- !!!Update Session by session_id:
  - set:
    - `viewers.{viewer_id}.nbf` = ifNull [viewers.{viewer_id}.nbf, now]
    - `viewers.{viewer_id}.duration` = 
    max($viewers.{viewer_id}.duration, 0) + duration
    - `viewers.{viewer_id}.exp` = max(now, $viewers.{viewer_id}.exp) + duration * 1000
  - project:
    - user
    - viewers.{viewer_id}

- generate JWT `token` with
  - streamer_id
  - viewer_id
  - nbf
  - exp

- generate `byteplus_token`
  - with
    - session_id
    - identifier (viewer_id)
    - exp
  - create token with **PrivateSubscribeStream**

- generate `byteplus_rtc_info`:
  - user_id = f'{viewer_id}__session_payment_received__{int(time.time())}'
  - token = tasks.generate_byteplus_token()

- vars `data` dict:
  - nbf = viewer['nbf']
  - exp = viewer['exp']
  - jitter_factor = DEFAULT_JITTER_FACTOR (3)

- trigger `notifications.tasks.batch`
  - target = f'presence-stream-viewer@{streamer_id}.{preset}.{viewer_id}'
  - event `stream.authorized`
  - data = token, byteplus_token, byteplus_rtc_info, **data

- trigger `notifications.tasks.batch`
  - target presence-stream-viewer@{streamer_id}.preview.{viewer_id}'
  - event 'stream.authorized'
  - data = data

