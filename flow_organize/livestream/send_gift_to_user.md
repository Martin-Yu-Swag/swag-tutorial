# Send Gift to User

Endpoint: [POST] `/users/<objectid:user_id>/gift/<product_id>`

Args:

- product_id (livestream-show-ticket_1200)

Queries:
  - count (min = 1)

before func:

- through **KYC** decorator
  - KYC = Know Your Customer, verify user for obeying regulation
  - See 4_swag_server_knowledge for detailed explanation
  - examine any(a series of check)

func flow:

- execute function `tasks.send_gift` with args:
  - product_id
  - count
  - sender_id
  - receiver_id (this is streamer)
  - upcoming = g.config['beta']

- Get `gift_id` from task, and return this id in response

## tasks.send_gift

- Fetch `GiftProduct` by `product_id`
- Fetch Receiver `User` by `receiver_id`
- Check if receiver is has creator tags
- set vars
  - `product_categories`       = product.category (eg. ['livestream-show-ticket'])
  - `extra_product_categories` = set()
  - product_price              = product.skus[0].price.amount (NOTE: 因為是鑽石交易，skus 必定只有一個 item)
  - tags                       = set()
  - metadata                   = {"count": count}
  - escrow_id                  = None

- IF product posses any `livestream-*` tag:
  **SUMMARY**: Add livestream-related tag and metadata

  - Fetch session (by receiver_id + active=True)
  - ...IF sender is session's exclusive user -> metadata["exclusive"] = True
  - `tags`.add(f'swag::livestream.session:{session["id"]}.gift')
  - `extra_product_categories`.add('livestream')
  - loop through tag in `product_categories`

    - ...IF tag match LIVESTREAM_KARAOKE_GIFT_CATEGORY
      **SUMMARY**: karaoke-related `tags` and `metadata`
      ...Since i'm tracking ticket only, so skip this...

      - `tags`.add(f'swag::livestream.session:{session["id"]}.karaoke')
      - `extra_product_categories`.add('livestream-karaoke')
      - ...IF product.metadata.device
        - metadata['device'] = product.metadata.device
      
    - ...IF tag match LIVESTREAM_SHOW_GIFT_CATEGORY
      **SUMMARY**: append related show goal id data on `tags` and `metadata`

      - pluck session's `show_goal_pairs` field data (current = last item of goal pairs)
      - parse valid `running_goal_id` (IF NOT -> raise 404)
        - IF funding not ended -> `running_goal_id` = funding_goal_id
        - IF show not ended -> `running_goal_id` = show_goal_id
      - append related field data:
        - `metadata`['funding_goal_id'] = funding_goal_id
        - escrow_id = f'show_funding:{funding_goal_id}'
        - `tags`.add
          f'swag::livestream.session:{session_id}.show_funding:{funding_goal_id}'
        - `extra_product_categories`.add
          'livestream-show'

    (END OF LOPPING AND IF BLOCK)

- reduce `product_categories` to related-gift tag only:
  - filter list: if any of match:
    (result: 'livestream-show-ticket')
    - not 'livestream-karaoke-*'
    - match 'livestream-karaoke-{receiver.id}'
    - match 'livestream-karaoke-default'
  - Add `extra_product_categories`
    (in ticket case: 'livestream', 'livestream-show')

- !!!Insert `Gift` object `gift`
  - id (new ObjectID)
  - sender
  - receiver
  - product (GiftedProduct)
    - id = product.id
    - name = product.name
    - categories=product_categories
  - cost (Diamond)
    - amount = product_price * amount
  - metadata: count, exclusive, device, funding_goal_id

- add `tags` set:
  - 'swag::gift:{`gift`.id}'
  - 'swag::gift.product:{`gift`.product.id}'

  - [NOTE]: total tags for **buying ticket**:
    - 'swag::livestream.session:{session["id"]}.gift'
    - 'swag::livestream.session:{session["id"]}.show_funding:{funding_goal_id}'
    - 'swag::gift:{gift.id}'
    - 'swag::gift.product:{gift.product.id}'

- Init Task chain and link task
  - chaining:
    - `swag.tasks.transfer`
      Call wallet service
    - `save_gift_transaction`
      Update Gift record of transaction related field
  - link task:
    - Send `gifts` signal with `gift.sent` sender

### Task `save_gift_transaction`

**SUMMARY**: After wallet transaction, update Gift record (sent_at, cost.timestamp, cost.wallet_transaction_id)

- args:
  - `wallet_transaction_id` (received from parent task `transfer`)
  - `gift_id`

- !!!Update `Gift` by id
  - set 
    - TIMESTAMPED `sent_at`
    - TIMESTAMPED `cost.timestamp`
    - `cost.wallet_transaction` = wallet_transaction_id
  
### Signal `gifts`: `gift.sent` Sender

Args:

- gift_id            = gift.id,
- sender_id          = gift.sender.id,
- receiver_id        = gift.receiver.id,
- product_id         = gift.product.id,
- product_categories = product_categories,
  RESULT
  - `livestream-show-ticket`
  - `livestream`
  - `livestream-show`
