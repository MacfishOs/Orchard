/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

package dev.sfg.orchard.mobile.settings

import dev.sfg.orchard.mobile.model.LyricsProvider
import dev.sfg.orchard.mobile.model.LyricsProviderConfig
import dev.sfg.orchard.mobile.model.normalizeLyricsProviders
import org.json.JSONArray
import org.json.JSONObject

internal fun decodeLyricsProviders(value: String?): List<LyricsProviderConfig> {
    val saved = runCatching {
        val array = JSONArray(value.orEmpty())
        buildList {
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val provider = LyricsProvider.entries.firstOrNull { it.key == item.optString("provider") } ?: continue
                add(LyricsProviderConfig(provider, item.optBoolean("enabled", true)))
            }
        }
    }.getOrDefault(emptyList())
    return normalizeLyricsProviders(saved)
}

internal fun encodeLyricsProviders(values: List<LyricsProviderConfig>): String = JSONArray().apply {
    normalizeLyricsProviders(values).forEach { item ->
        put(JSONObject().put("provider", item.provider.key).put("enabled", item.enabled))
    }
}.toString()
