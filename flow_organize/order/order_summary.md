# Order Summary

以 gash payment 為例

After payment, receive callback request:

Endpoint: [POST] `/notify/gash`

func `notify` flow:

- fetch `status` from
  a. request.view_args['PAY_STATUS']
  b. request.view_args['RCODES']
  c. 'failed'
  (eg. `success`)
  - possible status for gash:
    - success
    - failed
    - pending
    - cancelled
    - timeout

- Trigger signal `ext.gash` with sender status (eg. `success`)
  args:
  - kwargs = request.view_args
  Receivers of success:
  - `settle_payment`

- parse redirect response from request.args['next]

## settle_payment

Trigger Task `settle`
- args: (derived from kwargs)
  - payment_agent_id = PAID
  - currency         = CUID
  - order_id         = COID
  - amount           = AMOUNT
- link: swag.tasks.trigger_from_canvas
  args:
  - 'ext.gash'
  - 'settled'
- link_error: swag.tasks.trigger_from_canvas
  args:
  - 'ext.gash'
  - 'failed'

## Task `gash.tasks.settle`

**SUMMARY**: Check order is success with Gash SOAP API

- parse `customer_id` from task.app.config['GASH_CUSTOMER_ID']

- get zeep client `response` from `task.gash` (see create_celery_application)
  NOTE: [zeep](https://docs.python-zeep.org/en/master/) is a fast and modern Python SOAP client

- parse `result` dict from response xml

- parse `rcode` from response result
  (`0000` stands for success)

- return result

### link Task: `swag.tasks.trigger_from_canvas`

Signal trigger for canvas callbacks

- args:
  - `result`     : from task `settle`
  - `signal_name`: 'ext.gash'
  - `sender`     : settled
  - `result_as`  : None

- Sending Signal `ext.gash` with seder `settled`
  - Receivers:
    - `update_order`

### `settled` -> `update_order`

- args:
  - COID
  - CUID
  - RRN
  - AMOUNT
  - sender
  - kwargs

- init price = money.Money
  - AMOUNT
  - money.Currency[CUID]

- init payment = GashPurchase
  - id = RRN
  - currency = price.currency.value
  - amount = price.sub_units
  - transaction
    - COID   = COID,
    - CUID   = CUID,
    - RRN    = RRN,
    - AMOUNT = AMOUNT,
    - **kwargs,

- !!!UPDATE and fetch order (new=False):
  - filter: id = COID
  - modify:
    - set__status = 'paid'
    - set__status_transitions__paid = payment.timestamp
    - set_payment=payment

- Send signal `shop` with sender `order.paid`
  - **args**:
    - order_id    = order.id
    - customer_id = order.customer.id
  - metadata = order.metadata.get('_task_')
  - **Receivers**:
    - `grant_passes`
    - `trigger_calculate_user_spendings`
    - track_affiliate_spend
    - `mark_messagepack_fulfilled`
    - `update_messagepack_sold_count`
    - `order_updated`
    - trigger_capture
    - capture_charge
    - label_charge_with_order
    - trigger_fulfill_order_diamond_pack
    - fulfill_order_pass_product
    - provision_ezpay_invoice
    - send_payment_receipt
    - update_last_purchase
    - record_restrictions
    - track_transaction
    - deposit_diamonds
    - dispatch_order_payouts
    - track_subscription_earnings
    - fulfill_subscription_order

#### `order.paid` -> `grant_passes`

**SUMMARY**: 根據 product_id，將購買的 order 記錄兌換成 backpack 暢遊卷

- aggregate Order to fetch order_items:
  - filter: id = order_id
  - aggregate:
    - `$unwind`: $items
    - `$match`
      'items.product_id': $in PASSES
    - `$addFields`:
      - items.customer_id: $customer
      - items.paid: $status_transitions.paid
    - `$replace_with`: $items

- loop through order_items
  - parse _cls, duration, ttl, metadata from PASSES[product_id]
  - cal exp from ttl
  - Trigger Task `create_backpack_item`
    - user_id = item.customer_id
    - exp = exp
    - _cls = _cls (LivestreamPass/FlixFeedPass)
    - duration = duration
    - metadata=metadata

#### `order.paid` -> `trigger_calculate_user_spendings`

- parse ts, time_ref, start, end from 
  task.metadata.get('ａpublish_ts')

- Trigger Task `calculate_user_spendings`
  - user_id = customer_id
  - start   = start
  - end     = end

**calculate_user_spendings**

- Aggregate Order:
  - $match
    - customer = user_id
    - status_transitions.paid
      - $gte start
      - $lt end
    - status_transitions.refunded = None
  - $unwind
    - path: $items
    - preserveNullAndEmptyArrays: True
  - $group
    - _id: None
    - total_diamond: $sum of 
      - $switch:
        - case $gt $metadata.diamonds 0 then $metadata.diamonds
        - case $eq $items.product_cls DiamondPackProduct then
          $multiply $items.quantity ($add $items.metadata.points, $items.metadata.bonus)
        - default 0

- get total_diamond from first aggregation
- execute `set_user_spendings`
  - user_id
  - time_slot=start
  - total_diamonds

**set_user_spendings**

- !!!Update User (new = False)
  - filter: id = user_id
  - modify:
    - set__tagsv2__spendings__{time_slot}: total_diamonds

- from_level = user level before this spending
  to_level = user level after this spending
- IF from_level != to_level:
  Send signal `level.updated`
  - args:
    - user_id
    - from_level
    - to_level

- IF `spendings` has stale_time_slots:
  Trigger Task `cleanup_user_spendings`
  - user_id
  - time_slots = stale_time_slots

- Send Signal `spendings.updated`
  - args:
    - user_id
    - spendings = total_diamonds

#### `order.paid` -> `mark_messagepack_fulfilled`

**SUMMARY**: if items__product_cls == `MessagePackProduct`:
- Update `Order`
  - set__status                       = fulfilled
  - set__status_transitions_fulfilled = now
- Send signal `order.fulfilled`

#### `order.paid` -> `update_messagepack_sold_count`

**SUMMARY**:
- Update `MessagePackProduct`
  - $inc metadata.sold + count

#### `order.paid` -> `order_updated`

- Trigger Task `order_updated`
  - event = 'order.paid'
  - order_id

**order_updated**

**SUMMARY**: notify event `order.paid`

- fetch `Order`
  - id = order_id
  - customer__ne = None

- fetch `Product` list
  - __raw__
    - skus.id $in order.items

- collect from product list
  - product_type set
  - product_ids list
  - product_name list

- status_name = 'paid'
- batch notify
  - targets:
    - presence-notification@{user_id}
      (user_id in order.customer_id, payout_receivers)
  - event: `order.paid`

#### `order.paid` -> `order_updated`
