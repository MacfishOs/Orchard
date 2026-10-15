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

package dev.sfg.orchard.mobile.home

import dev.sfg.orchard.mobile.model.CatalogItem
import dev.sfg.orchard.mobile.model.HomeFeed
import kotlinx.coroutines.CancellationException

/** A feed and the source that served it. [warning] is set when the preferred source was skipped. */
data class HomeFeedResult(
    val source: HomeSource,
    val feed: HomeFeed,
    val warning: String? = null,
)

/** Serves the home screen from the preferred source, falling back through the others in order. */
class HomeFeeds(
    private val sources: List<HomeSource>,
    private val preferred: () -> String,
) {
    @Volatile
    private var active: HomeSource? = null

    /** Source behind the feed on screen; "See all" goes back to it. */
    val activeSource: HomeSource? get() = active

    suspend fun load(): HomeFeedResult {
        val first = sources.firstOrNull { it.id == preferred() } ?: sources.first()
        var skipped: String? = null
        var lastError: Throwable? = null
        for (source in listOf(first) + (sources - first)) {
            if (!source.available()) {
                if (source == first) skipped = "${source.name} is not connected."
                continue
            }
            try {
                val feed = source.feed()
                active = source
                return HomeFeedResult(source, feed, skipped?.let { "$it Showing ${source.name} on Home." })
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                lastError = e
                if (source == first) skipped = "${source.name} Home could not load."
            }
        }
        throw lastError ?: IllegalStateException("No home source is available.")
    }

    suspend fun sectionItems(browseId: String, params: String): List<CatalogItem> =
        (active ?: return emptyList()).sectionItems(browseId, params)
}
