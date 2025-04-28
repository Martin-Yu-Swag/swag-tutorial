# Rate Session

**SUMMARY**: 

- update rate in Session.ratings.{user_id}
- IF rating is 100, notify with event `session.rated`

---

Endpoint: [PUT] `/sessions/<objectid:session_id>/rate`

Body:

```json
{
    "rating": 100
    // 20, 40, 60, 80, 100
}
```

func `rate_session` flow:

- fetch session by session_id
- ...IF user.tags has "blocked_by:{session.user_id}" -> raise UserBlocked
- !!!update SessionVote:
  - filter:
    - session=session_id
    - `ratings.{user_id}` don't exist
  - set:
    - `last_sync` = None
    - `ratings.{user_id}` = rating
- Send Signal "features.livestream" with sender `session.rated`
  - args:
    - session_id = session_id,
    - user_id    = g.user.id,
    - rating     = rating,
  - Receivers:
    - track_session_rated
    - notify_session_best_rating
      - Only notify when rating = 100
      - channels:
        - f'presence-stream@{session.user.id}',
        - f'private-stream@{session.user.id}',
        - f'presence-session@{session.id}',
      - event: `session.rated`
