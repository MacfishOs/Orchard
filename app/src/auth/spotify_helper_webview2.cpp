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
#include "webview2_item.h"
#include "webview2_view.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QJsonObject>
#include <QNetworkCookie>
#include <QQuickItem>
#include <QQuickView>
#include <QTimer>

using namespace spotify_page;

namespace {

const QList<QUrl> &spotifyOrigins() {
  static const QList<QUrl> origins{QUrl(QStringLiteral("https://accounts.spotify.com/")),
                                   QUrl(QStringLiteral("https://open.spotify.com/")),
                                   QUrl(QStringLiteral("https://www.spotify.com/"))};
  return origins;
}

// The keychain keeps sp_dc; the shared browser profile forgets Spotify.
void forgetSpotify(WebView2View *view, std::function<void()> done) {
  auto remaining = std::make_shared<int>(spotifyOrigins().size());
  for (const QUrl &origin : spotifyOrigins())
    view->deleteCookies(origin, [remaining, done] {
      if (--*remaining == 0)
        done();
    });
}

} // namespace

int runSpotifyLogin(const QString &socketName) {
  QQuickView view;
  view.setResizeMode(QQuickView::SizeRootObjectToView);
  view.resize(600, 760);
  view.setTitle(QObject::tr("Log in to Spotify"));
  view.setSource(QUrl(QStringLiteral("qrc:/auth/SpotifyLoginView.qml")));
  if (view.status() == QQuickView::Error || !view.rootObject())
    return 1;
  QObject::connect(view.rootObject(), SIGNAL(closeRequested()), qApp, SLOT(quit()));
  auto *item = view.rootObject()->findChild<WebView2Item *>();
  if (!item)
    return 1;

  // WebView2 has no cookie change event; poll for sp_dc while the page is open.
  bool sent = false;
  bool reading = false;
  QTimer poll;
  poll.setInterval(500);
  QObject::connect(&poll, &QTimer::timeout, qApp, [item, &sent, &reading, &poll, &view, socketName] {
    WebView2View *web = item->webView();
    if (sent || reading || !web || !web->isReady())
      return;
    reading = true;
    web->cookies(QUrl(QStringLiteral("https://open.spotify.com/")),
                 [web, &sent, &reading, &poll, &view, socketName](const QList<QNetworkCookie> &cookies) {
      reading = false;
      for (const auto &cookie : cookies) {
        if (sent || cookie.name() != "sp_dc" || cookie.value().isEmpty())
          continue;
        sent = true;
        poll.stop();
        view.hide();
        const QString spdc = QString::fromLatin1(cookie.value());
        forgetSpotify(web, [socketName, spdc] {
          sendSessionAndQuit(socketName, {{QStringLiteral("spdc"), spdc}});
        });
      }
    });
  });
  poll.start();
  view.show();
  return QCoreApplication::exec();
}

int runSpotifyToken(const QString &socketName) {
  const QString spdc = readCookie();
  if (spdc.isEmpty())
    return 1;
  WebView2HiddenHost host;
  WebView2View::Options options;
  // InPrivate: each harvest starts from the stored cookie and leaves nothing behind.
  options.inPrivate = true;
  options.userAgent = QString::fromLatin1(kBrowserUserAgent);
  options.startupScripts = {QString::fromLatin1(kTokenHook)};
  WebView2View page(options);
  QObject::connect(&page, &WebView2View::failed, qApp, [] { QCoreApplication::exit(3); });

  QNetworkCookie cookie("sp_dc", spdc.toLatin1());
  cookie.setDomain(QStringLiteral(".spotify.com"));
  cookie.setPath(QStringLiteral("/"));
  cookie.setSecure(true);
  cookie.setHttpOnly(true);
  cookie.setExpirationDate(QDateTime::currentDateTimeUtc().addYears(1));
  page.setCookie(cookie);
  page.navigate(QUrl(QStringLiteral("https://open.spotify.com/")));
  page.setBounds(QRect(0, 0, 1280, 800));
  page.create(host.winId());

  bool sent = false;
  QTimer poll;
  poll.setInterval(400);
  QObject::connect(&poll, &QTimer::timeout, qApp, [&page, &sent, &poll, socketName] {
    if (!page.isReady())
      return;
    page.runJavaScript(QString::fromLatin1(kTokenRead), [&sent, &poll, socketName](const QJsonValue &value) {
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
                       [](const QJsonValue &seen) {
      qInfo().noquote() << "Spotify token response:" << seen.toString();
      QCoreApplication::exit(3);
    });
  });
  return QCoreApplication::exec();
}
