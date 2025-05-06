# W1-W2

## Code structure

## Try out features with provisioned diamonds

# W3-W4

Core functionalities

- System-wide Authorization

- Login / Sign up

- Pusher Authorization Flow
    - batch-authenticate
    - Pusher webhooks

# W5-W6

## **Message** Model:

- EmbeddedDocuments:
  - media: `Media`
  - List(assets): `Asset`
  - caption: `Caption`
  - pricing: `Price`
  - cost: Generic
    - `Diamond`
    - `MessagingDiamonds`
    - `Voucher`
  - unlocks: Generic
    - `PointsUnlock`
    - `VoucherUnlock`
    - `RainbowDiamondUnlock`
  - status_transitions: `StatusTransitions`
  - metadata: `Metadata`

In `DocumentLifecycleMixin`, we add 1 dynamic signal receiver as following:

```py
class DocumentLifecycleMixin:
    LIFECYCLE_SIGNALS = {
        mongoengine.signals.post_save,
    }

    def __init_subclass__(cls, *args, **kwargs):
        super().__init_subclass__(*args, **kwargs)

        for signal in cls.LIFECYCLE_SIGNALS:
            if not (receiver := getattr(cls, f'on_{signal.name}'), None):
                continue

            signal.connect(sender=cls, receiver=receiver)
```

Then, in Message model, we have `on_post_save` function as receiver:

```py
@staticmethod
def on_post_save(sender, document: db.Document, created: bool, **kwargs):
    if created:
        # HACK: Dynamic import
        from . import signals, tasks

        tasks.trigger.apply_async(
            args=[signals.message_signal.name, 'created'],
            kwargs=dict(
                message_id=document.id,
            ),
        )
```

## Shop

### Create order

- `/shop/checkout`
- in checkout, order will be created, than signal sender 'order.created'
  - 'order.created' -> `ensure_wallet_and_bank` receive, invoke task `provision_wallet_and_bank_account`
  - provision_wallet_and_bank_account -> invoke task `swag.ext.wallet.tasks.create_account`
  - in create_account, fire request to `WALLET_API_URL`, 
    ```py
    response = task.session.post(   # requests.Session()
        task.app.config['WALLET_API_URL'].navigate('/1/account'), # default http://api.wallet.svc.cluster.local
        auth=Authorization(scopes=['account:create']),
    )
    ```

### Checkout

- `/shop/checkout/<gateway>/complete`

產生的 redirect url: (以 sonet 為例)

- http://127.0.0.1:8000/redirect-out
  - 目的：將 resume 存進 session cookie 中 (with specified cookie_path)
  - queries:
    - `session`=shop-checkout-sonet-67ff4ac855034a533a094088
    - `next`=http://127.0.0.1:8000/tools/POST.html?action%3Dhttps://mpay.so-net.net.tw/paymentRule.php?icpId%253Dplanckpay%2526icpOrderId%253D67ff4ac855034a533a094088%2526icpProdId%253Ddiamond_29900%2526mpId%253DGASH_GPAY%2526memo%253DOrder%252067ff4ac855034a533a094088%2526icpUserId%253D67ff21fdb2535a8b5301708f%2526authCode%253Ddf9fc7d8fedaefc5a7fd0e31d8926697
    - `resume`=http://127.0.0.1:8000/notify/sonet?metadata%3DeyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjhiNmNlZjY5In0.eyJpY3BJZCI6InBsYW5ja3BheSIsImljcE9yZGVySWQiOiI2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJpY3BQcm9kSWQiOiJkaWFtb25kXzI5OTAwIiwibXBJZCI6IkdBU0hfR1BBWSIsIm1lbW8iOiJPcmRlciA2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJpY3BVc2VySWQiOiI2N2ZmMjFmZGIyNTM1YThiNTMwMTcwOGYiLCJtZXRhZGF0YSI6eyJpY3BJZCI6InBsYW5ja3BheSIsImljcE9yZGVySWQiOiI2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJwcmljZSI6Mjk5MDAsIm1wSWQiOiJHQVNIX0dQQVkifSwicHJpY2UiOjI5OTAwLCJpY3BQcm9kRGVzYyI6Ik9yZGVyIDY3ZmY0YWM4NTUwMzRhNTMzYTA5NDA4OCJ9.6FQqJmnavLKn9SAPqAm1RyjyOvx04aNbQMP78TicUCA%26next%3Dhttp://127.0.0.1:8000/redirect-in/shop-checkout-67ff4ac855034a533a094088

