# Upsert session

Initialize a Session

End point: [POST] `/sessions`

func `upsert_livestream_session` flow:

A. for brand new Session

- execute `activate_session`
  - **args**
    - session_id = ObjectId()
    - user_id
    - title
    - tags = []
  - !!!Create `Session` through upsert
    - set_on_insert
      - id
      - user
      - statuses__created = now
      - pricing = Session.SessionPricing(default)
      - status__preset = "preview"
      - title = tile
      - tags.*
        - yield user.tags with
          - "country:*"
          - "hashtag:"
          - "badge:new"
        - "device:lovense"
          (IF attach_lovense_online_device)
    - unset__statuses__ended = True
    - set__active            = True
        
- Send signal `session.started`

---

- init session_id (ObjectId())

- fetch doc from `Source` model:
  - filter: user = g.user_id
  - aggregate:
    **SUMMARY**: Filter out Source that match user and started
    - $project: 
      - sources = objectToArray sources (originally DictField[str, `Source`])
    - $unwind: sources
    - $replaceWith: $sources.v (`Source` instance)
    - $match:
      - statuses.started exist
      - metadata.session_id: exist
    - $project
      - session_id
- IF doc exist -> session_id = doc['session_id']
- Execute `activate_session` to get session_doc
  **SUMMARY**: upsert and fetch session 
  - set vars:
    - preset = Session.SessionStatus.preset.default (`preview`)
    - pricing = Session.pricing.default (preview / sd)
  - Init `Session` query and fetch:
    - filter:
      - active = True OR id = session_id AND user = user_id
      - status.ended = False
    - modify (new=true, upsert=true):
      - set_on_insert:
        - id               = session_id
        - user             = user_id
        - statuses.created = now
        - pricing          = pricing
        - status.preset    = preset
        - tags = 
          - loop yield on user.tags, starts with
            - `country:*`
            - `hashtag:`
            - or `badge:new` -> 新人主播
          - if has device -> `device:lovense`
      - set: active = True
      - unset: statuses.ended = now
  - Send `features.livestream` signal with sender `session.started` and 
    - args:
      - session_id      = session.id,
      - streamer_id     = session.user.id,
      - preset          = session.status.preset,
      - price           = session.get_price(),
      - show_goal_pairs = session.show_goal_pairs
      - tags            = session.tags
    - Receivers:
      - `set_session_name`
        update `session.metadata.name` = `badge:livestream_*` (from user.tags)

      - `generate_livestream_feed`
        generate feeds with alias: r'^user_livestream-{region}(-filtered)?$'

      - `initialize_session_rating`
        fill the session rating with previous session rating

      - `notify_viewers_livestream_online`
        - channel: `presence-session@{session_id}` QUESTION: WHO can subscribe this channel?
        - event: `stream.preset.{status}`

      - `notify_followers_livestream_online`
        notifications through firebase message

      - `notify_existing_show_goal`
        no show_goal_pairs, returned

      - `invalidate_cached_pusher_channel_data`
        invalidate old following channel cache data and renew them through notifications.tasks.authorize
        - f'private-user@{streamer_id}'
        - f'private-enc-user@{streamer_id}'
        - f'private-stream@{streamer_id}'
        - f'private-enc-stream@{streamer_id}'

      - `cleanup_stale_stream_viewers`
        remove `StreamViewer.viewer.{preview,sd}` record if it is expired


  - return session.to_mongo().to_dict()
  END OF `activate_session`

- Return session information

### `session.started` -> `generate_livestream_feed`

**SUMMARY**: generate 4 feeds with aliases:
- user_livestream-global, user_livestream_most_recent-global
- user_livestream-global-filtered, user_livestream_most_recent-global-filtered
- user_livestream-asia, user_livestream_most_recent-asia
- user_livestream-asia-filtered, user_livestream_most_recent-asia-filtered

- args:
  - streamer_id

func flow:

- fetch user by streamer_id
- set vars groupings = {} (Dict[alias, country])
- set vars user_tags = user.tags
- loop through `constants.regions.GROUPINGS.items()` to collect groupings:
  - grouping["global"] = None
  - grouping["asia"]   = "country" (if f"country:{country}" in 
  tags, in my case, grouping["asia"] = "tw")
