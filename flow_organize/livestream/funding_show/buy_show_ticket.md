# Buy Show ticket

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

func `send_gift_to_user` flow:

- execute function `tasks.send_gift` with args:
  - product_id
  - count
  - sender_id
  - receiver_id (this is streamer)
  - upcoming = g.config['beta']

- Get `gift_id` from task, and return this id in response

## Task `send_gift`

**SUMMARY**
- create `Gift` document
- trigger Task
  - `transfer`
  - `save_gift_transaction`
  - link: Send signal `gift.sent`

- Fetch `GiftProduct` by `product_id`
- Fetch Receiver `User` by `receiver_id`
- Check if receiver is has creator tags
- set vars
  - `product_categories`       = product.categories (eg. ['livestream-show-ticket'])
  - `extra_product_categories` = set()
  - product_price              = product.skus[0].price.amount (NOTE: 因為是鑽石交易，skus 必定只有一個 item)
  - tags                       = set()
  - metadata                   = {"count": count}
  - escrow_id                  = None

- IF product posses any `livestream-*` tag:
  **SUMMARY**: Add livestream-related tag and metadata

  - Fetch session (by receiver_id + active=True)
  - ...IF sender is session's exclusive user -> metadata["exclusive"] = True
  - `tags`.add
    - 'swag::livestream.session:{session["id"]}.gift
  - `extra_product_categories`.add
    - 'livestream'
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
          (NOTE: `escrow_id` defined here!!!)
        - `tags`.add
          f'swag::livestream.session:{session_id}.show_funding:{funding_goal_id}'
        - `extra_product_categories`.add
          'livestream-show'

    (END OF LOPPING AND IF BLOCK)
- **Quick Sum up**: for buying ticket in show
  - `tags` set:
    - 'swag::livestream.session:{session_id}.gift
    - 'swag::livestream.session:{session_id}.show_funding:{funding_goal_id}'
  - `extra_product_categories`:
    - 'livestream'
    - 'livestream-show'

- reduce `product_categories` to related-gift tag only:
  - filter list: if any of match:
    (result: 'livestream-show-ticket')
    - not 'livestream-karaoke-*'
    - match 'livestream-karaoke-{receiver.id}'
    - match 'livestream-karaoke-default'
  - Add `extra_product_categories`
    (in ticket case: 'livestream', 'livestream-show')

- !!!Create `Gift`
  - id (new ObjectID)
  - sender
  - receiver
  - product = Gift.`GiftProduct`
    - id         = product.id
    - name       = product.name
    - categories = product_categories
      - livestream-show-ticket
      - livestream
      - livestream-show
  - cost (Diamond)
    - amount = product_price * amount
  - metadata:
    - count
    - funding_goal_id

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
      - **args**:
        - transaction_id = 'gifts:gift-{gift.id}'
        - from_user_id   = gift.sender.id
        - to_user_id     = gift.receiver.id
        - amount         = gift.cost.amount
        - tags
          - 'swag::livestream.session:{session["id"]}.gift'
          - 'swag::livestream.session:{session["id"]}.show_funding:{funding_goal_id}'
          - 'swag::gift:{gift.id}'
          - 'swag::gift.product:{gift.product.id}'
        - escrow_id = f'show_funding:{funding_goal_id}'
    - `save_gift_transaction`
      - args: gift_id
  - link task: Send `gifts` signal with `gift.sent` sender

### Task `transfer`

- fetch User of sender & receiver

- tags.add
  - 'escrow::{wallet_id_b64}:show_funding:{funding_goal_id}' // wallet_id is receiver.wallet_id

- because `escrow_id` and `to_account` and `from_account`
  - tags.add
    - 'escrow::{wallet_id_b64}:show_funding:{funding_goal_id}' (to_account is embedded in wallet_id_b64)
  - to_account = None

- Trigger Wallet task `transfer`
  - args:
    - from_account   = sender.wallet_id
    - from_amount    = amount (price * amount),
    - to_account     = None,
    - to_amount      = amount (price * amount),
    - forced         = False,
    - tags
      - 'swag::livestream.session:{session["id"]}.gift'
      - 'swag::livestream.session:{session["id"]}.show_funding:{funding_goal_id}'
      - 'swag::gift:{gift.id}'
      - 'swag::gift.product:{gift.product.id}'
      - 'escrow::{wallet_id_b64}:{escrow_id}'
    - timestamp      = None,
    - transaction_id = 'gifts:gift-{gift.id}'

### Task `save_gift_transaction`

**SUMMARY**: After wallet transaction, update Gift record (sent_at, cost.timestamp, cost.wallet_transaction_id)

- args:
  - `wallet_transaction_id` (received from parent task `transfer`)
    = 'gifts:gift-{gift.id}'
  - `gift_id`

- !!!Update `Gift` by id
  - `sent_at` = now
  - `cost.timestamp` = now
  - `cost.wallet_transaction` = 'gifts:gift-{gift.id}'
  
### Signal `gifts`: `gift.sent` Sender

Args:

- gift_id            = gift.id,
- sender_id          = gift.sender.id,
- receiver_id        = gift.receiver.id,
- product_id         = gift.product.id,
- product_categories
  - `livestream-show-ticket`
  - `livestream`
  - `livestream-show`
- cost_amount        = gift.cost.amount,
- metadata
  - count
  - funding_goal_id
- tags               = tags,
  - `swag::livestream.session:{session["id"]}.gift`
  - `swag::livestream.session:{session["id"]}.show_funding:{funding_goal_id}`
  - `swag::gift:{gift.id}`
  - `swag::gift.product:{gift.product.id}`

Receivers:

