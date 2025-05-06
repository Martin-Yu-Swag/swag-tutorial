# Checkout Complete

```bash
curl 'https://api.swag.live/shop/checkout/happypay/complete?lang=zh-hant' \
  -H 'accept: */*' \
  -H 'accept-language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
  -H 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJzdWIiOiI2N2NlYWJlY2M4MmI4ZmQ2Y2Y2M2Q2ZDYiLCJqdGkiOiJmc0ZQT0xhZE9pZ1VhZ3gzIiwiaXNzIjoiYXBpLnN3YWcubGl2ZSIsImF1ZCI6ImFwaS5zd2FnLmxpdmUiLCJpYXQiOjE3NDU0NzYyMjYsImV4cCI6MTc0NTQ3OTgyNiwidmVyc2lvbiI6Miwic2NvcGVzIjpbIkhVTUFOIl0sIm1ldGFkYXRhIjp7ImZpbmdlcnByaW50IjoiZDI3OTNkZDQiLCJmbGF2b3IiOiJzd2FnLmxpdmUiLCJvcmlnaW5hbCI6eyJpYXQiOjE3NDU0NjExODYsIm1ldGhvZCI6InBhc3N3b3JkIn19fQ.MjyxBd3799nCyxivI9SyqAqZGVVFKE5XDXLTX7O9rp0' \
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
  -H 'x-ab: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjBjOTNkZTgzIn0.eyJpYXQiOjE3NDU0NzY1MjksImV4cCI6MTc0NTQ4MDEyOSwic3ViIjoicHJlc2VuY2UtdXNlckA2N2NlYWJlY2M4MmI4ZmQ2Y2Y2M2Q2ZDYiLCJleHBlcmltZW50cyI6eyJzb2tldGkiOnsidmFyaWF0aW9uIjoiYSJ9LCJob21lX2NhdGVnb3J5X3Y0Ijp7InZhcmlhdGlvbiI6ImUifSwiY2RuIjp7InZhcmlhdGlvbiI6ImIifX19.HXp0x0vk_s027-WYkA6zRUbiYYm4Xy5siMzsGyh6ltw' \
  -H 'x-client-id: ac9cd42b-2982-430f-bdd0-18b0ce505d0a' \
  -H 'x-fingerprint-oss-id: a22c6e2b3f630acdac0924f3c4d25331' \
  -H 'x-session-id: 2b4471a5-429b-4a1c-a080-e9ca844e5514' \
  -H 'x-track: ga_G77CX53EJ6=GS1.1.1744022068.2.1.1744022825.0.0.0;ga_GNMH147MCG=GS1.1.1745476243.72.1.1745476530.48.0.0;mixpanel_distinct_id=67ceabecc82b8fd6cf63d6d6;utm_campaign=tw_routine;utm_content=brand;utm_medium=cpc;utm_source=google_g;utm_term=swag' \
  -H 'x-version: 3.228.0' \
  --data-raw '{"order":"6809de27e2e9667905066103","source":"pd-credit-3d","redirect_url":"https://swag.live/?shopId=addvalue&email=martin.yu%40swag.live&sourceId=pd-credit-3d&utm_source=google_g&utm_medium=cpc&utm_campaign=tw_routine&utm_content=brand&utm_term=swag&pwa=true","email":"martin.yu@swag.live"}'
```

PAYLOAD

```json
{
    "email"       : "martin.yu@swag.live",
    "order"       : "6809de27e2e9667905066103",
    "redirect_url": "https://swag.live/?shopId=addvalue&email=martin.yu%40swag.live&sourceId=pd-credit-3d&utm_source=google_g&utm_medium=cpc&utm_campaign=tw_routine&utm_content=brand&utm_term=swag&pwa=true",
    "source"      : "pd-credit-3d",
}
```

---

Endpoint: [POST] `/shop/checkout/<gateway>/complete`

Body:

```json
{
    "email"       : "martin.yu@swag.live",
    "order"       : "6809de27e2e9667905066103",
    "redirect_url": "https://swag.live/?shopId=addvalue&email=martin.yu%40swag.live&sourceId=pd-credit-3d&utm_source=google_g&utm_medium=cpc&utm_campaign=tw_routine&utm_content=brand&utm_term=swag&pwa=true",
    "source"      : "pd-credit-3d",
}
```

- !!!fetch `Order` and update: (new = True)
  - filter:
    - id
    - status_transitions__paid__exists     = False
    - status_transitions__canceled__exists = False
  - modify
    - set__email = email

- IF order.created < now - SHOP_ORDER_CHECKOUT_TTL
  -> HTTP.GONE

- IF order has restricted_item:
  - return 400 if user buy more than 1 limited product
  - Trigger Task `cancel_user_order_by_restrictions`
    - user_id
    - order_id
    - restrictions
  - !!!Update `Order` by id:
    - set__restrictions=[restriction]

- Trigger gateway task `generate`
  - order_id    = order.id,
  - currency    = price.currency.value.lower(),
  - amount      = price.sub_units,
  - source      = source,
  - description = order.description,
  - notify_url  = gateway.notify_url,
  - redirect_url
  - email
  - customer_id

- IF gateway response is ACCEPTED: Send Signal `order.processing`
  - **args**
    - order_id
    - customer_id
    - gateway.name
  - **receivers**
    - track_transaction
    - provision_customer_for_user
      for "securionpay" gateway service

## `cancel_user_order_by_restrictions`

- !!!Update `Order`
  - filter
    - restrictions__0__exists          = True
    - restrictions__in                 = restrictions
    - customer                         = user_id
    - status_transitions__paid__exists = False
    - id__ne                           = order_id
  - update
    - set__status                       = 'canceled',
    - min__status_transitions__canceled = now
    - unset__restrictions               = True
    - max__updated                      = now


