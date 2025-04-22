# Livestream Leaderboard

Endpoint: `/sessions/<objectid:session_id>/leaderboard` (鑽石排行榜)

進入直播後，瀏覽鑽石排行版 tab

SUMMARY: Aggregate result from `Earnings` models

`breakdown` field: dictionary
  - KEY: stream:{category}:{session.id}
  - VALUE: dictionary
    - KEY: user ObjectID
    - VALUE: dictionary
      - total: number

Queries:

- `days`: 1 / 7 / 30 (default=1)
- `page`
- `limit`
- `_` (timestamp)
- `category` (default {'views', 'gifts', 'chat'} if not provided)

func `get_session_leaderboard` flow:

- Fetch Session by `session_id`
- var start = `session.statuses.started`
- var end
  - (session.statuses.ended + 1 hr) IF exist
  - ELSE NONE
- var `categories` set (default has "gifts")
  - add "karaoke", "show"

- Init query from `insights.models.Earnings` to for further aggregation:
  - if (timestamp - now) > 6s: queryset use `primary()`
  - query between (start, end) (從直播開始到直播後結束 1 hr)
  - stages:
    - $match: user = session.user.id
    - $facet:
      - "total|diamonds|{views}"     // {category} substitution
        - $project: users: [{'$objectToArray' : f'$breakdown.stream:{views}:{session.id}'}]
                                                  // dict = breakdown, key = "stream:views:session_id"
                                                  // value type: dict[objectID, dict]
                                                  // result: users: [ [{"k": objectID, "v": "dict"},...], [{"k": objectID, "v": "dict"},...], ...]
        - $unwind: users
          // result: users: [{"k": objectID, "v": dict}]
        - $unwind: users
          // result: users: {"k": objectID, "v": dict}
        - $match: users.k NOT SYSTEM_USER
        - $project:
          - _id: {'$toObjectId': '$users.k'}
          - total: users.v.total
          - total|diamonds|{views}: users.v.total
      - "total|diamonds|{gifts}"
      - "total|diamonds|{chat}"
      - "total|diamonds|{karaoke}"
      - "total|diamonds|{show}"
    (AFTER facet)
    - $project:
      - totals: concatArrays: [
          "$total|diamonds|views",
          "$total|diamonds|gifts",
          "$total|diamonds|chat",
          "$total|diamonds|karaoke",
          "$total|diamonds|show",
        ]
        
    - $unwind: totals
      result: [totals: {_id: "", total: "", total|diamonds|{cat}: ""}]
    - $group: (grouped by user id)
      - _id: $totals._id
      - total|diamonds|views: $sum: "totals.total|diamonds|views"
      - total|diamonds|gifts
      - total|diamonds|chat
      - total|diamonds|karaoke
      - total|diamonds|show
    - $addField:    // LEADERBOARD_CATEGORIES
      - total: $sum: [
        $total|diamonds|{views},
        $total|diamonds|{gifts},
        $total|diamonds|{chat},
        $total|diamonds|{exclusive},
      ]
    - $sort -1 by total
    - $project:
      - id: $_id (user id)
      - total
      - total|diamonds|views ('$total|diamonds|views' + '$total|diamonds|chat')
      - total|diamonds|gifts (total|diamonds|gifts - total|diamonds|karaoke - total|diamonds|show)
      - total|diamonds|karaoke
      - total|diamonds|chat
      - total|diamonds|show
      - total|diamonds|exclusive

- Organize `objects` from aggregation query:

  ```py
  for obj in objects:
      obj['summary'] = {
          'total.diamonds.gifts'    : obj.pop('total|diamonds|gifts', None)     or 0,
          'total.diamonds.views'    : obj.pop('total|diamonds|views', None)     or 0,
          'total.diamonds.karaoke'  : obj.pop('total|diamonds|karaoke', None)   or 0,
          'total.diamonds.chat'     : obj.pop('total|diamonds|chat', None)      or 0,
          'total.diamonds.show'     : obj.pop('total|diamonds|show', None)      or 0,
          'total.diamonds.exclusive': obj.pop('total|diamonds|exclusive', None) or 0,
      }
  ```

- Preparing response attr: headers X-Total-Count, link, cache_control

---


https://api.swag.live/sessions/680721c0623f20ec317207c9/leaderboard?limit=15&page=1&_=1745300994&category=all

