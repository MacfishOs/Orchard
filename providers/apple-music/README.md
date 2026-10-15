# Orchard Apple Music provider

Catalog access to the public Apple Music API (`api.music.apple.com`), returning
the same item, track and detail shapes as the YouTube provider so desktop QML
and Android parse both alike. The runtime code is standard ECMAScript with no
Node, DOM or URL dependency.

The host supplies Fetch and a session: the developer token from the Orchard
account service, the Music User Token from MusicKit sign-in, the storefront,
and the page origin named in the developer token's `origin` claim. Native hosts
send that origin as the `Origin` header.

## Ids

Apple resources travel as Orchard browse ids `am.<type>.<id>`, such as
`am.artists.605800394` or `am.playlists.pl.u-abc`. Tracks carry
`source: "apple_music"` and the bare catalog id in `appleId`.

## Runtime methods

`src/runtime.js` is the QuickJS entry point, exposed as
`OrchardAppleMusicProvider.invoke(method, payload)`:

| Method | Payload | Result |
| --- | --- | --- |
| `session.set` | `developerToken`, `userToken`, `storefront`, `origin` | `{connected}` |
| `storefront.resolve` | `fallback` | the listener's storefront, or `fallback` for guests |
| `catalog.home` | none | personal recommendation shelves, or charts when empty |
| `catalog.home.section` | `browseId` | every supported item in a recommendation shelf |
| `catalog.artist` | `browseId` | artist page: top songs, release shelves, similar artists |
| `catalog.artist.view` | `browseId`, `params` (`view:<name>`) | every item on one artist shelf |
| `catalog.artist.match` | `name` | `{browseId, title}` for an exact name match, or null |
| `catalog.album` | `browseId` | album page with every track |
| `catalog.playlist` | `browseId` | playlist page with every track |
| `catalog.artwork` | `albumId`, `appleId`, `isrc`, or `title`, `artist`, `album` (`kind: "album"` for albums) | `{albumId, name, artist, static, animated, animatedVertical}`, or `{}` when nothing matches |
| `catalog.search` | `query`, `filter` | sections keyed `songs`, `albums`, `artists`, `playlists` |

Apple API failures return `{error: {code, status, message}}`. Codes include
`not_connected`, `not_signed_in`, `developer_token` (401), `user_token` (403),
`not_found` and `rate_limited`.

Artist pages request the undocumented `artistBio` and `editorialVideo`
attributes and retry without them if Apple rejects the request. Third-party
developer tokens never receive editorial fields (`editorialVideo` is dropped,
`editorialArtwork` is a 400). While the listener is signed in to Apple Music,
editorial requests go to `amp-api.music.apple.com` with music.apple.com's own
developer token, read from its main bundle (`src/webToken.js`) and cached until
Apple rejects it. Signed out, or when that fails, the public API answers. Music videos
and stations are left out until Apple Music playback exists.

Run `npm test` for the unit tests.

## Home

`catalog.home` reads `/v1/me/recommendations` with the signed-in listener's
Music User Token. Recommendation titles use `attributes.title.stringForDisplay`
and cards use `relationships.contents`, matching the response shapes in
[MusadoraKit](https://github.com/rryam/MusadoraKit/tree/main/Sources/MusadoraKit/Recommendations).
Empty supported recommendations fall back to storefront charts. Hosts fall
back to YouTube Music if Apple Music is disconnected or Home fails.

Apple Music tracks are catalog metadata; the hosts match them to YouTube Music
for playback. Apple Music subscription audio is not streamed.

## Animated artwork

`catalog.artwork` finds the Apple album behind a song (by Apple id, ISRC or a
title/artist/album search) and reads its `editorialVideo` with `extend` through
the editorial path above, so motion artwork needs an Apple Music sign-in.
`motionDetailSquare` and `motionDetailTall` are the keys music.apple.com uses
for album motion artwork; both are HLS URLs. Hosts use it in place of the
unofficial artwork providers while the listener is signed in.
