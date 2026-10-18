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

#pragma once

// Internal to the webview2_*.cpp files.

#include "webview2_view.h"

#include <windows.h>
#include <WebView2.h>
#include <wrl.h>

#include <functional>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

struct WebView2View::Native {
  ComPtr<ICoreWebView2Environment> environment;
  ComPtr<ICoreWebView2Controller> controller;
  ComPtr<ICoreWebView2> webview;
  ComPtr<ICoreWebView2CookieManager> cookies;
  QString filteredOrigin;
};

namespace webview2 {

inline LPCWSTR wide(const QString &text) { return reinterpret_cast<LPCWSTR>(text.utf16()); }

// Frees text with CoTaskMemFree.
inline QString take(LPWSTR text) {
  const QString value = text ? QString::fromWCharArray(text) : QString();
  CoTaskMemFree(text);
  return value;
}

using EnvironmentReady = std::function<void(ICoreWebView2Environment *, HRESULT)>;
// One environment per process: WebView2 rejects differing options on a shared folder.
void withEnvironment(EnvironmentReady ready);

} // namespace webview2
