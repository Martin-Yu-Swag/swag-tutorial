# Karaoke Features Flow

## Q: How we get Karaoke menu list?

A: In Batch-authentication, fetch from `private-enc-stream@{streamer_id}` channel data

`user_info.events.{stream.online event}.data.karaoke_menu`

which is fetched from Model: `session.karaoke_menu` (ProductItem list)

ProductItem:
  - id
  - name
  - metadata
    - points
    - duration
    - device

Which is attached to session in `bind_karaoke_menu`, the ProductItem is mapped from `GiftProduct` model records.

---


