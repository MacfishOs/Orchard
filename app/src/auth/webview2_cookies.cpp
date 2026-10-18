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

#include "webview2_native.h"

#include <QDateTime>
#include <QPointer>
#include <QTimeZone>

using webview2::take;
using webview2::wide;

namespace {

QNetworkCookie toQt(ICoreWebView2Cookie *item) {
  LPWSTR text = nullptr;
  item->get_Name(&text);
  const QByteArray name = take(text).toUtf8();
  text = nullptr;
  item->get_Value(&text);
  QNetworkCookie cookie(name, take(text).toUtf8());
  text = nullptr;
  item->get_Domain(&text);
  cookie.setDomain(take(text).toLower());
  text = nullptr;
  item->get_Path(&text);
  cookie.setPath(take(text));
  BOOL flag = FALSE;
  if (SUCCEEDED(item->get_IsSecure(&flag)))
    cookie.setSecure(flag);
  if (SUCCEEDED(item->get_IsHttpOnly(&flag)))
    cookie.setHttpOnly(flag);
  double expires = 0;
  if (SUCCEEDED(item->get_IsSession(&flag)) && !flag && SUCCEEDED(item->get_Expires(&expires)))
    cookie.setExpirationDate(
        QDateTime::fromMSecsSinceEpoch(static_cast<qint64>(expires * 1000), QTimeZone::UTC));
  return cookie;
}

} // namespace

void WebView2View::cookies(const QUrl &url, std::function<void(const QList<QNetworkCookie> &)> done) {
  whenReady([this, url, done = std::move(done)] {
    const HRESULT status = m_native->cookies->GetCookies(
        wide(url.toString(QUrl::FullyEncoded)),
        Callback<ICoreWebView2GetCookiesCompletedHandler>(
            [done](HRESULT result, ICoreWebView2CookieList *list) -> HRESULT {
              QList<QNetworkCookie> cookies;
              UINT count = 0;
              if (SUCCEEDED(result) && list && SUCCEEDED(list->get_Count(&count))) {
                for (UINT index = 0; index < count; ++index) {
                  ComPtr<ICoreWebView2Cookie> item;
                  if (SUCCEEDED(list->GetValueAtIndex(index, &item)) && item)
                    cookies.append(toQt(item.Get()));
                }
              }
              done(cookies);
              return S_OK;
            })
            .Get());
    if (FAILED(status))
      done({});
  });
}

void WebView2View::setCookie(const QNetworkCookie &cookie) {
  whenReady([this, cookie] {
    ComPtr<ICoreWebView2Cookie> item;
    if (FAILED(m_native->cookies->CreateCookie(wide(QString::fromUtf8(cookie.name())),
                                               wide(QString::fromUtf8(cookie.value())),
                                               wide(cookie.domain()), wide(cookie.path()), &item)))
      return;
    if (!cookie.isSessionCookie())
      item->put_Expires(static_cast<double>(cookie.expirationDate().toSecsSinceEpoch()));
    item->put_IsSecure(cookie.isSecure());
    item->put_IsHttpOnly(cookie.isHttpOnly());
    m_native->cookies->AddOrUpdateCookie(item.Get());
  });
}

void WebView2View::deleteCookies(const QUrl &url, std::function<void()> done) {
  const QPointer<WebView2View> self(this);
  whenReady([this, self, url, done = std::move(done)] {
    const HRESULT status = m_native->cookies->GetCookies(
        wide(url.toString(QUrl::FullyEncoded)),
        Callback<ICoreWebView2GetCookiesCompletedHandler>(
            [self, done](HRESULT result, ICoreWebView2CookieList *list) -> HRESULT {
              if (!self)
                return S_OK;
              UINT count = 0;
              if (SUCCEEDED(result) && list && SUCCEEDED(list->get_Count(&count))) {
                for (UINT index = 0; index < count; ++index) {
                  ComPtr<ICoreWebView2Cookie> item;
                  if (SUCCEEDED(list->GetValueAtIndex(index, &item)) && item)
                    self->m_native->cookies->DeleteCookie(item.Get());
                }
              }
              if (done)
                done();
              return S_OK;
            })
            .Get());
    if (FAILED(status) && done)
      done();
  });
}

void WebView2View::clearProfileData(std::function<void(bool)> done) {
  if (m_failed) {
    done(false);
    return;
  }
  whenReady([this, done = std::move(done)] {
    ComPtr<ICoreWebView2_13> withProfile;
    ComPtr<ICoreWebView2Profile> profile;
    ComPtr<ICoreWebView2Profile2> clearing;
    if (FAILED(m_native->webview.As(&withProfile)) || FAILED(withProfile->get_Profile(&profile)) ||
        FAILED(profile.As(&clearing))) {
      done(false);
      return;
    }
    const HRESULT status = clearing->ClearBrowsingDataAll(
        Callback<ICoreWebView2ClearBrowsingDataCompletedHandler>([done](HRESULT result) -> HRESULT {
          done(SUCCEEDED(result));
          return S_OK;
        }).Get());
    if (FAILED(status))
      done(false);
  });
}
