# Pay Authorize

進入 1 on 1 直播過 5 分鐘後，透過 `/pay` 來付款

- Body:

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

- Fetch `Session` by
  - user = streamer_id
  - active = True

- Get session price
  - preset = "sd"
  - duration = 60

- check user_balance > amount

- Trigger Task `pay`
  - **args**:
    - streamer_id
    - session_id
    - user_id
    - amount
    - exclusive = True
  - link task Send signal `payment.succeeded`:
    - **args**:
      - streamer_id
      - session_id
      - viewer_id
      - duration = 60
      - cost = amount
      - exclusive = True
    - **Receivers**:
      - track_mixpanel
      - `session_payment_received`

## Task `pay`
  
- execute `transfer`
  - from_user_id
  - to_user_id
  - tags
    - f'swag::livestream.session:{session_id}.exclusive',
  - timestamp = now

- Trigger Task `transfer`
  - from_account
  - from_amount = amount
  - to_account
  - to_amount = amount
  - forced = False
  - tags
    - f'swag::livestream.session:{session_id}.exclusive'
  - timestamp = now
  - transaction_id = None

---

## `payment.succeeded` -> `session_payment_received`

- !!!Update `Session` by id:
  - $set:
    - `viewers.{viewer_id}.nbf` = ifNull [viewers.{viewer_id}.nbf, now]
    - `viewers.{viewer_id}.duration` = 
    max($viewers.{viewer_id}.duration, 0) + duration
    - `viewers.{viewer_id}.exp` = max(now, $viewers.{viewer_id}.exp) + duration * 1000
  - $project:
    - user
    - viewers.{viewer_id}
  
- batch notify:
  - targets: 'presence-stream-viewer@{streamer_id}.{preset}.{viewer_id}'
  - events: 'stream.authorized'

- batch notify:
  - targets: 'presence-stream-viewer@{streamer_id}.preview.{viewer_id}'
  - events: 'stream.authorized'

---

Wallet Callback

Endpoint: [POST] `/notify/wallet/transaction`

body:

```json
{
    "transaction_id": "",
    "timestamp"     : "",
    "tags"          : [
        "swag::livestream.session:{session_id}.exclusive",
    ],
    "from_account"  : "viewer-wallet-id",
    "from_amount"   : "amount",
    "to_account"    : "streamer-wallet-id",
    "to_amount"     : "amount",
}
```
