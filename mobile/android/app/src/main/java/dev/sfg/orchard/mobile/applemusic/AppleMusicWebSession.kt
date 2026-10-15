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

import android.annotation.SuppressLint
import android.content.Context
import android.os.Message
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebStorage
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.webkit.WebViewAssetLoader
import androidx.webkit.WebViewClientCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject

/** Apple Music web session shared by every WebView in the app process. */
internal object AppleMusicWebSession {
    const val PAGE_ORIGIN = "https://appassets.androidplatform.net"
    const val PAGE_URL = "$PAGE_ORIGIN/assets/applemusic/signin.html"

    private val cookieUrls = listOf(
        "https://apple.com",
        "https://www.apple.com",
        "https://music.apple.com",
        "https://authorize.music.apple.com",
        "https://idmsa.apple.com",
        "https://appleid.apple.com",
        "https://account.apple.com",
        "https://play.itunes.apple.com",
        "https://buy.itunes.apple.com",
    )

    val supported: Boolean get() = WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)

    fun flush() = CookieManager.getInstance().flush()

    /** Expires Apple's cookies and the page's MusicKit storage; other services keep their sessions. */
    fun clear() {
        val cookies = CookieManager.getInstance()
        for (url in cookieUrls) {
            val names = cookies.getCookie(url).orEmpty().split(';')
                .map { it.substringBefore('=').trim() }.filter { it.isNotEmpty() }
            for (name in names) {
                cookies.setCookie(url, "$name=; Max-Age=0; Path=/")
                cookies.setCookie(url, "$name=; Max-Age=0; Path=/; Domain=.apple.com")
            }
        }
        cookies.flush()
        WebStorage.getInstance().deleteOrigin(PAGE_ORIGIN)
    }
}

/**
 * Sign-in page plus the popups MusicKit opens. Lives only while the sign-in screen is shown;
 * [destroy] releases every WebView.
 */
@SuppressLint("SetJavaScriptEnabled")
internal class AppleMusicSignInWindows(
    context: Context,
    private val onMessage: (JSONObject) -> Unit,
) {
    val root = FrameLayout(context)
    private val windows = mutableListOf<WebView>()
    private val assets = WebViewAssetLoader.Builder()
        .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
        .build()

    private val client = object : WebViewClientCompat() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            assets.shouldInterceptRequest(request.url)
    }

    private val chrome = object : WebChromeClient() {
        override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
            val popup = open()
            (resultMsg.obj as WebView.WebViewTransport).webView = popup
            resultMsg.sendToTarget()
            return true
        }

        override fun onCloseWindow(window: WebView) = close(window)
    }

    init {
        val page = open()
        WebViewCompat.addWebMessageListener(page, "orchardAppleMusic", setOf(AppleMusicWebSession.PAGE_ORIGIN)) {
                _, message, _, isMainFrame, _ ->
            if (isMainFrame) message.data?.let { runCatching { JSONObject(it) }.getOrNull() }?.let(onMessage)
        }
    }

    /** JWTs are URL-safe, and the fragment never leaves the device. */
    fun load(developerToken: String) = windows.first().loadUrl("${AppleMusicWebSession.PAGE_URL}#$developerToken")

    fun reload() = windows.first().reload()

    /** Steps back within the top window, then closes popups. False once only the page is left. */
    fun back(): Boolean {
        val top = windows.lastOrNull() ?: return false
        when {
            top.canGoBack() -> top.goBack()
            windows.size > 1 -> close(top)
            else -> return false
        }
        return true
    }

    fun destroy() {
        AppleMusicWebSession.flush()
        windows.asReversed().forEach { root.removeView(it); it.destroy() }
        windows.clear()
    }

    private fun open(): WebView = WebView(root.context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.setSupportMultipleWindows(true)
        // Apple's idmsa sign-in frame is third party inside the authorize popup.
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webViewClient = client
        webChromeClient = chrome
        layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        windows += this
        root.addView(this)
    }

    private fun close(window: WebView) {
        if (window === windows.firstOrNull() || !windows.remove(window)) return
        root.removeView(window)
        window.destroy()
    }
}