- Next url:
  http://127.0.0.1:8000/tools/POST.html
  - 前往支付頁面前，透過 POST.html 將 Redirect GET 轉為 action url POST, query string 包在 payload 中
  - queries: 
    - `action`=https://mpay.so-net.net.tw/paymentRule.php?icpId=planckpay&icpOrderId=67ff4ac855034a533a094088&icpProdId=diamond_29900&mpId=GASH_GPAY&memo=Order 67ff4ac855034a533a094088&icpUserId=67ff21fdb2535a8b5301708f&authCode=df9fc7d8fedaefc5a7fd0e31d8926697
      - queries:
        - icpId     : planckpay
        - icpOrderId: 67ff4ac855034a533a094088
        - icpProdId : diamond_29900
        - mpId      : GASH_GPAY
        - memo      : Order 67ff4ac855034a533a094088
        - icpUserId : 67ff21fdb2535a8b5301708f
        - authCode  : df9fc7d8fedaefc5a7fd0e31d8926697

- Resume URL
  http://127.0.0.1:8000/notify/sonet
  - queries:
    - `metadata`=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjhiNmNlZjY5In0.eyJpY3BJZCI6InBsYW5ja3BheSIsImljcE9yZGVySWQiOiI2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJpY3BQcm9kSWQiOiJkaWFtb25kXzI5OTAwIiwibXBJZCI6IkdBU0hfR1BBWSIsIm1lbW8iOiJPcmRlciA2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJpY3BVc2VySWQiOiI2N2ZmMjFmZGIyNTM1YThiNTMwMTcwOGYiLCJtZXRhZGF0YSI6eyJpY3BJZCI6InBsYW5ja3BheSIsImljcE9yZGVySWQiOiI2N2ZmNGFjODU1MDM0YTUzM2EwOTQwODgiLCJwcmljZSI6Mjk5MDAsIm1wSWQiOiJHQVNIX0dQQVkifSwicHJpY2UiOjI5OTAwLCJpY3BQcm9kRGVzYyI6Ik9yZGVyIDY3ZmY0YWM4NTUwMzRhNTMzYTA5NDA4OCJ9.6FQqJmnavLKn9SAPqAm1RyjyOvx04aNbQMP78TicUCA
    - `next`=http://127.0.0.1:8000/redirect-in/shop-checkout-67ff4ac855034a533a094088
  
- `/notify/sonet`
  - if resultCode=ok -> verify_order
    - sent request to sonet to check the payment (`confirmOrder`)
    - if confirmed -> trigger signal with sender `constants.OrderStatus.success`
      - `update_order` received
  - eg. i got metadata decoded as
    `{'icpId': 'planckpay', 'icpOrderId': '67ff4ac855034a533a094088', 'price': 29900, 'mpId': 'GASH_GPAY'}`
  - redirect to `next` above

- `/shop/redirect-in`
  - mainly for clear path-specified session cookie


### Order fulfillment

NOTE:

- `grant_passes` vs `fulfill_order_pass_product`
  - 最一開始 `Prduct` 類型沒有分類，根據 id 決定 product 種類，然後依此建立個別 BackpackItem 的 type (see `grant_passes`)

  - 後續定義 Product subtype (`DiamondPackProduct`, `UserProduct`, `PassProduct`)。
    於是根據 `_cls` 決定 BackpackItem 的 type
    (see `fulfill_order_pass_product`)
  
  - To sum up: `grant_passes` is legacy flow.

## Asset uploading

### Create Assets

- create upload URL

- QUESTION: How did instance get access to bucket? with key or role?
  with this? `CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE`

Possible ans: `swag/__init_as_.py`, credential

