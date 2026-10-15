/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

package dev.sfg.orchard.mobile.applemusic

import dev.sfg.orchard.mobile.catalog.CatalogRepository
import dev.sfg.orchard.mobile.model.APPLE_MUSIC_SOURCE
import dev.sfg.orchard.mobile.model.Track
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlin.math.abs

/** Apple Music songs play through their YouTube Music match until Apple Music playback exists. */
internal class AppleMusicMatches(private val youtube: CatalogRepository) {
    private val cache = HashMap<String, Track>()

    /** [tracks] with Apple songs swapped for YouTube matches; unmatched songs are dropped. */
    suspend fun playable(tracks: List<Track>): List<Track> {
        if (tracks.none { it.playbackSource == APPLE_MUSIC_SOURCE }) return tracks
        val permits = Semaphore(MAX_PARALLEL)
        return coroutineScope {
            tracks.map { track ->
                async {
                    if (track.playbackSource != APPLE_MUSIC_SOURCE) track
                    else permits.withPermit { match(track) }
                }
            }.awaitAll().filterNotNull()
        }
    }

    private suspend fun match(track: Track): Track? {
        synchronized(cache) { cache[track.id] }?.let { return it }
        val candidates = try {
            youtube.search("${track.title} ${track.artist}", filter = "songs").tracks.take(CANDIDATES)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            return null
        }
        // The closest duration among the top results; YouTube ranks the right song first most of the time.
        val best = candidates.minByOrNull { candidate ->
            if (track.durationMs <= 0 || candidate.durationMs <= 0) 0L else abs(candidate.durationMs - track.durationMs)
        }?.takeIf { track.durationMs <= 0 || it.durationMs <= 0 || abs(it.durationMs - track.durationMs) <= MAX_DRIFT_MS }
            ?: candidates.firstOrNull()
            ?: return null
        val matched = best.copy(artworkUrl = track.artworkUrl.ifEmpty { best.artworkUrl })
        synchronized(cache) { cache[track.id] = matched }
        return matched
    }

    private companion object {
        const val MAX_PARALLEL = 4
        const val CANDIDATES = 3
        const val MAX_DRIFT_MS = 5_000L
    }
}