- add_to_chat_room **returned**
- create_karaoke_goal **returned**
- `track_gift_sent`
  Trigger Task `analytics.tasks.track`

- `notify_gift_sent`
  - targets:
    - presence-notification@{sender_id}
    - presence-notification@{receiver_id}
    - presence-stream@{receiver_id}
    - private-stream@{receiver_id}
  - events: `gift.sent`

- `notify_stream_revenue_updated_from_gifts`
  - targets:
    - private-stream@{user_id}
    - presence-stream@{user_id}
  - events: `stream.revenue.updated`

- !!!`update_show_funding_goal_progress`
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


### `gift.sent` -> `update_show_funding_goal_progress`

- Trigger task `increment_goal_progress` with
  - goal_id      = funding_goal_id
  - amount       = utils.dq(metadata, 'count') or 1
  - cost         = cost_amount
  - breakdown_id = sender_id
  - insert_id    = gift_id

**increment_goal_progress**

**SUMMARY**: update goal's progress, breakdown, metadata.insert_ids (which record gift id)

(breakdown_id = sender's id)

- fetch and update goal (new=True)
  - goal_id (funding_goal_id)
  - metadata__insert_ids__ne _insert_id (gift_id)
- !!!Update goal:
  - inc__progress amount
  - inc__breakdown__{breakdown_id}__progress amount
  - inc__breakdown__{breakdown_id}__cost  cost
  - push__metadata__insert_ids insert_id (gift_id)

- Send `features.leaderboards` signal with sender `goal.progressed`
  **args**:
  - goal_id      = goal.id,
  - _cls         = `ShowFundingGoal`,
  - amount       = amount,
  - conditions   = goal.conditions,
    - session_id
  - context      = goal.context,
    - type                 = 'show-funding'
    - perform_duration     = 60,
    - session_id           = "681088cb95684fc0c6496546",
    - hesitation_countdown = 30,
    - ticket_product_id    = "livestream-show-ticket_134",
    - ticket_product_type  = "earlybird",
    - discount_percentage  = 33
  - progress     = goal.progress,
  - breakdown_id = breakdown_id,
  - levels.0
    - target
    - title
  - metadata = goal.metadata
    - insert_ids
    - user_id (streamer_id)
  - exp      = goal.exp,

  Receivers:
  - `track_goals`
    Trigger `analytics.tasks.track`

  - update_and_notify_session_karaoke_goal **returned**
  - trigger_exclusive_goal_escrow_refund **returned**

  - `notify_goal_progress_updated`
    - event: `goal.progress.updated`
    - targets:
      - 'private-stream@{streamer_id}'
      - 'presence-stream@{streamer_id}'
      - 'private-user@{streamer_id}'
      - 'presence-goal@{goal.id}.{breakdown_id}'

  - `trigger_goal_complete`
    Triggers goal.completed if a goal's level.target is met

  - `notify_viewer_change_stream_for_show` (**returned** if not ShowGoal)
    Notifies viewer to change stream if the funding goal he progressed has a show goal bind to it already.
    - event: `stream.authorized`
    - target: presence-stream-viewer@{streamer_id}.preview.{breakdown_id}

  - `invalidate_cached_pusher_channel_data`
    invalidate cached channels data then re-authorize:
    - 'private-user@{streamer_id}'
    - 'private-enc-user@{streamer_id}'
    - 'private-stream@{streamer_id}'
    - 'private-enc-stream@{streamer_id}'

---

## Wallet Transfer callback

Endpoint: [POST] `/notify/wallet/transaction`

body:

```json
{
    "transaction_id": "gifts:gift-{gift.id}",
    "timestamp"     : "",
    "tags"          : [
        "swag::livestream.session:{session_id}.gift",
        "swag::livestream.session:{session_id}.show_funding:{funding_goal_id}",
        "swag::gift:{gift.id}",
        "swag::gift.product:{gift.product.id}",
    ],
    "from_account"  : "",
    "from_amount"   : "",
    "to_account"    : null,
    "to_amount"     : "",
}
```

Send signal sender `transaction.created`

Receivers:

- update_order **returned**
- `trigger_user_balance_updated`

### `transaction.created` -> `trigger_user_balance_updated`

- aggregate `to_user_metadata` if to_account and to_amount:
  (in this case: to_account is None)

- aggregate `from_user_metadata` if from_account and from_amount:
  - fetch user by user_id
  - vars:
    - from_user_id
    - from_user_wallet_id = user.wallet_id
    - from_user_metadata:
      - id
      - username
      - tags
      - tagsv2
      - level
    
- Send signal `user` with sender `balance.decremented`:
  - **args**
    - user_id
    - user_wallet_id
    - source_user_id (None)
    - source_user_wallet_id (None)
    - amount
    - timestamp
    - transaction_id
      (`gifts:gift-{gift.id}`)
    - tags
      - "swag::livestream.session:{session_id}.gift",
      - "swag::livestream.session:{session_id}.show_funding:{funding_goal_id}",
      - "swag::gift:{gift.id}",
      - "swag::gift.product:{gift.product.id}"
      - 'escrow::{wallet_id_b64}:show_funding:{funding_goal_id}'
  - Receivers:
    - handle_bet_transaction_completions (borden.py) **returned**
    - handle_bet_transaction_completions (giocogroup.py) **returned**
    - handle_bet_transaction_completions (sic_bo.py) **returned**
    - record_penalty_points_to_earnings **returned**
    - progress_trigger_goals **returned**
    - points_withdrawn **returned**
    - `livestream_show_withdrawn`
      - `notifications.tasks.record` with event `stream.show`
    - fetch_user_balance_when_changed
    - track_points_activity
