/* Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
package dev.sfg.orchard.mobile.lyrics.translation

import dev.sfg.orchard.mobile.auth.OrchardAccountService
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject

/** The whole song is one admission; the Worker owns batching, cache, model, and limits. */
internal class AccountLyricTranslation(http: OkHttpClient, private val account: OrchardAccountService) {
    private val client = http.newBuilder().followRedirects(false).followSslRedirects(false)
        .callTimeout(130, TimeUnit.SECONDS).readTimeout(130, TimeUnit.SECONDS).build()

    suspend fun translate(songId: String, lines: List<String>): List<String> {
        check(account.state.value.signedIn) { "Sign in to Orchard to translate lyrics." }
        require(songId.isNotBlank()) { "This song has no ID." }
        val token = account.accessToken() ?: error("Sign in to Orchard again.")
        val payload = JSONObject().put("song_id", songId).put("lines", JSONArray(lines))
        val request = Request.Builder().url("${account.serviceUrl}/lyrics/translate")
            .header("Authorization", "Bearer $token")
            .post(payload.toString().toRequestBody("application/json".toMediaType())).build()
        val body = suspendCancellableCoroutine<String> { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(IOException(if (e is java.io.InterruptedIOException)
                        "Translation took too long. Try again." else "Account translation network error."))
                }
                override fun onResponse(call: Call, response: Response) {
                    response.use {
                        if (!continuation.isActive) return
                        if (!it.isSuccessful) {
                            val code = runCatching { JSONObject(it.body.string()).optString("error") }.getOrDefault("")
                            val message = when {
                                code == "translation_busy" -> "Translation is busy. Try again shortly."
                                code == "translation_invalid_result" -> "The model returned invalid lyric lines. Try again."
                                it.code == 504 -> "Translation took too long. Try again."
                                it.code == 429 -> "The account or IP has reached 10 songs today. Resets at 00:00 UTC."
                                it.code == 409 -> "This song is being translated. Try again shortly."
                                it.code == 401 -> "Sign in to Orchard again."
                                else -> "Account translation failed. Try again later."
                            }
                            continuation.resumeWithException(IOException(message))
                        } else {
                            runCatching { it.body.string() }
                                .onSuccess { body -> continuation.resume(body) }
                                .onFailure { continuation.resumeWithException(IOException("Could not read account translation.")) }
                        }
                    }
                }
            })
        }
        return parseAccountLines(body, lines.size) ?: error("The translation returned an invalid number of lines.")
    }
}

internal fun parseAccountLines(body: String, count: Int): List<String>? {
    val lines = runCatching { JSONObject(body).getJSONArray("lines") }.getOrNull() ?: return null
    if (lines.length() != count) return null
    return (0 until count).map { index ->
        (lines.opt(index) as? String)?.trim()?.takeIf(String::isNotEmpty) ?: return null
    }
}
