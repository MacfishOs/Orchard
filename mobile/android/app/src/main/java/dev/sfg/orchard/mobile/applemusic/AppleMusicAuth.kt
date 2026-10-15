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

import android.content.Context
import dev.sfg.orchard.mobile.security.AndroidKeystoreCipher
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

internal data class AppleMusicAuthState(val connected: Boolean = false, val error: String = "")

/** Stores the Music User Token. Apple's sign-in cookies stay in the shared WebView cookie jar. */
internal class AppleMusicAuth private constructor(context: Context) {
    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences("orchard_apple_music", Context.MODE_PRIVATE)
    private val cipher = AndroidKeystoreCipher("orchard_apple_music_user_token_v1")
    private val mutableState = MutableStateFlow(AppleMusicAuthState(connected = userToken().isNotBlank()))
    val state = mutableState.asStateFlow()

    fun userToken(): String = runCatching {
        prefs.getString(KEY_USER_TOKEN, null)?.let(cipher::decrypt)
    }.getOrNull().orEmpty()

    fun complete(userToken: String): Boolean {
        if (userToken.isBlank() || userToken.length > 16_384) {
            fail("Apple Music did not return an authorization token. Try again.")
            return false
        }
        val saved = runCatching {
            prefs.edit().putString(KEY_USER_TOKEN, cipher.encrypt(userToken)).commit()
        }.getOrDefault(false)
        if (!saved) {
            fail("Could not securely save your Apple Music connection. Try again.")
            return false
        }
        AppleMusicWebSession.flush()
        mutableState.value = AppleMusicAuthState(connected = true)
        return true
    }

    fun fail(message: String) {
        mutableState.value = mutableState.value.copy(error = message)
    }

    fun disconnect() {
        if (!prefs.edit().remove(KEY_USER_TOKEN).commit()) {
            fail("Could not remove your Apple Music connection. Try again.")
            return
        }
        AppleMusicWebSession.clear()
        mutableState.value = AppleMusicAuthState()
    }

    companion object {
        private const val KEY_USER_TOKEN = "user_token"

        @Volatile private var instance: AppleMusicAuth? = null

        fun get(context: Context): AppleMusicAuth = instance ?: synchronized(this) {
            instance ?: AppleMusicAuth(context).also { instance = it }
        }
    }
}