- looping through alias in grouping: (global, asia)

  - Trigger Task `generate_most_recent_livestream_feed_by_region_group`
  args:
    - kwargs
      - aliases:
        - user_livestream-{alias}
        - user_livestream_most_recent-{alias}
      - region_group = alias
    - metadata.__debounce__ = f'feature.feeds:user_livestream:{alias}:{time.time() // 60}'
    - countdown=15

  - Trigger Task `generate_most_recent_livestream_feed_by_region_group` (NOT filtered version)
  args:
    - kwargs
      - aliases:
        - user_livestream-{alias}-filtered
        - user_livestream_most_recent-{alias}-filtered
      - region_group = alias
      - filtered     = False
    - metadata.__debounce__ = f'feature.feeds:user_livestream:{alias}-filtered:{time.time() // 60}'
    - countdown=15

#### `generate_most_recent_livestream_feed_by_region_group`

**SUMMARY**:
Aggregate streamer data from Session then merge_on Feed collection
- `filtered` argument:
  - True = 包含 filtered-tagged 用戶
  - False = 排除 filtered-tagged 用戶
  (here filtered means "filtered user" 要排除掉的用戶)

- set vars:
  - now
  - feed_id (newly init)
  - countries = constants.regions.GROUPINGS[region_group]
    (tw)

- collect `match_tags` dict
  - match_tags[$nin] = list(EXCLUDE_TAGS)
  - ...IF not filtered: (不要 filtered-tagged 用戶)
    match_tags[$nin] = list(EXCLUDE_TAGS) + [f'hidden:region-group:{region_group}']
  - ...IF countries: (NOTE: "global" alias won't have country)
    match_tags['$in'] = [f'country:{country}' for country in countries]

- trending_creators = streamer_id from livestream.tasks.get_trending_creators()

- Aggregate `Session` model (from primary DB):
  - `$match`: active is True
  - `$projecr`
    - user
    - status
    - statuses.started
    - show_goal_pairs
    - exclusive_goal_pairs
    - rating.current
      - `$switch` case for parsing rating.current_count: when under 20, show 0
    - metadata.viewer_count
    - metadata.name
  - `$lookup` pipeline: user field
    - `$match`: tags = match_tags
    - `$project`: profile.biography, username, tags
  - `$unwind` user
    (filter out non-match user session)
  - `$addFields`
    - __priority__: map tag match 
      ('^feed:(?P<name>[A-Za-z0-9-_]+)(:(?P<priority>\d+))?$')
    - trending_ranking: $indexOfArray to find user_id in trending_creators
  - `$addField`:
    - __priority__: first non-Null and feed name in `aliases` from __priority__.captures
  - `$addField`:
    - __priority__ =  -1 * feed property number
  - `$sort` by
    - __priority__: -1,
    - trending_ranking: -1,
    - statuses.started: -1,
  - `$lookup`
    - aggregate `revenue` field from `Earning` by user._id
  - `$addFields`:
    - user.metadata.preset
    - user.metadata.goal
    - user.metadata.revenue
    - user.metadata.viewers
    - user.metadata.started
    - user.metadata.trending_ranking
    - user.metadata.current_rating
    - user.metadata.s_score
    - user.__priority__
  - `$replaceWith`: $user
  - `$addField`: s_score by metadata.current_rating * metadata.viewers
    (排序依據 = 用戶數 * 當前 session 評分)
  - `$project`:
    - _id = False
    - _cls = UserFeedItem._class_name
    - __priority__
    - id = $_id
    - username
    - biography
    - metadata
    - badges: user.tags that match r'^badge:(.+)$'
  - `$merge`: on `Feed._id`

- Trigger Signal `features.feed` with sender `updated`

---

### `session.started` -> `set_session_name`

**SUMMARY**: update `session.metadata.name` = `badge:livestream_*`

- pluck user_id from kwargs.streamer_id
- fetch user by user_id, get tags from user.tags
- var name = first `badge:livestream_*` in tags
- !!!Update Session:
  - metadata.name = name

### `session.started` -> `initialize_session_rating`

**SUMMARY**: fill the session rating with previous session rating

- fetch previous session by
  - user = streamer_id
  - statuses.started < ObjectId(session_id).generation_time
  - rating.current not NONE
- !!!Update session by session_id
  - rating = SessionRating()
    - previous       = previous_session.rating.current,
    - previous_count = previous_session.rating.current_count,
    - current        = previous_session.rating.current,
    - current_count  = previous_session.rating.current_count,

- Send signal `features.livestream` with sender `rating.updated`

### `session.started` -> `cleanup_stale_stream_viewers`

**SUMMARY**: remove `StreamViewer.viewer.{preview,sd}` record if it is expired (3 days ago)

- set exp = now - 3 days
- !!!Update StreamViewer
  - filter: streamer = streamer_id
  - set:
    - viewers.preset (filter out timestamp > exp)
    - viewers.sd     (filter out timestamp > exp)

