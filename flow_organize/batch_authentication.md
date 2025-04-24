# Batch Authentication

Endpoint: [GET] `/pusher/batch-authenticate`

queries:

- app_id (always 100000)
- socket_id (from query, will change)
- channels (from queries)

headers:

- X-Client-ID
- X-Client-PK (basically not used)

decorator:

- `enable_client_hint`
  - Add response headers:
    - `Accept-CH`: DPR
    - `Accept-CH-Lifetime`: 3600 (unit: sec)

func `batch_authenticate` flow:

- parsing each channels to 3 parts:
  - channel_type
    - private (more public information)
    - presence (personal information)
  - feature
    - user
    - message
    - feed
    - goal
    - stream
    - stream-viewer
    - session
    - order
    - asset
    - chat
  - object_id (after `@`)

- in `user_infos`: return list of {channel, (user_info, reason)} object:
  - get list of {channel, (channel_type, feature, object_id), _client_id, user_info} from `cached_user_info`
    **SUMMARY**: 嘗試拿 private-channel data from cache_p
    - IF channel_type is `presence` -> return with user_info NONE
      (無需 cache 私人 channel)
    - vars `_client_ids` = []
    - get cache_p pipeline and loop through _channels.items
      - _client_ids = ANNONYMOUS_CLIENT ('ANNON')
      - _client_ids.append('ANNON')
      - pipeline.hget
        - hash_name = CLIENT_METADATA_v2
          (ext.pusher:channel-data-v2:{channel}) -> here channel will remove enc
        - key = _client_id (always 'ANNON' because for public)
      - return zip through
        - _channels.keys() (channel_name)
        - _channels.values() (channel's parts)
        - _client_ids (always 'ANNON')
        - pusher.tasks.load_user_info(results) (result is hget result)
  - If user_info exist (fetched from cache):
    yield channel, (user_info, None)
  - set Task-related config vars:
    - ...IF 1."presence" OR 2. "private-stream"
      - time_limit = 4
      - expires = 4
      - queue = 'swag.features.notifications/auth/high'
    - ...ELSE
      - time_limit = 2
      - expires    = 2
      - queue      = 'swag.features.notifications/auth'
  - ...IF "presence" -> user_id = g.user.id
    ...ELSE  user_id = None
  - chain[channel_name] = `task.authorize signature`
    - args:
      - channel_type
      - feature
      - object_id
      - client_id
      - user_id
    - config set:
      - time_limit
      - expires
      - queue
  - loop through channel, result from zip(chain.keys(), result.children)
    - ...IF result.successful -> yield (channel (result.result, None))  # HERE, result is user_info
    - ...ELSE ->
      - authorization_errors += 1 
      - yield (channel (None, result.results))
  END OF USER_INFOS

- Aggregate resp with channel info dict:
  key = channel name
  value = 
  - ...IF fail "reason": "reason"
  - ...ELSE `pusher.tasks.authenticate` result

## task.authorize

- fetch auth signal by channel_type
  - authorizations.private
  - authorizations.presence
- Send signal with sender {feature}
- collect signal send results, take each result last elem (each result is iterable)

### authorizations.private

Return pattern in last item:

```py
{
    "events": [{
        "event": "event_name",
        "data": "data",
    }]
}
```

Receivers:

- All senders:
  - `attatch_retained_events`
    for `private-stream`, `private-campaign`s
    - Fetch events data from `Channel.events`

- Sender `goal`:
  - `authorize_goal`
    - event: 'goal.updated'

- Sender `user`
  - `attatch_stream_info`
    - event:
      - stream.online
      - stream.viewers.updated
      - goal.progress.updated
      - goal.added
      - goal.started
      - goal.added
      - session.rating.updated

  - `attach_lovense_online_device`
    - event: device.online
  - `get_online_status`
    - event: user.online
  - `append_reply_price`
    - event: user.reply-price-changed
  - `attach_user_level`
    - event: level.updated
  - `attach_user_events`
    - event: message.sent

- Sender `stream`
  - `stream_info`
    event:
    - stream.online
    - stream.revenue.updated
    - goal.started
    - goal.progress.updated
    - goal.added
    - session.events item
    - stream.viewers.updated
    - source.online
    - session.rating.updated
    - ...event from notifications.tasks.get_retained_ephemeral_events(session_id)
  - `attach_lovense_online_device`
    - event: device.online

### authorizations.presence

Receivers:

- user
- client
- asset
- chat
- goal
- session
- stream
- stream-viewer
- stream-exclusive
- session-exclusive
- order
- message

## pusher.tasks.authenticate

with args:

- channel
- socket_id
- custom_data
- app_id

- Aggregate response data:
  - auth (f"{key}:{signature}")
  - shared_secret (base64 encoded)
  - channel_data (custom_data)

---

QUESTION:

We dont use `presence-` prefix user_info from cache, but we still store it in Cache?

ANSWER: will be used in pusher callback.
