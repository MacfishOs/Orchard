## Orchard Mobile 2.0.0-beta.9 "Ensues Worryingly"

### Added
- **Mobile Data Quality**: Choose a separate audio quality for mobile data, applied automatically when the phone leaves Wi-Fi.
- **SD Card Downloads**: Store new downloads on the SD card from Storage & updates.

### Changed
- **Adaptive Mix**: Blends match each song's section tempo. Pairs that only work behind a filter and R&B pairs that cannot blend cleanly play out at their natural boundary. Best Mix sees these blends too.
- **Qobuz Streaming**: Lower startup and seek latency for FLAC streams.
- **Interface**: The bottom bar no longer shows a Settings tab, the search results panel uses lighter glass, and the Song/Video switch stays clear of the artwork.
- **Music Video Search**: Searches run as a guest so plays stay out of YouTube search history.

### Fixed
- **Uploaded Songs**: Streams from c.youtube.com hosts now play, in playback, downloads, and Best Mix analysis.
- **Albums**: Cards that carry a video id open the album page.
- **Autoplay**: A blank artist is treated as unknown when matching song variants.
- **Widget**: Cover art renders at device pixel size.
- **Queue Badge**: The queue badge in the player is no longer clipped.

### Maintenance
- **Licensing**: The adaptive mix engine and its crates are licensed under OOL-1.0.
- **Testing & Tooling**: Added section tempo, Qobuz stream server, and Autoplay tests.
