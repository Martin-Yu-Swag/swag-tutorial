## Generation of `short_curated` Feeds

starts with `schedule_generate_message_feed_from_tag`

### schedule_generate_message_feed_from_tag

- Collect tag From `Message.tags` fields (which may include `short_curated`)
- var aliases = ['shorts_curated', 'shorts_curated_infinite']
- Trigger func `generate_message_feed_from_tag` with
  - tag     = "feed:short_curated"
  - aliases = aliases

**generate_message_feed_from_tag**

SUMMARY:
  - collect all message `feed:short_curated`
  - duplicate strategy if count less than 10000
  - Insert into Feed collection as items field

- Init new ObjectId for var `feed_id`
- var _tag = tag
- check tag match `RE_FEED` -> tag = short_curated, _tag = feed:short_curated
- re.compile
  - tag_pattern `rf'^(?P<name>{_tag})(:(?P<priority>\d+))?$'`
  - tag_pattern_match `rf'^{_tag}(:(?P<priority>\d+))?$'`
- var aliases = ['shorts_curated', 'shorts_curated_infinite']

- Init Message query:
  - filter tags=tag_pattern_match, posted_at <= now
  - add a [query comment](https://www.mongodb.com/docs/manual/reference/method/cursor.comment/) with json string
  - add [hint](https://mongoengine-odm.readthedocs.io/apireference.html#mongoengine.queryset.QuerySet.hint) on index `tags_1`

  - aggregate stages: (FOR FINAL `$merge` Operation)
    - $addField:
      - badges (from `tags` regex)
      - unlocks (`unlocks` or [])
      - boosted_unlocks (from `tags` regex)
    - $addField:
      - `boosted_unlocks` (from `boosted_unlocks`)
    - $unwind: tags
    - $addField
      - matched: tags '^(?P<name>feed:short_curated)(:(?P<priority>\d+))?$'
    - $match: filter out matched is NONE row (aka the rest all have `feed:short_curated`)
    - $addField: __priority__ by matched captures (`<priority>`) * -1
      ???QUESTION: who add these priority tags?
      (BUT `shorts_curated` tag dont sort by priority, so basically this doesn't affect)
    - $project
      - id
      - _cls = MessageFeedItem
      - sender
      - caption
      - posted_at
      - unlock_price
      - expires_at
      - metadata (dict include bunch of data)
      - assets
      - badges
      - __priority__
    - (Following are yielded from `_duplicated()` func, which is specially for `shorts_curated`)
      SUMMARY: Duplicate the item count by N times, then shuffle each list randomly
    - Grab `item_count` from posts available query:
      - filter tags=feed:shorts_curated, tags not in (EXCLUDE_TAGS - hidden:discover, hidden:feed)
      - ...IF `item_count` >= SHORTS_CURATED_COUNT (10000) -> RETURN
    - eg: if `item_count` = 3000, vars:
      - `duplicate_count` = SHORTS_CURATED_COUNT // item_count = 3
      - `remaining_count` = SHORTS_CURATED_COUNT % item_count = 1000
    - $facet:
      - f"items-{i}": (for i in range(duplicate_count))
        - $addFields: sort_by ($rand)
        - $sort: sort_by
        - $unset: sort_by
      - f"items-{duplicate_count}" (these for remaining)
        - $limit: remaining_count
    - $project:
      - items: concat all above facet stages (so the total num is 10000)
    - $unwind: items
    - $replaceWith: items
    - Save all these content into Feed Collection through `save_as()` (exp = 2 hours later)

- Send `feature.feed` signal with `updated` sender and args:
  - feed_id
  - feed_aliases = aliases ()
  - timestamp = now

Receivers:

- `notify_feed_updated` (not match NOTIFY_FEED_PATTERN, returned)
- `trigger_post_feed_update_from_short` (not match RE_USER_OUTBOX_SHORT, returned)
- `schedule_generate_shorts_livestream_clip_feed` (returned)
- `trigger_sync_earnings_leaderboard_badges` (returned)
- `set_stale_feed_expired`: update `Feed.exp`
- `ping_seo`: publish_feed_to_pubsubhubbub

---

## In retrieval of short_curated aliases feed:

Endpoint `/feeds/short_curated`

- 目前 `infinite` 是沒有作用的
- `short_` started alias will be randomize
  - 在 redirect 時隨機給 `page`
