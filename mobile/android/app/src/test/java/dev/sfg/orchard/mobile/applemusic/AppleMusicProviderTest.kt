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

import dev.sfg.orchard.mobile.provider.ProviderBundle
import dev.sfg.orchard.mobile.provider.ProviderException
import dev.sfg.orchard.mobile.provider.ProviderHost
import java.io.File
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class AppleMusicProviderTest {
    private val assets = File(checkNotNull(System.getProperty("orchard.providerAssets")))
    private val provider = ProviderHost(OkHttpClient(), ProviderBundle.AppleMusic) { name ->
        File(assets, name).takeIf(File::isFile)?.readBytes()
    }

    @Test fun `shared bytecode answers through the native host`() = runBlocking {
        assertEquals(false, provider.invoke("session.set").getBoolean("connected"))
        val error = provider.invoke("catalog.artist", JSONObject().put("browseId", "am.artists.1")).getJSONObject("error")
        assertEquals("not_connected", error.getString("code"))
        assertEquals("not_connected", provider.invoke("catalog.home").getJSONObject("error").getString("code"))
        assertEquals(true, provider.invoke("session.set", JSONObject().put("developerToken", "dev")).getBoolean("connected"))
        val badId = provider.invoke("catalog.artist", JSONObject().put("browseId", "UCabc")).getJSONObject("error")
        assertEquals("bad_id", badId.getString("code"))
    }

    @Test fun `unknown methods reject`() = runBlocking {
        try {
            provider.invoke("missing.method")
            fail()
        } catch (error: ProviderException) {
            assertTrue(error.message.orEmpty().contains("Unknown Apple Music provider method"))
        }
    }
}
