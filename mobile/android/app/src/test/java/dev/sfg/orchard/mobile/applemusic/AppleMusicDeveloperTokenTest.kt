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

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppleMusicDeveloperTokenTest {
    private val now = 1_792_022_400L

    private fun body(token: String = "header.payload.signature", expiry: Long = now + 3600): String =
        JSONObject().put("developer_token", token).put("expires_at", expiry).toString()

    @Test fun acceptsWorkerTokenAndExpiry() {
        val token = parseAppleMusicDeveloperToken(body(), now)
        assertEquals("header.payload.signature", token.value)
        assertEquals(now + 3600, token.expiresAt)
    }

    @Test fun rejectsExpiredAndNearlyExpiredTokens() {
        for (expiry in listOf(now - 1, now, now + 60, now + 15_777_001)) {
            assertTrue(runCatching { parseAppleMusicDeveloperToken(body(expiry = expiry), now) }.isFailure)
        }
    }

    @Test fun rejectsMalformedAndMissingTokens() {
        for (token in listOf("", " ", "..", "one..three", "no-jwt", "one.two", "one.two.three.four", "a".repeat(16_385))) {
            assertTrue(runCatching { parseAppleMusicDeveloperToken(body(token), now) }.isFailure)
        }
        for (json in listOf("{}", "not-json", "{\"developer_token\":\"a.b.c\"}")) {
            assertTrue(runCatching { parseAppleMusicDeveloperToken(json, now) }.isFailure)
        }
    }
}