- cost_amount        = gift.cost.amount,
- metadata           = gift.metadata,
  RESULT
  - count
  - funding_goal_id
- tags               = tags,
  RESULT
  - `swag::livestream.session:{session["id"]}.gift`
  - `swag::livestream.session:{session["id"]}.show_funding:{funding_goal_id}`
  - `swag::gift:{gift.id}`
  - `swag::gift.product:{gift.product.id}`

Receivers:

- track_gift_sent
  Trigger Task `analytics.tasks.track`

- notify_gift_sent
  broadcast `gift.sent` event

- notify_stream_revenue_updated_from_gifts
  (for LIVESTREAM_GIFT_TAG Gift)
  notify `stream.revenue.updated` event to streamer channel

- `add_to_chat_room`
  (For Chat Gift only, returned)

- `create_karaoke_goal`
  (For karaoke goal, returned)

- `update_show_funding_goal_progress`
  update goal's progress, breakdown, metadata.insert_ids

### `gift.sent` -> `notify_gift_sent`

**SUMMARY**: sent `gift.sent` event to target channel

- with args
  - sender
  - gift_id
  - sender_id
  - receiver_id
  - tags
  - product_categories
  - metadata

- vars targets:
  - `presence-notification@{sender_id}`
  - `presence-notification@{receiver_id}`

- ...IF tags exist LIVESTREAM_GIFT_TAG
  - targets.append(`presence-stream@{receiver_id}`)
  - ...IF exclusive
    -> targets.append(`presence-stream-exclusive@{receiver_id}`)
  - ...ELSE
    -> targets.append(`private-stream@{receiver_id}`)

- fetch Gift by id
- fetch sender by id
- vars event = `gift.sent`
- prepare data...
- ...IF gift product is `karaoke-*` -> set data["product_name"]

- Batch notification
  In our `ticket` case:
  - event = gift.sent
  - targets:
    - presence-notification@{sender_id}
    - presence-notification@{receiver_id}
    - presence-stream@{receiver_id}
    - private-stream@{receiver_id}

### `gift.sent` -> `notify_stream_revenue_updated_from_gifts`

**SUMMARY**: notify `stream.revenue.updated` event to streamer channel

- proceed when gift is LIVESTREAM_GIFT_TAG
- Trigger `send_livestream_revenue_events`

- SUMMARY:
  - event: `stream.revenue.updated`
  - target:
    - `private-stream@{user_id}` (user_id is steamer)
    - `presence-stream@{user_id}` (user_id is steamer)

### `gift.sent` -> `create_karaoke_goal`

**SUMMARY**: create `KaraokeGoal` goal after receive karaoke gift.

### `gift.sent` -> `update_show_funding_goal_progress`

- proceed only with 
  - `metadata.funding_goal_id`
  - cost_amount

- Trigger task `increment_goal_progress` with
  - goal_id      = funding_goal_id
  - amount       = utils.dq(metadata, 'count') or 1
  - cost         = cost_amount
  - breakdown_id = sender_id
  - insert_id    = gift_id

**increment_goal_progress**

**SUMMARY**: update goal's progress, breakdown, metadata.insert_ids (which record gift id)

(breakdown_id = sender's id)

- fetch goal by
  - goal_id (funding_goal_id)
  - metadata.insert_ids array don't have _insert_id (gift_id)
- !!!Update goal:
  - progress += amount (count)
  - breakdown.{breakdown_id}.progress += amount
  - breakdown.{breakdown_id}.cost += cost
  - metadata.insert_ids append(_insert_id)

- Send `features.leaderboards` signal with sender `goal.progressed`
  args:
  - goal_id      = goal.id,
  - _cls         = goal._cls,
  - amount       = amount,
  - conditions   = goal.conditions,
  - context      = goal.context,
  - progress     = goal.progress,
  - breakdown_id = breakdown_id,
  - levels       = [{
        'title': level.title,
        'target': level.target,
    } for level in goal.levels],
  - metadata = goal.metadata,
  - exp      = goal.exp,

  Receivers:
  - `track_goals`
    Trigger `analytics.tasks.track`

  - `update_and_notify_session_karaoke_goal`
    For KaraokeGoal, returned

  - `notify_goal_progress_updated`
    - event: `goal.progress.updated`
    - targets:
      - 'private-stream@{streamer_id}'
      - 'presence-stream@{streamer_id}'
      - 'private-user@{streamer_id}'
      - 'presence-goal@{goal.id}.{breakdown_id}'

  - `trigger_goal_complete`
    Triggers goal.completed if a goal's level.target is met

  - `notify_viewer_change_stream_for_show`
    Notifies viewer to change stream if the funding goal he progressed has a show goal bind to it already.
    - event: `stream.authorized`
    - target: presence-stream-viewer@{streamer_id}.preview.{breakdown_id}

  - `trigger_exclusive_goal_escrow_refund`
    Trigger refund diamonds from escrow to viewers

  - `invalidate_cached_pusher_channel_data`
    Invalidate cached private-user@streamer_id, private-streamer@streamer_id channel data

---
