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

import dev.sfg.orchard.mobile.model.Artist
import dev.sfg.orchard.mobile.model.BrowseDetail
import dev.sfg.orchard.mobile.model.CatalogItem
import dev.sfg.orchard.mobile.model.CatalogKind
import dev.sfg.orchard.mobile.model.SearchResults
import dev.sfg.orchard.mobile.model.Track
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CatalogRouterTest {
    private class FakeSource(val id: String) : CatalogRouter.Source {
        val calls = mutableListOf<String>()
        var failure: Exception? = null
        override suspend fun search(query: String): SearchResults {
            calls += "search:$query"
            failure?.let { throw it }
            return SearchResults(tracks = listOf(Track("$id.song", query, "Artist", playbackSource = id)))
        }
        override fun pages(id: String) = flowOf(BrowseDetail(id, CatalogKind.ARTIST, "Artist")).also {
            calls += "pages:$id"
        }
        override suspend fun sectionItems(id: String, params: String): List<CatalogItem> {
            calls += "section:$id:$params"
            return emptyList()
        }
        override suspend fun artist(name: String): BrowseDetail? {
            calls += "artist:$name"
            failure?.let { throw it }
            return BrowseDetail("am.artists.123", CatalogKind.ARTIST, name)
        }
    }

    @Test
    fun searchFollowsCatalogChangesAndPreservesAppleIdentity() = runBlocking {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music")
        var selected = "apple_music"
        val router = CatalogRouter(youtube, apple) { selected }
        assertEquals("apple_music", router.search("Song").tracks.single().playbackSource)
        assertTrue(youtube.calls.isEmpty())
        selected = "youtube"
        assertEquals("youtube", router.search("Song").tracks.single().playbackSource)
        assertEquals(listOf("search:Song"), youtube.calls)
    }

    @Test
    fun appleFailureNeverSearchesYouTube() {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music").apply { failure = IllegalStateException("Disconnected") }
        val router = CatalogRouter(youtube, apple) { "apple_music" }
        val error = assertThrows(IllegalStateException::class.java) { runBlocking { router.search("Song") } }
        assertEquals("Disconnected", error.message)
        assertTrue(youtube.calls.isEmpty())
    }

    @Test
    fun youtubeModeKeepsYouTubeArtistPagesEvenWhenAppleIsConnected() = runBlocking {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music")
        val router = CatalogRouter(youtube, apple) { "youtube" }
        assertEquals("UCartist", router.pages("UCartist").toList().single().id)
        assertTrue(apple.calls.isEmpty())
    }

    @Test
    fun appleModeResolvesTrackArtistLinksToAppleAndKeepsAppleIdentity() = runBlocking {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music")
        val router = CatalogRouter(youtube, apple) { "apple_music" }
        val seed = CatalogItem.Performer(Artist("UCartist", "Artist"))
        assertEquals("am.artists.123", router.pages("UCartist", seed).toList().single().id)
        assertTrue(youtube.calls.isEmpty())
        assertEquals(listOf("artist:Artist"), apple.calls)
    }

    @Test
    fun mismatchedCollectionRequiresChangingCatalog() {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music")
        val router = CatalogRouter(youtube, apple) { "apple_music" }
        assertThrows(IllegalStateException::class.java) { runBlocking { router.pages("MPREalbum").toList() } }
        assertTrue(youtube.calls.isEmpty())
        assertTrue(apple.calls.isEmpty())
    }

    @Test
    fun sectionsUseApplePaginationWithoutLosingTheirView() = runBlocking {
        val youtube = FakeSource("youtube")
        val apple = FakeSource("apple_music")
        val router = CatalogRouter(youtube, apple) { "apple_music" }
        router.sectionItems("am.artists.123", "view:live-albums")
        assertEquals(listOf("section:am.artists.123:view:live-albums"), apple.calls)
        assertTrue(youtube.calls.isEmpty())
    }
}
