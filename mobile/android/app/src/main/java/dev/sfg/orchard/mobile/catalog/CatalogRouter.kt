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

package dev.sfg.orchard.mobile.catalog

import dev.sfg.orchard.mobile.applemusic.AppleMusicCatalog
import dev.sfg.orchard.mobile.model.BrowseDetail
import dev.sfg.orchard.mobile.model.CatalogItem
import dev.sfg.orchard.mobile.model.CatalogKind
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.last

internal fun isAppleMusicId(id: String): Boolean = id.startsWith("am.")

/**
 * Detail pages and "See all" shelves from the catalog that owns them. A signed-in Apple Music
 * listener gets Apple's artist page in place of YouTube's when the names match exactly.
 */
internal class CatalogRouter(
    private val youtube: CatalogRepository,
    private val apple: AppleMusicCatalog,
) {
    // YouTube artist id to Apple artist id; blank records a miss.
    private val appleIds = ConcurrentHashMap<String, String>()

    fun pages(id: String, seed: CatalogItem? = null): Flow<BrowseDetail> = flow {
        if (isAppleMusicId(id)) {
            emit(apple.detail(id))
            return@flow
        }
        if (!apple.signedIn() || CatalogRepository.kindOf(id.substringBefore(":")) != CatalogKind.ARTIST) {
            emitAll(youtube.browsePages(id))
            return@flow
        }
        val name = (seed as? CatalogItem.Performer)?.artist?.name.orEmpty()
        if (name.isNotBlank()) {
            appleArtistFor(id, name)?.let { emit(it); return@flow }
            emitAll(youtube.browsePages(id))
            return@flow
        }
        // Artists opened from a track or the player arrive without a seed, so YouTube's page supplies the name.
        val page = youtube.browsePages(id).first()
        emit(appleArtistFor(id, page.title) ?: page)
    }

    suspend fun browse(id: String): BrowseDetail = pages(id).last()

    suspend fun sectionItems(browseId: String, params: String): List<CatalogItem> =
        if (isAppleMusicId(browseId)) apple.artistView(browseId, params) else youtube.sectionItems(browseId, params)

    /** Keeps the YouTube channel id so subscribing still targets the listener's YouTube library. */
    private suspend fun appleArtistFor(id: String, name: String): BrowseDetail? {
        if (name.isBlank()) return null
        return try {
            val appleId = appleIds[id] ?: apple.matchArtist(name).orEmpty().also { appleIds[id] = it }
            appleId.ifEmpty { null }?.let { apple.detail(it).copy(id = id) }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Apple being unreachable is no reason to lose the YouTube page.
            null
        }
    }
}
