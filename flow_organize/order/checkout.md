# Create Checkout

```bash
curl 'https://api.swag.live/shop/checkout' \
  -H 'accept: */*' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJzdWIiOiI2ODAwYTkwNzNlMGMzNDY1MzE5NThiMDMiLCJqdGkiOiJmc2xORDQ1RGV4Y3I3S0lpIiwiaXNzIjoiYXBpLnN3YWcubGl2ZSIsImF1ZCI6ImFwaS5zd2FnLmxpdmUiLCJpYXQiOjE3NDY1MDQ0MzcsImV4cCI6MTc0NjUwODAzNywidmVyc2lvbiI6Miwic2NvcGVzIjpbIlBBSUQiLCJIVU1BTiIsIkNSRUFUT1IiXSwibWV0YWRhdGEiOnsiZmluZ2VycHJpbnQiOiJkMjc5M2RkNCIsImZsYXZvciI6InN3YWcubGl2ZSIsIm9yaWdpbmFsIjp7ImlhdCI6MTc0NTgwNzc5OSwibWV0aG9kIjoicGFzc3dvcmQifX19.t-7bsPb7m1ucyJSIExKmJJqFoFfxSl5QOB73JF_n_yc' \
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
  -H 'x-ab: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJpYXQiOjE3NDY1MDQ0MzgsImV4cCI6MTc0NjUwODAzOCwic3ViIjoicHJlc2VuY2UtdXNlckA2ODAwYTkwNzNlMGMzNDY1MzE5NThiMDMiLCJleHBlcmltZW50cyI6eyJrYXJhb2tlX2hpbnQiOnsidmFyaWF0aW9uIjoiYSJ9LCJjZG4iOnsidmFyaWF0aW9uIjoiYiJ9fX0.kTNaJtDe9URGBp7Jj-7FSk5TbFYZbzoLyuRp1sF8BpM' \
  -H 'x-client-id: ac9cd42b-2982-430f-bdd0-18b0ce505d0a' \
  -H 'x-fingerprint-oss-id: a22c6e2b3f630acdac0924f3c4d25331' \
  -H 'x-session-id: 2148da8d-30a1-49db-9bda-645be1ca134b' \
  -H 'x-track: ga_G77CX53EJ6=GS1.1.1744022068.2.1.1744022825.0.0.0;ga_GNMH147MCG=GS2.1.s1746504438$o101$g1$t1746504438$j60$l0$h0;mixpanel_distinct_id=6800a9073e0c346531958b03;utm_campaign=tw_routine;utm_content=brand;utm_medium=cpc;utm_source=google_g;utm_term=swag' \
  -H 'x-version: 3.230.0' \
  --data-raw '{"skus":["3999-diamonds-limited-daily-twd-f3f04fe67f52c3adf58da967156dc600"],"email":"martin.yu+2@swag.live","currency":"TWD","source":{"id":"card:11aa190e","type":"card","via":"ecpay"}}'
```

```json
{
   "id":"68198b054ce6555682224a96",
   "amount":29900,
   "currency":"twd",
   "email":"martin.yu+2@swag.live",
   "items":[
      {
         "type":"sku",
         "id":"3999-diamonds-limited-daily-twd-f3f04fe67f52c3adf58da967156dc600",
         "currency":"TWD",
         "amount":29900,
         "quantity":1,
         "productId":"3999-diamonds-limited-daily"
      }
   ],
   "source":{
      "id":"card:11aa190e",
      "type":"card",
      "via":"ecpay",
      "context":{
         "brand":"visa",
         "exp_month":8,
         "exp_year":2029,
         "last4":"2258"
      },
      "last_used":false
   },
   "sources":[
      {
         "id":"card:11aa190e",
         "type":"card",
         "via":"ecpay",
         "context":{
            "brand":"visa",
            "exp_month":8,
            "exp_year":2029,
            "last4":"2258"
         },
         "last_used":false
      },
      {
         "type":"card",
         "id":"merch-token",
         "via":"ecpay",
         "last_used":true
      },
      {
         "type":"apple-pay",
         "id":"onsite-apple-pay",
         "via":"ecpay",
         "last_used":false
      },
      {
         "type":"google-pay",
         "id":"GASH_GPAY",
         "via":"sonet",
         "last_used":false
      },
      {
         "type":"line-pay",
         "id":"pd-epoint-linepay",
         "via":"happypay",
         "last_used":false
      },
      {
         "type":"prepaid",
         "id":"card",
         "via":"spgateway",
         "last_used":false
      },
      {
         "type":"cvs",
         "id":"cvs",
         "via":"spgateway",
         "last_used":false
      },
      {
         "type":"aftee",
         "id":"aftee",
         "via":"aftee",
         "last_used":false
      },
      {
         "type":"telecom-tcc",
         "id":"TCC",
         "via":"sonet",
         "last_used":false
      },
      {
         "type":"telecom-fet",
         "id":"FET",
         "via":"sonet",
         "last_used":false
      },
      {
         "type":"telecom-cht",
         "id":"OTP839",
         "via":"sonet",
         "last_used":false
      },
      {
         "type":"webatm",
         "id":"pd-webatm-ctcb",
         "via":"happypay",
         "last_used":false
      },
      {
         "type":"vacc",
         "id":"vacc",
         "via":"spgateway",
         "last_used":false
      },
      {
         "type":"card",
         "id":"card-prime",
         "via":"tappay",
         "last_used":false
      }
   ]
}
```