```py
# in create_celery_application
def googlecloud(self):
    # ...
      'credentials': (credentials := google.auth.default(
          scopes=self.app.config['GOOGLECLOUD_SCOPES'],
          request=req,
      )[0])
```

- Things done after sending `asset.created` signals:

  - signal: `features.assets`
    -> invoke swag/features/shop/endpoints.py::`track_asset_events`
      -> invoke `analytics.tasks.track`, which add event meta to Redis stream

### Upload Artifact

create Artifact of Assets, then generate upload url.

Artifact includes:

- thumbnail 縮圖
- trailer   短片
- aup       

## Post

Q: What is `nbf`? -> not-before

### Create

- trigger signal `features.posts` with sender `post.created`
  - received by swag/features/posts/signals.py::`claim_post_assets`
    trigger task `assets.tasks.claim_asset`

  - `assets.tasks.claim_asset`:
    - set claim time: `f'{Asset._claims.db_field}.{claim_id}': claim_time`
    - trigger signal `feature.asset` with sender `asset.claimed`
      - received by swag/features/assets/signals/__init__.py::`track_asset_events` (for analytics track)
      - received by swag/features/assets/signals/message.py:
        - `trigger_encode_message`
          - NOTE: this encode image assets artifact
          - fire task `tasks.flows.encode_message`
            - in `encode()`, generate `asset.Artifact`
            - Generate DRM keys

        - `trigger_encode_gcp_transcoder`
          - NOTE: this encode video only
          - apply_async `tasks.encode_v2.trigger_encode_v2`
            - send signal with sender `message.processing.started` -> update_message_asset_status (when started, failed, completed)

            - execute `trigger_upload_custom_thumbnail`
              - Get artifact with thumbnail label from Asset
              - trigger `googlecloud.storage.tasks.rewrite`
              - looks like didn't rewrite format of data, just move it from 1 bucket/object-name to another bucket/object-name

            - execute `trigger_encode_trailer`
              - if artifact possess artifact with trailer label from Asset:
                - trigger `googlecloud.storage.tasks.rewrite`
                - ??? QUESTION: no need to blurrer this trailer?
              - else:
                - trigger `trigger_encode_trailer_cloud_run`
                  - get stream from asset's streams_by_codec_type (video)
                  - check if duration >= 3 min
                  - init Artifact with *trailer* label, content_type = video/mp4
                  - trigger `googlecloud.cloudrun.tasks.trailer_generation`
                  - init Artifact with *trailer-blurred* label
                  - trigger `googlecloud.cloudrun.tasks.video_blurrer`

            - execute `trigger_encode_blurred_source`
              - get asset and stream of asset
              - init *SOURCE-blurred* labeled Artifact


            - execute `trigger_encode_gcp_transcoder_cloud_run`


        - `update_message_asset_metadata`
        - `update_message_artifacts`
        - `copy_aup_to_assets_artifacts`
      - received by `swag/features/assets/signals/user.py`:
        - `cleanup_previous_assets`
        - `trigger_generate_thumbnail_artifact`
        - `track`

Asset 上傳到 Bucket 後， GCP 會透過 callback url `/notify/googlecloud/pubsub`，
trigger 進一步的 `googlecloud.pubsub.signal` operation

TO_CHECK: 
**handle_artifact_events_from_google_cloud_storage**
  -> where Artifact really be inserted into DB

### Encoding

in swag/features/assets/tasks/flows.py::`encode_message`

-> call swag/features/assets/tasks/bin.py::`encode_cpu` in task chain

## Note:

- `role:creator` scope gives proper auth scope for create post

- features.posts.models.`Post`:
  - is a public display of features.assets.models.`Asset` Model,
    have a list doc with asset id and some metadata in it.
  - `Post` inherent from `Message` Class

- TODO: Provide `GOOGLE_APPLICATION_CREDENTIALS` in env for google bucket authentication
  - used to generate pre-signed url to upload assets

- **Question**:
  - where do we attach this role to user tags?
  - Who is responsible for update assets status after upload finished?

- SKUs = stock keeping unit

