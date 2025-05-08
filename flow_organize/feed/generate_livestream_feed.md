# Generate Livestream Feed

- Trigger Task `generate_most_recent_livestream_feed_by_region_group`
  - **args**:
    - aliases
      - 'user_livestream-global'
    - region_group = "global"
  - metadata
    - __debounce__ = 'feature.feeds:user_livestream:global:{time.time() // 60}'

- Trigger Task `generate_most_recent_livestream_feed_by_region_group`
  - **args**
    - aliases
      - user_livestream-global-filtered
    - region_group = "global"
    - filtered     = False
  - metadata
    - __debounce__ = 'feature.feeds:user_livestream:global-filtered:{time.time() // 60}'

- Trigger Task `generate_custom_jp_livestream_feed`
  - **args**
    - aliases
      - 'user_livestream-custom_jp'
    - metadata
      - __debounce__ = 'feature.feeds:user_livestream:custom_jp:{time.time() // 60}

## Task `generate_most_recent_livestream_feed_by_region_group`

- `Session` aggregate:
  - `$match`: active
  - `$project`
    - user
    - status
    - tags_obj: `$map`
      - input: $tags
      - as: tag
      - in: $let
        - vars: parts = $split [`$$tag`, ':']
        - in
          - k: $arrayElemAt $$parts, 0
          - v: $arrayElemAt $$parts, 1
    - statuses.started
    - show_goal_pairs
    - exclusive_goal_pairs
    - rating.current: `$switch`
      - branches
        - case $lt
          - '$ifNull': ['$rating.current_count', 0]
          - VALID_RATING_COUNT (20)
          then 0
      - default: $ifNull '$rating.current', 0
    - metadata.viewer_count_v2
    - settings
  - `$lookup` `User` as user
    - localField  : user
    - foreignField: _id
    - pipeline
      - `$match`
        - tags:$nin (EXCLUDE_TAS)
          - hidden
          - banned
          - beta
          - hidden:discover
          - hidden:feed
          - no_exposure
          (IF not filtered)
          - hidden:region-group:global
      - `$project`
        - profile.biography
        - username
        - tags
  - `$unwind` user (filter out those doc that user is null)
  - `$addFields`
    - __priority__: `$map`
      - input: $user.tags
      - as   : tag
      - in   : $regexFind
        - input: $$tag
        - regex: ^feed:(?P<name>[A-Za-z0-9-_]+)(:(?P<priority>\d+))?$
    - trending_ranking: `$indexOfArray`
      - trending_creators (from Task `get_trending_creators`)
      - '$toString': '$user._id'
  - `$addField`
    - __priority__: `$first` `$filter`
      - input: `$__priority__.captures`
      - as: captures,
      - cond: {'$in': [{'$first': '$$captures'}, aliases]}
        (alias = `user_livestream-global` OR `user_livestream-global-filtered`)
        (get <name> of feed tag)
    - `$sort`
      - '__priority__': -1,
      - 'trending_ranking': -1,
      - 'statuses.started': -1,
    - `$lookup` Earnings as revenue
      **SUMMARY**: fetch earning by session_id
      - localField: user._id
      - foreignField: user
      - let
        - summary_key: $concat ['stream', ':', '$toString' $_id]
        - timestamp: $dateSubtract
          (NOTE: Over-select by 1 hour)
          - startDate: $statuses.started
          - unit: hour
          - amount: 1
      - pipeline
        - `$match`: `$expr`
          - $gte: '$timestamp', '$$timestamp' // here timestamp is Earnings.timestamp
        - `$project`
          - summary: '$objectToArray': '$summary' 
            // summary: dict[str, dict]
            // -> [{k:'', v:''}, {k:'', v:''}...]
        - `$unwind`: '$summary'
        - `$match`: `$expr`
          - $eq: $summary.k, '$$summary_key' ("stream:<session_id>")
    - `$addFields`:
      - user.metadata.preset: $status.preset
      - user.metadata.goal: $let
        **SUMMARY**: exclusive / show / funding / None
        - vars
          - show_goal: '$last': '$show_goal_pairs'
          - exclusive_goal: $first $filter
            - input: $ifNull {'$objectToArray': '$exclusive_goal_pairs'}, []
            - as: pair
            - cond: `$and`
              - $ne: $ifNull [$$pair.v.exclusive_goal', None] None
              - $eq: $ifNull [$$pair.v.exclusive_goal_ended None] None
        - in: $switch
          - case: $ne $ifNull ['$$exclusive_goal', None] None
            then "exclusive"
          - case: `$and`
            - {'$ne': [{'$ifNull': ['$$show_goal.show_goal', None]}, None]}
            - {'$eq': [{'$ifNull': ['$$show_goal.show_ended', None]}, None]}
            then "show"
          - case `$and`
            - {'$ne': [{'$ifNull': ['$$show_goal.funding_goal', None]}, None]},
            - {'$eq': [{'$ifNull': ['$$show_goal.funding_ended', None]}, None]},
            then "funding"
          - default: None
      - user.metadata.revenue: $sum $revenue.summary.v.total
      - user.metadata.viewers: $cond 
        **SUMMARY** num of viewers
        - if: `$size` $ifNull ['$status.exclusive_to', []]
        - then `$min` ['$metadata.viewer_count_v2.sd', 1]
        - else $add
          - '$ifNull': [f'$metadata.viewer_count_v2.preview', 0]
          - '$ifNull': [f'$metadata.viewer_count_v2.sd', 0]
      - user.metadata.started         : $statuses.started
      - user.metadata.trending_ranking: $trending_ranking
      - user.metadata.current_rating  : '$rating.current'
      - user.metadata.setting_trigger_private: `$cond` (0/1)
        - if: '$settings.trigger_private'
        - then: 1
        - else: 0
      - user.metadata.setting_trigger_exclusive: `$cond` (0/1)
        - if: '$settings.trigger_exclusive'
        - then: 1
        - else: 0
      - user.__priority__: $__priority__
      - users.metadata.{field}
        (Session tags based metadata)
        (field = 'badge', 'category', 'hashtag', 'country', 'device')
    - `$replaceWith`: $user
    - `$addFields`
      - metadata.s_score: `$multiply`
        - '$ifNull': ['$metadata.current_rating', 0]
        - '$ifNull': ['$metadata.viewers', 0]
    - `$project`
      - _id  = False
      - _cls = UserFeedItem
      - __priority__
      - id = $_id
      - username
      - biography = $profile.biography
      - metadata
      - badges: $setDifference // to remove null value
        **SUMMARY**: pluck "badges:<value>" value in tags
        - `$map`
          - input: $tags 
          - as   : tag
          - in   : $let
            - vars: matched `$regexFind`
              - input: $$tag
              - regex: '^badge:(.+)$'
            - in:
              - $first: $$matched.captures
        - [None]
    (following yield from `save_as`)
    - `$group`:
      - _id: None
      - items: {`$push`: $$ROOT}
    - `$project`
      - _id: False,
      - aliases.*
        - user_livestream-global
      - last_modified = now
      - exp = now + 2 hour
      - metadata
        - total: $size $items
      - items
    - `$addFields`
      - _id: (newly generated ObjectId)
    - `$merge`!!!
      - into: Feed
      - on: _id
      - whenNotMatched: insert
      - whenMatched
        (Not gonna match, so skip)

- Send signal `features.feeds` sender `updated`
  - **args**
    - feed_id
    - feed_aliases
      - "user_livestream-global"
    - timestamp = now
  - **receivers**:
    - `notify_feed_updated`
      - targets: private-feed@user_livestream-global
      - event: `feed.updated`
    - trigger_post_feed_update_from_short **returned**
    - `schedule_generate_shorts_livestream_clip_feed`
    - trigger_sync_earnings_leaderboard_badges **returned**
    - set_stale_feed_expired **returned**
    - ping_seo

### `updated` -> `schedule_generate_shorts_livestream_clip_feed`

NOTE: 現在已經不會產生 `feed:shorts_livestream` clip post，故這邊不會有 Feed 產生
(在 `produce_livestream_clip_from_goal` 裡跳過 Source 為 BytePlus 的情境)

- Aggregate Session:
  - `$match`: active True
  - `$lookup`: Message as items (actually get 1 item for each streamer)
    - foreignField: sender
    - localField: user
    - pipeline
      - `$match`:
        - _cls: Post
        - posted_at: $gt (now - 7 days)
        - `$and`
          - tags: 'feed:shorts_livestream'
          - tags: $nin
            - hidden
            - banned
            - beta
            - no_exposure
      - `$sort`: posted_at -1
      - `$limit`: 1
  - `$unwind`: $items
  - `$group`
    - _id: None
    - $items: $push $items
  - `$addFields`
    - items: $let
      - vars
        - dup_factor: $ceil $divide 10000 $size $items  // 10000 = SHORTS_CURATED_COUNT
      - in: $slice
        - $reduce
          - input       : $range (0, "$$dup_factor")
          - initialValue: $items
          - in          : $concatArray $$value $items
        - 10000
  - `$unwind` $items
  - `$replaceWith` $items
  - `$project`
    - id: $_id
    - _cls

