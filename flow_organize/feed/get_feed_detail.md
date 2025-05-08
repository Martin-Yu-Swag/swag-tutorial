# Get Feed Detail

Endpoint: `/feeds/<string:aliases>`

**SUMMARY**: Get feed's items by `aliases` (string or Feed id), and format response structure by `format`

queries 1:

- page = 496
- limit = 10
- no-redirect = 1
- infinite = 0
- _aliases=shorts_curated

queries 2:

- _ = 1745201989
  (timestamp)
- page = 1
- limit = 10
- sorting = desc:s_score
- ui = livestream-square

queries 3:

- limit       = 10
- page        = 1
- ui          = leaderboard-user-square
- no-redirect = 1
- _aliases    = user_new_creator_leaderboard_a
- infinite    = 0
- format      = user

func `get_feed_detail` flow:

- aliases may be one of following: (basically only ONE of them)
  - 首頁
  - {bson_id} (after redirect)

  - user_livestream-global

  - user_leaderboard_livestream
  - leaderboard-global-livestream-24h
  - user_leaderboard_livestream_24h_a
  - user_new_creator_leaderboard_a (新人榜)

  - shorts_curated (NOTE: infinite looping, 可以一直滑的短影片頁面)

  - stories_top_100_unlocked_48h-global (追蹤中)
  影片頁面
  - discover_dream
  - discover_new
  - post_video_635688324a11ceb2c9fc3fa7 (by sender)
  - flix_nu_free_video-global
  - flix_showcase-global
  - flix_recent_free-global
  - flix_pro-global
  - lix_user_peachmedia
  - showcase_a
  - hashtag_trending_24h (一排 hashtags)
  - stories_recommended-global
  - discover_sexy
  - stories_recent_7d_global
  - stories_top_viewed_7d-global
  - stories_top_100_unlocked_48h-global
  - discover_western
  - stories_message_pack-global
  選分類後頁面
  - story_by_category_glasses (限動)
  - post_video_by_category_glasses (影片)
  - short_by_category_glasses (短影片)
  - post_image_by_category_glasses (照騙)

- IF any elem of [alias + aliases] begin with "shorts_" -> `randomize_page` = True
- IF No `infinite` -> `infinite` = (any elem of [alias + aliases] begin with "_infinite")
- IF "ME" in aliases -> replace "ME" string with user_id in aliases, and `private_feed` = TRUE

- IF string alias (not id) exist in aliases
  -> Resolve aliases to `Feed` IDs, then redirect
  - filter:
    - nbf passed (or None)
    - exp yet (or None) OR `metadata__pinned__0__exists` True
    - aliases__in = aliases OR alias__in = aliases
  - aggregate:
    - `$project`:
      - aliases: $concatArrays [[$alias], $aliases]
      - last_modified
      - metadata
      - exp
    - `$unwind` $aliases
    - `$match` {$aliases: {$in: aliases}}
    - `$sort` {$last_modified: -1}
    - `$group`
      - _id: $aliases
      - item: {'$first': '$$ROOT'}
    - `$replaceWith`: $item

  - ...IF len(feeds) != len(aliases) -> return 404 with private cache_control 5 min

  - ...IF not no_redirect -> **ask for redirect**, prepare redirect response (302 FOUND)
    - resp.location = `/feeds/{'&'.join(feed_ids)}`
    - set cache_control attribute...
    - return 302

- following are redirected content, where aliases are already parsed into feedIds...

- `Feed` query
  - (if timestamp) query.primary
  - query.p_aggregate by page
    - `$match`: _id $in feed_ids
    - `$unwind`
      - path: $items
      - includeArrayIndex: items.index
    - `$project`
      - $items._search: False
    - `$addFields`
      - items.id: $ifNull '$items.id', '$items._id'
      - items.badges: $setUnion
        - $ifNull $badges []
        - $ifNull $items.badges []
      - items.tags: $ifNull $items.tags []
      - items.metadata: $mergeObjects $items.metadata $metadata
    - `$addFields`
      - items.badges: `$setDifference`
        **SUMMARY**: parsed content started "badge:" from items in badges | tags
        - `$setUnion`
          - `$map`:
            - input: $items.badges
            - as: badge
            - in: `$switch`
              - branches:
                - case: `$regexMatch` input: $$badge regex: '^badge:'
                  then: `$arrayElemAt` [{`$split`: ['$$badge', 'badge:']}, 1]
              - default: $$badge
          - `$map`
            - input: $items.tags
            - as: tag
            - in: `$switch`
              - branches
                - case $regexMatch input: $$tag regex: '^badge:'
                  then `$arrayElemAt` [{`$split`: ['$$tag', 'badge:']}, 1]
              - default: None
          - `$setIntersection`
            (map 'flix' badges)
            - $ifNull $items.tags, []
            - [flix]
        - [None] (NOTE: to exclude null value)
    - `$replaceWith` $items
    - (IF feed_ids > 1)
      - `$group`
        - _id: $id
        - count: $sum 1
        - item: {'$mergeObjects': '$$ROOT'}
        - metadata: {'$mergeObjects', '$metadata'}
      - `$match`: count len(feed_ids)
        **NOTE**: item's id 為另一個 Collection 的 ID (eg. UserFeedItem -> user id, MessageFeedItem -> message id)
        用 item's id grouping 後，如果 count == len(feed_ids)，代表這個 Item 在兩個 Feed 都存在 (即 FeedItem 的交集)，
        就是要找到 multiple Feed & 的對象
      - `$addFields`: item.metadata: $metadata
      - `$replaceWith`: $item
    - (IF filters queries)
      - `$match`:
        - metadata.{key}: {$in: filters.getlist(key)} for key in filters if key not exp
        - `$or` (of key is "exp")
          - expires_at None
          - expires_at $gt now
          - `$expr`: $in
            NOTE: CHECK item id in metadata.pinned
            - $ifNull: $id, $_id
            - $ifNull: $metadata.pinned, []
    - `$facet`
      - pinned
        - `$match`: `$expr`
          - $in: $id, `$ifNull` [$metadata.pinned, []]
        - `$addFields`
          - metadata.pinned: $indexOfArray: [$metadata.pinned, $id]
        - `$sort`: metadata.pinned: 1
      - non_pinned
        - `$match`: $expr
          - `$not`: {$in: [$id, $ifNull['$metadata.pinned', []]]}
        - `$project`
          - 'metadata.pinned': False,
        - `$sort`:
          - '__priority__': -1,
          - '_search.score': -1,
          - (IF sorting query)
            metadata.{sorting["field"]}': sorting['ordering'],
          - 'index': 1,
    - `$project`:
      - items: `$concatArrays`
        - $pinned
        - $non_pinned
    - `$unwind` $items
    - `$replaceWith` $items
    - (format output by types)
      - 'user', 'discover', 'livestream'
      - 'hashtag'
      - default