# W7-W8

- Feeds
  - Different generations

NOTE:

- Feed 的 排序依據: `Feeditem.metadata.s_score`

- Livestream
  - Pay to watch/Authorizing
  - Goals
  - Leaderboard

NOTE:

- 過去的直播邏輯為 "個人主播的直播間"，因此 routing 習慣為 `/streams/{streamer_id}/*`
- 後來概念上改為 "各場次的直播 aka session"， routing 邏輯改成 `/session/{session_id}/*`

- preview = Free Streaming
- sd = Paid Streaming

- About User kyc validation:
  - KYC = know your customer
  - 因應台灣法規做驗證
  - 因此可以看到第一步就是 only 驗證 country = tw 的用戶，其他都通過

- About User utm:
  - UTM = Universal Transverse Mercator, 導流頁面資訊
  - eg. 如果買廣告，帶的 url 上攜帶與導流網站相關的 query string, 並存到 `user.utm` field
  - user.utm.initial / user.utm.current (UTMInformation)
  - info fields: source, medium, campaign, term, content

- Trivial things about `Gift`:
  - `karaoke-` prefix gift: 遙控玩具 or 下達指令
  - "非 livestream" 情境的禮物， eg. 私訊 (`Chat` Model) 時送 gift
  - `LIVESTREAM_GIFT_TAG`      = general gift
    `LIVESTREAM_SHOW_GIFT_TAG` = ticket, 因此會綁定 `funding_goal_id`

  - `ShowGoalPair` 包含 funding_goal, show_goal
    - funding_goal = 募票階段
    - show_goal = 表演階段, 主播需達成時間要求才算完成 show session

  - `GiftProduct` 是固定的 DB Record (eg. id = 'livestream-show-ticket_1200')
  購票時 建立 `feature.gifts` object gift, 在 `gift.product.categories` 標註 Gift 類型: (以 buy ticket 為例)
    - livestream-show-ticket
    - livestream-show
  
  - 有時間關係的 Gift 就會有 Goal
    eg. karaoke gift 指令有要求 duration, 因此贈送後有 `KaraokeGoal`

- How user get byteplus_token?
  - 方法一：透過 batch-autenticate subscribe
    `presence-enc-stream-viewer@{streamer_id}.sd.{viewer_id}`
    channel, 如果有購票的話就會帶上 token
  - 方法二：透過 endpoint `/streams/<objectid:session_id>/token`, 主動取得 token
    (for 減少 batch-authentication 的壓力)

- 在 get session token endpoint 裡，會把整個 response 用 LIVESTREAM_TOKEN_CACHE_KEY format cache 起來。

- 直播暢遊卷 `livestream_pass*`：
  - 兩種類型
    - `livestream_pass` (global)
    - `livestream_pass_{streamer_id}`
  - `users.tagsv2.livestream_pass`: {nbf, exp}
  - 取得暢遊卷後，選擇啟用，才將 `livestream_pass` 掛載到 tagsv2 下，並填上 nbf, exp

- Who is authorized to earn sd token?
  - A: ticket buyer, recorded in `session.show_goal_pairs[-1].funding_goal.breakdown.{user_id}`
  - B: payer, recorded in `session.viewers.{user_id}`
  - C: livestream_pass owner, recorded in `user.tagsv2.livestream_pass`

- `session.viewers` 是作為 pay method 權限控管的紀錄;
  紀錄直播間人數的 model 則是 `StreamViewer` model

- Livesteam.`Sources` model:
  直播主使用的直播來源 (eg. 手機 or OBS), 目前沒有特別用途

- Question: when will escrow_refund happen:
  - 1. FundingGoal reached, but no related ShowGoal found
    (`deactivate_goals_in_session`)
  - 2. Show goal trigger_show_escrow_refund
    (`trigger_show_escrow_refund`)

QUESTION: Where to store livestream_pass?

HINT: `order.paid` -> grant_passes

# Evaluation

- Must understand the high level flow of all the items
- Must try these features out locally as much as possible
- Should try to understand the underlying design of the items as much as possible
