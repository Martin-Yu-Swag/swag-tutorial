# Update Session Price

1 on 1 開始後，調整 session sd 價格為 exclusive form

Endpoint: [PATCH] `/sessions/<session_id>/price`

Body:

```json
{
    "sd": 540 // price of exclusive show
}
```

func flow:

- !!!Update `Session` (new = True)
  - filters:
    - id
    - user = g.user.id
    - active = True
  - modify __raw__:
    - $set:
      - Session.pricing_before.db_field = ${Session.pricing.db_field}
      - pricing.sd                      = Session.SessionPricing.sd.to_mongo(sd)

- Send Signal `session.pricing.updated`
  - **args**:
    - session_id
    - streamer_id
    - preset
    - price
    - pricing_before
  - **Receivers**:
    - track_session_status
    - generate_livestream_feed
    - notify_session_updated
    - invalidate_cached_pusher_channel_data
