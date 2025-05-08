# Feed

## About `.rss` endpoint

provided for Google SEO, not used by swag app

## `/feeds/flix_recommendation` 推薦影片

**SUMMARY**: Get use-specific feed list from bucket object by identifier, then return paginate result

queries:

- identifier
  (user's ObjectId, 每個人會有 customized feed content)
  (預設為 trending)
- version (default **v0_cr**)
- page
- page_size

function flow:

- get bucket_id from MESSAGE_RECOMMENDATION_BUCKET
  (default: recommendation-flix-mart-c6d9b3d)

- ...IF NO identifier
  - return redirect to `/feeds/flix_recommendation?identifier=trending` OR `/feeds/flix_recommendation?identifier={user_id}` if authed
    (with Cache-Control max_age 10 min)

- Verify identifier is valid ObjectID and match user_id

- Open blob `recommendation-flix-mart-c6d9b3d:{identifier}.json`, load data to loaded

- Get feeds list from `loaded[version]`

- Get paginate result from Pagination(source=feed-list, page, per_page)

- return paginated list with cache_control 10 minute

---

## `/feeds/shorts_recommendation` 推薦限時動態

**SUMMARY**: Get message id list from cache, or from data host API then store in cache

queries:

- identifier
  (user_id)
- page
- page_size

function flow:

- ...IF NO identifier
  - return redirect to `/feeds/shorts_recommendation?identifier={"default" or "user_id"}`

- Fetch feeds item from Task `get_user_shorts_recommendation` with arg identifier
  - cache key = `swag.features.feeds:user_shorts_recommendation:{identifier}`
  - ...IF cache hit -> return
  - ...ELSE
    - get items from Task `short_content_v1_recommendations` with identifier and limit=100
      (IN SHORT: request data from `https://{SWAG_DATA_HOST}/short_content/v1/recommendations/{user_id}`)
    - set cache and return

- Paginate items and return

---

In  `https://swag.live/post/61efd588aacdddf61538de0f?lang=zh-TW` page, Invoke `https://api.swag.live/feeds/message-61efd588aacdddf61538de0f?page=2&limit=10` request

## `/feeds/message-<objectid:message_id>` 貼文頁面旁邊的推薦列表

**SUMMARY**: 搜尋 feed based on 同作者/同標籤

function flow:

- fetch `Message` by id

- feed_aliases:
  - f"flix_sender_{message.sender_id}"  (同作者)
  - f"post_by_hashtag_{hashtag}" for hashtag in message.hashtags (同標籤)

- p_Aggregate `Feed`
  - `$match`
    - aliases: $in 
      - "flix_sender_{message.sender_id}"
      - "post_by_hashtag_{hashtag}"
  - `$sort`: last_modified: -1
  - `$project`
    - items
    - aliases: $setIntersection [$aliases, feed_aliases]
  - `$unwind` aliases
  - `$group`
    - _id: $aliases
    - items: {$first: $items}
  - `$unwind`: $items 
  - `$project`
    - items
    - score: $cond
      - if: $eg $_id flix_sender_{message.sender.id}
      - then 0
      - else 1
  - `$sort`: score -1
  - `$limit`: 1000
  - `$group`
    - _id: $items.id
    - 'items': {'$first': '$items'},
  - `$replaceWith` $items
  - `$project`

https://api.swag.live/feeds/user_livestream-global&shorts_curated
https://api.swag.live/feeds/ME

---

## Scheduled feed generation

schedule_feed_generations_from_bq_views: loop table of `FEEDS_QUERIES_BQ_DATASET`

-> generate_feed_from_bq_views according to view_id

  -> create_user_feed_from_id, with args:
    - target_ids (from bq table rows)
    - aliases (from bq RE_BQ_FEED_VIEWS matching)

  -> create_message_feed_from_id, with args:
    - target_ids (from bq table rows)
    - aliases (from bq RE_BQ_FEED_VIEWS matching)

### create_user_feed_from_id

- with args: target_ids, aliases
- Invoke Task generate_user_feed

#### generate_user_feed

Eg. for alias user_new_creator_leaderboard_a

- Init User aggregation query:
  - filter: username NOT NULL AND profile.biography NOT NULL AND tags NOT IN EXCLUDE_TAGS
  - filter: _id in target_ids
  - lookup: user.outbox collection
    - pluck latest OutboxMessage of type Message.Post
    - project fields `id`, `caption`
    - as metadata.latestMessage
  - project fields:
    - id
    - _cls: `UserFeedItem`
    - username
    - biography
    - metadata.latestMessage
    - hashtags
  - post projection: add field __priority__, sort by __priority__, un-project __priority__
  - !!!save_as!!!:
    - SUMMARY: Use `$merge` to write above user aggregation result into Feed collection as items

- Trigger signal sender `updated`
  - feed_id      = feed_id,
  - feed_aliases = aliases,
  - timestamp    = now,

---

### create_message_feed_from_id

with targets_id and aliases

- Init Message aggregation query
  - filter:
    - id in target_ids
    - _cls in Message, Post
    - posted_at <= now
    - tags not in EXCLUDE_TAGS
  - Add field: badges, unlocks, boosted_unlocks
  - project field:
    - id
    - cls: `MessageFeedItem`
    - sender
    - caption
    - posted_at
    - unlock_price
    - expires_at
    - metadata
    - assets
    - categories
    - badges
  - Sorted by __priority__
  - !!!save_as!!!:

- Trigger signal sender `updated` with
  - feed_id      = feed_id,
  - feed_aliases = aliases,
  - timestamp    = now,

---

### feed signal with `updated` sender

Receivers:

- notify_feed_updated
  - targets = `private-feed@{alias}` for alias in feed_aliases

- trigger_post_feed_update_from_short
  - proceed only with `RE_USER_OUTBOX_SHORT` matched feed_alias

- schedule_generate_shorts_livestream_clip_feed
  - proceed only with `user_livestream-global` feed alias

- trigger_sync_earnings_leaderboard_badges
  - proceed only with `leaderboard-*` feed alias

- set_stale_feed_expired
  - !!!UPDATE: set Feed.exp = timestamp (arg)

- ping_seo
  - publish_feed_to_pubsubhubbub (feed_url=f'https://api.swag.live/feeds/{feed_alias}.rss')

---

# Overview

Feed Item creation:

**MessageFeedItem**

- generate_top_unlocked_stories_by_countries
- generate_message_feed_from_tag (used to generate category feed)
- generate_flix_new_release_by_countries
- generate_flix_top_unlocked_lifetime_by_countries
- generate_flix_feed_by_user
- generate_hashtag_feed
  - create feeds of aliases `{post|story}_by_hashtag_{hash_tag}` from `Post` Model
- generate_sender_feed
- generate_posts_top_viewed
- generate_message_feed_from_mixpanel_insights
- generate_posts_recent_posts_from_outboxes
- generate_stories_recent_7d
- generate_creator_outbox_feed
- generate_shorts_livestream_clips_feed
- create_message_feed_from_id

**UserFeedItem**

- generate_discover
- generate_most_recent_livestream_feed_by_region_group
- generate_user_online_feed_by_countries
- generate_user_feed
- generate_creator_feed
- generate_user_follows_feed
- generate_leaderboard_feed_from_earning

**HashtagFeedItem**

- generate_trending_hashtag_feed
  - alias `hashtag_trending_24h`

## generate_trending_hashtag_feed

- `Feed` query Aggregation:
  - match alias in:
    - post_by_hashtag_{hash_tag}
    - story_by_hashtag_{hash_tag}
  - project alias, items (that not expired)
  - facet by hashtags
