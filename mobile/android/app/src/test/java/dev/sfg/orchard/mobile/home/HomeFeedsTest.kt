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
import dev.sfg.orchard.mobile.model.CatalogSection
import dev.sfg.orchard.mobile.model.HomeFeed
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class HomeFeedsTest {
    private class FakeSource(
        override val id: String,
        override val name: String,
        private val connected: Boolean = true,
        private val failure: Exception? = null,
    ) : HomeSource {
        val seeAll = mutableListOf<String>()
        override fun available() = connected
        override suspend fun feed(): HomeFeed {
            failure?.let { throw it }
            return HomeFeed(sections = listOf(CatalogSection(id, name, emptyList())))
        }
        override suspend fun sectionItems(browseId: String, params: String): List<CatalogItem> {
            seeAll += browseId
            return emptyList()
        }
    }

    @Test
    fun preferredSourceServesWithoutWarning() = runBlocking {
        val apple = FakeSource("apple_music", "Apple Music")
        val result = HomeFeeds(listOf(FakeSource("youtube", "YouTube Music"), apple)) { "apple_music" }.load()
        assertEquals("apple_music", result.source.id)
        assertNull(result.warning)
    }

    @Test
    fun disconnectedPreferredFallsBackWithWarning() = runBlocking {
        val youtube = FakeSource("youtube", "YouTube Music")
        val feeds = HomeFeeds(listOf(youtube, FakeSource("apple_music", "Apple Music", connected = false))) { "apple_music" }
        val result = feeds.load()
        assertEquals("youtube", result.source.id)
        assertEquals("Apple Music is not connected. Showing YouTube Music on Home.", result.warning)
        feeds.sectionItems("shelf", "")
        assertEquals(listOf("shelf"), youtube.seeAll)
    }

    @Test
    fun failedPreferredFallsBackWithWarning() = runBlocking {
        val sources = listOf(
            FakeSource("youtube", "YouTube Music"),
            FakeSource("apple_music", "Apple Music", failure = IllegalStateException("down")),
        )
        val result = HomeFeeds(sources) { "apple_music" }.load()
        assertEquals("youtube", result.source.id)
        assertEquals("Apple Music Home could not load. Showing YouTube Music on Home.", result.warning)
    }

    @Test
    fun allSourcesFailingRethrowsLastError() {
        val sources = listOf(FakeSource("youtube", "YouTube Music", failure = IllegalStateException("offline")))
        val error = assertThrows(IllegalStateException::class.java) { runBlocking { HomeFeeds(sources) { "youtube" }.load() } }
        assertEquals("offline", error.message)
    }
}
