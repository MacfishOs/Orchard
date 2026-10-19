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

#include "spotify_helper.h"
#include "auth_session_channel.h"
#include "spotify_page.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QJsonObject>
#include <QTimer>

#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
#include <QNetworkCookie>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickView>
#include <QQuickWebEngineProfile>
#include <QWebEngineCookieStore>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineScriptCollection>
#endif

using namespace spotify_page;

#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
namespace {

bool isSpotifyCookie(const QNetworkCookie &cookie) {
  const QString domain = cookie.domain().toLower();
  return domain == QStringLiteral("spotify.com") || domain.endsWith(QStringLiteral(".spotify.com"));
}

} // namespace
#endif

int runSpotifyLogin(const QString &socketName) {
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
  // QtWebView's WebEngine backend owns this profile; match its settings.
  auto *profile = QQuickWebEngineProfile::defaultProfile();
  profile->setStorageName(QCoreApplication::applicationName());
  profile->setOffTheRecord(false);
  auto *store = profile->cookieStore();

  QQuickView view;
  view.setResizeMode(QQuickView::SizeRootObjectToView);
  view.resize(600, 760);
  view.setTitle(QObject::tr("Log in to Spotify"));
  view.setSource(QUrl(QStringLiteral("qrc:/auth/SpotifyLoginView.qml")));
  if (view.status() == QQuickView::Error || !view.rootObject())
    return 1;
  QObject::connect(view.rootObject(), SIGNAL(closeRequested()), qApp, SLOT(quit()));

  bool sent = false;
  QObject::connect(store, &QWebEngineCookieStore::cookieAdded, qApp,
                   [store, socketName, &sent, &view](const QNetworkCookie &cookie) {
    if (sent || cookie.name() != "sp_dc" || !isSpotifyCookie(cookie) || cookie.value().isEmpty())
      return;
    sent = true;
    view.hide();
    // The keychain keeps sp_dc; the shared browser profile forgets Spotify.
    QObject::connect(store, &QWebEngineCookieStore::cookieAdded, qApp,
                     [store](const QNetworkCookie &other) {
      if (isSpotifyCookie(other))
        store->deleteCookie(other);
    });
    store->deleteCookie(cookie);
    store->loadAllCookies();
    sendSessionAndQuit(socketName, {{QStringLiteral("spdc"), QString::fromLatin1(cookie.value())}});
  });
  store->loadAllCookies();
  view.show();
  return QCoreApplication::exec();
#else
  Q_UNUSED(socketName);
  return 2;
#endif
}

int runSpotifyToken(const QString &socketName) {
  const QString spdc = spotify_page::readCookie();
  if (spdc.isEmpty())
    return 1;
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
  // Off the record: each harvest starts from the stored cookie and leaves nothing behind.
  QWebEngineProfile profile;
  profile.setHttpUserAgent(QString::fromLatin1(kBrowserUserAgent));
  QWebEnginePage page(&profile);
  QWebEngineScript hook;
  hook.setName(QStringLiteral("orchard-spotify-token"));
  hook.setSourceCode(QString::fromLatin1(kTokenHook));
  hook.setInjectionPoint(QWebEngineScript::DocumentCreation);
  hook.setWorldId(QWebEngineScript::MainWorld);
  hook.setRunsOnSubFrames(false);
  page.scripts().insert(hook);

  QNetworkCookie cookie("sp_dc", spdc.toLatin1());
  cookie.setDomain(QStringLiteral(".spotify.com"));
  cookie.setPath(QStringLiteral("/"));
  cookie.setSecure(true);
  cookie.setHttpOnly(true);
  cookie.setExpirationDate(QDateTime::currentDateTimeUtc().addYears(1));
  bool loading = false;
  const auto load = [&page, &loading] {
    if (loading)
      return;
    loading = true;
    page.load(QUrl(QStringLiteral("https://open.spotify.com/")));
  };
  QObject::connect(profile.cookieStore(), &QWebEngineCookieStore::cookieAdded, qApp,
                   [load](const QNetworkCookie &added) {
    if (added.name() == "sp_dc")
      load();
  });
  profile.cookieStore()->setCookie(cookie, QUrl(QStringLiteral("https://open.spotify.com")));
  QTimer::singleShot(1000, qApp, load);

  bool sent = false;
  QTimer poll;
  poll.setInterval(400);
  QObject::connect(&poll, &QTimer::timeout, qApp, [&page, &sent, &poll, socketName] {
    page.runJavaScript(QString::fromLatin1(kTokenRead), [&sent, &poll, socketName](const QVariant &value) {
      const QJsonObject token = QJsonDocument::fromJson(value.toString().toUtf8()).object();
      if (sent || token.value(QStringLiteral("accessToken")).toString().isEmpty())
        return;
      sent = true;
      poll.stop();
      sendSessionAndQuit(socketName, token);
    });
  });
  poll.start();
  // No token in time: exit quietly and let the parent try again later.
  QTimer::singleShot(kTokenTimeoutMs, qApp, [&page] {
    if (!qEnvironmentVariableIsSet("ORCHARD_SPOTIFY_DEBUG")) {
      QCoreApplication::exit(3);
      return;
    }
    // Tells a dead cookie (anonymous token) apart from a player that never asked.
    page.runJavaScript(QStringLiteral("String(window.__orchardSpotifyTokenSeen || 'none')"),
                       [](const QVariant &seen) {
      qInfo().noquote() << "Spotify token response:" << seen.toString();
      QCoreApplication::exit(3);
    });
  });
  return QCoreApplication::exec();
#else
  Q_UNUSED(socketName);
  return 2;
#endif
}
