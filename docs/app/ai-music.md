---
title: AI-generated music
summary: Mark, skip, or remove songs that YouTube labels "Made with AI", or turn the check off.
group: Sound
icon: sparkles
keywords:
  - ai generated music
  - ai badge
  - made with ai
  - slop
  - skip ai songs
  - remove ai songs
  - ai detection
  - audio ai analysis
platforms:
  - desktop
order: 100
---

# AI-generated music

Orchard flags songs that YouTube labels "Made with AI". You choose what Orchard does with a flagged song. The default is **Mark**.

## Choose what happens to AI-generated songs

1. Open **Settings**.
2. Select **Playback**.
3. In the **Queue** group, on the "When a track is AI-generated" row, select **Off**, **Mark**, **Skip**, or **Remove**.

The four choices:

- **Off**: Orchard does not check songs.
- **Mark**: Orchard puts an AI badge on the song. This is the default.
- **Skip**: Orchard marks the song and skips it when it comes up.
- **Remove**: Orchard marks the song, skips it, and removes known AI songs from the queue.

## How Orchard checks songs

Orchard reads the "Made with AI" label that YouTube shows on the playing song and on upcoming songs. YouTube adds this label when the uploader discloses AI content. A song without the label plays normally, even if it sounds AI-generated.

## Turn on audio AI analysis (deprecated)

Audio AI analysis is off by default. It is deprecated and misses newer AI music.

1. Open **Settings**.
2. Select **Playback**.
3. In the **Queue** group, turn on **Audio AI analysis (deprecated)**.

When it is on, Orchard also downloads upcoming songs at low bitrate and analyses the audio for AI-generation artifacts. It catches some fully generated songs. It does not catch AI voice covers. The switch is unavailable when the "When a track is AI-generated" row is set to **Off**.

## What the AI badge looks like

A small "AI" badge appears next to the song title in the player bar, the fullscreen player, the queue panel, and playlist song lists. Its accessible name is "Likely AI-generated". Hover the badge to see why the song was flagged:

- "YouTube labels this track "Made with AI"." for a labelled song.
- "Orchard detected AI-generation artifacts in this track" with a confidence percentage for a song flagged by audio AI analysis.

## Stop skipping flagged songs

Select **Mark** or **Off** on the "When a track is AI-generated" row in the **Queue** group. **Mark** keeps the badge and plays every song. **Off** stops all checks.
