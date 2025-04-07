# [Channels](https://pusher.com/docs/channels/)

> Pusher Channels provides realtime communication between servers, apps and devices.

> When an event happens on an app, the app can notify all other apps and your system.

> Pusher Channels works everywhere because it uses WebSockets and HTTP.

> Pusher Channels has pub/sub model.

> You can publish sensitive data via private channels.
> Apps must get permission to subscribe to a private channel.

> **Presence channels** show who is online.

> **Pusher Channels** tells you everything that’s happening,
> so you can debug, analyze and record your application’s activity.

# [Using Channels](https://pusher.com/docs/channels/using_channels/channels/)

- no need to be explicitly created, are instantiated on client demand.

## Types of channels

### [Public channels](https://pusher.com/docs/channels/using_channels/public-channels/)

- can be subscribe to by anyone who knows the channel name.
- subscribe and unsubscribe from channels at any time

### [Private channels](https://pusher.com/docs/channels/using_channels/private-channels/)

- with prefix `private-`
- control access to broadcasted data

### Private encrypted channels

- with prefix `private-encrypted-`
- adding encryption of the data payloads

### Presence channels

- with prefix `presence-`
- an extension of private channels
- to register user's info on subscription

### Cache channels

> remembers last published message and delivers it to clients when they subscribe

- available in public, private, and private-encrypted modes

## Channel Naming Conventions

- a maximum of 164 char
- upper + lower + numbers + punc (`_ - = @ , . ;`)

## Accessing Channels

`channel = pusher.channel("channel-name")`
