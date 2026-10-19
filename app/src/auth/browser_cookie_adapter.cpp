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
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#include "browser_cookie_adapter.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QPointer>
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
#include <QQuickWebEngineProfile>
#include <QWebEngineCookieStore>
#endif
#ifdef ORCHARD_WEBVIEW2_AUTH
#include "webview2_view.h"
#endif

BrowserCookieAdapter::BrowserCookieAdapter(QObject *parent) : QObject(parent) {
  m_notify.setSingleShot(true);
  m_notify.setInterval(300);
  connect(&m_notify, &QTimer::timeout, this, &BrowserCookieAdapter::cookiesChanged);
  // WebView2 has no cookie change event.
  m_poll.setInterval(500);
  connect(&m_poll, &QTimer::timeout, this, &BrowserCookieAdapter::readWebView2Cookies);
}

bool BrowserCookieAdapter::keep(const QNetworkCookie &cookie) const {
  const QString domain = cookie.domain().toLower();
  if (domain != QStringLiteral(".youtube.com") && domain != QStringLiteral("youtube.com") &&
      domain != QStringLiteral("music.youtube.com"))
    return false;
  return cookie.path() == QStringLiteral("/") || cookie.path().isEmpty();
}

void BrowserCookieAdapter::start() {
  if (m_started)
    return;
  m_started = true;
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
  auto *profile = QQuickWebEngineProfile::defaultProfile();
  // These are the same settings used by QtWebView's WebEngine plugin.
  profile->setStorageName(QCoreApplication::applicationName());
  profile->setOffTheRecord(false);
  auto *store = profile->cookieStore();
  connect(store, &QWebEngineCookieStore::cookieAdded, this,
          [this](const QNetworkCookie &cookie) {
    if (!keep(cookie)) return;
    m_cookies.insert(cookie.name(), cookie);
    m_notify.start();
  });
  connect(store, &QWebEngineCookieStore::cookieRemoved, this,
          [this](const QNetworkCookie &cookie) {
    const auto found = m_cookies.constFind(cookie.name());
    if (found != m_cookies.cend() && found->hasSameIdentifier(cookie)
        && found->value() == cookie.value()) {
      m_cookies.remove(cookie.name());
      m_notify.start();
    }
  });
  store->loadAllCookies();
#elif defined(ORCHARD_WEBVIEW2_AUTH)
  m_poll.start();
  readWebView2Cookies();
#endif
}

void BrowserCookieAdapter::readWebView2Cookies() {
#ifdef ORCHARD_WEBVIEW2_AUTH
  // The sign-in page's view owns the default profile; read its live cookie manager.
  WebView2View *view = WebView2View::findReady(QString());
  if (!view || m_reading)
    return;
  m_reading = true;
  const QPointer<BrowserCookieAdapter> self(this);
  view->cookies(QUrl(QStringLiteral("https://music.youtube.com/")),
                [self](const QList<QNetworkCookie> &cookies) {
    if (!self)
      return;
    self->m_reading = false;
    QMap<QByteArray, QNetworkCookie> snapshot;
    for (const auto &cookie : cookies)
      if (self->keep(cookie))
        snapshot.insert(cookie.name(), cookie);
    bool same = snapshot.size() == self->m_cookies.size();
    for (auto it = snapshot.cbegin(); same && it != snapshot.cend(); ++it)
      same = self->m_cookies.value(it.key()).value() == it->value();
    if (same)
      return;
    self->m_cookies = snapshot;
    self->m_notify.start();
  });
#endif
}

QString BrowserCookieAdapter::cookies() const {
  QStringList parts;
  for (const auto &cookie : m_cookies) {
    if (!cookie.isSessionCookie() && cookie.expirationDate() <= QDateTime::currentDateTimeUtc()) continue;
    parts.append(QString::fromLatin1(cookie.toRawForm(QNetworkCookie::NameAndValueOnly)));
  }
  return parts.join(QStringLiteral("; "));
}