Endpoint: [POST] `/shop/checkout`

Creates an Order based on submitted SKUs

Body:

```json
{
   "skus":[
      "3999-diamonds-limited-daily-twd-f3f04fe67f52c3adf58da967156dc600"
   ],
   "email":"martin.yu+2@swag.live",
   "currency":"TWD",
   "source":{
      "id":"card:11aa190e",
      "type":"card",
      "via":"ecpay"
   }
}
```

- fetch "skus" from `Product` aggregate:
  - `$match`
    - skus.id: $in sku_ids
  - `$unwind`: $skus
  - `$match`:
    - skus.id: $in sku_ids
    - `$or`
      - skus.currency: $in currency / currency.lower
  - `$project`
    - id                     : '$skus.id'
    - product_id             : '$_id'
    - product_cls            : '$_cls'
    - currency               : '$skus.currency'
    - amount                 : '$skus.amount'
    - name                   : True
    - description            : True
    - metadata               : {'$mergeObjects': ['$metadata', '$skus.metadata']}
    - restriction            : {'$toInt': '$restriction'}
    - restriction_period     : True
    - restriction_user_level : {'$ifNull': ['$restriction_user_level', 0]}
    - exclude_payment_methods: {'$ifNull': ['$exclude_payment_methods', []]}

- for sku in skus
  - check sku['restriction_user_level'] < g.user.get_level()[0]
  - Ensure int sku['metadata'][key] = int(val) IF key exists:
    - sku['metadata']['bonus']
    - sku['metadata']['points']

- init `Order.OrderItem` list from skus:
  - id                      = sku['id'],
  - product_cls             = sku['product_cls'],
  - product_id              = sku['product_id'],
  - amount                  = sku['amount'],
  - currency                = sku['currency'],
  - name                    = sku.get('name'),
  - description             = sku.get('description'),
  - restriction             = sku.get('restriction'),
  - restriction_period      = sku.get('restriction_period'),
  - metadata                = sku.get('metadata'),
  - exclude_payment_methods = sku.get('exclude_payment_methods'),

- Check if order is valid:
  - UNAUTHORIZED_PURCHASE_RESTRICTED_PRODUCT
  - INVALID_PAYLOAD
  - HIT_MONTH_PURCHASE_LIMIT / HIT_WEEK_PURCHASE_LIMIT / HIT_DAY_PURCHASE_LIMIT

- Init `Order`: order
  - id          = (order_id := bson.ObjectId()),
  - customer    = g.user.id
  - email       = email
  - currency    = price.currency.value,
  - amount      = price.sub_units,
  - description = utils.dq(items, 0, 'description') or f'Order #{order_id}',
  - items       = items,

- parse source (of payment)

- if source ask for payment fee:
  - order.items.append Order.OrderItem
    - id         = f'{product_id}-{payment_gateway_fee.currency.value}',
    - amount     = payment_gateway_fee.sub_units,
    - currency   = payment_gateway_fee.currency.value,
    - product_id = product_id,

- order.save(force_insert=True)
  - :param `force_insert`:
    only try to create a new document, don't allow updates of existing documents

- Send signal `order.created`
  - **args**
    - order_id
    - currency
    - customer_id
  - **receivers**
    - track_transaction
    - `ensure_wallet_and_bank`
      - Execute `s`
    - `attach_metadata`
      - !!!Update `Order` by id
        - set__metadata___task_ = task.metadata (which remove 'publish_ts' key)
    - `tag_order_as_subscription`
      - !!!Update `Order`:
        - filter:
          - id
          - items__0__product_cls = `UserSubscriptionProduct`
          - items__1__exists      = False
        - update_one
          - set__metadata__via = 'subscriptions.subscribe_to_user'

- Payment gateway currency conversion

- Generate an order token for onsite ApplePay of ECPay:
  Trigger Task `GetTokenbyTrade`s

- Return response

## `order.created` -> `provision_wallet_and_bank_account`

Ensure Wallet ID and Bank Account ID for the User
