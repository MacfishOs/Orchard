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

#include "apple_music_helper.h"
#include "auth_session_channel.h"

#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <QUrl>

#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickView>
#include <QQuickWebEngineProfile>
#include <QWebEngineCookieStore>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#endif

namespace {

// The developer token's origin claim names this origin; Android serves the same page from it.
constexpr auto kPageOrigin = "https://appassets.androidplatform.net";
constexpr auto kPageUrl = "https://appassets.androidplatform.net/assets/applemusic/signin.html";
constexpr auto kProfileName = "AppleMusic";

void sendAndQuit(const QString &socketName, const QJsonObject &result) {
  auto *client = new AuthSessionClient(qApp);
  QObject::connect(client, &AuthSessionClient::finished, qApp,
                   [](bool accepted) { QCoreApplication::exit(accepted ? 0 : 1); });
  client->send(socketName, result);
}

#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
// Apple's sign-in widget awaits getClientCapabilities(), which never settles in Qt WebEngine.
constexpr auto kCapabilitiesShim = R"JS(
(() => {
  const credential = window.PublicKeyCredential;
  if (!credential || typeof credential.getClientCapabilities !== 'function') return;
  const original = credential.getClientCapabilities.bind(credential);
  credential.getClientCapabilities = () => Promise.race([
    original(),
    new Promise((resolve) => setTimeout(() => resolve({}), 1500))
  ]);
})();
)JS";

// The shared page posts to window.orchardAppleMusic; the helper polls what it posted.
// Apple's popup pages share the profile, so the bridge only arms on Orchard's origin.
constexpr auto kBridge = R"JS(
(() => {
  if (location.origin !== %1) return;
  window.orchardDeveloperToken = %2;
  window.orchardAppleMusic = {
    postMessage: (message) => { window.__orchardAppleMusicMessage = String(message); }
  };
})();
)JS";

QString jsString(const QString &value) {
  return QString::fromUtf8(QJsonDocument(QJsonArray{value}).toJson(QJsonDocument::Compact)).mid(1).chopped(1);
}

QWebEngineScript userScript(const QString &name, const QString &source, bool subFrames) {
  QWebEngineScript script;
  script.setName(name);
  script.setSourceCode(source);
  script.setInjectionPoint(QWebEngineScript::DocumentCreation);
  script.setWorldId(QWebEngineScript::MainWorld);
  script.setRunsOnSubFrames(subFrames);
  return script;
}

QString signInHtml() {
  QFile page(QStringLiteral(":/auth/applemusic-signin.html"));
  return page.open(QIODevice::ReadOnly) ? QString::fromUtf8(page.readAll()) : QString();
}
#endif

QString readDeveloperToken() {
  QFile input;
  if (!input.open(stdin, QIODevice::ReadOnly))
    return {};
  return QJsonDocument::fromJson(input.readLine(32 * 1024)).object().value(QStringLiteral("developerToken")).toString();
}

} // namespace

int runAppleMusicLogin(const QString &socketName) {
  const QString developerToken = readDeveloperToken();
  if (developerToken.isEmpty())
    return 1;
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
  const QString html = signInHtml();
  if (html.isEmpty())
    return 1;
  auto *profile = new QQuickWebEngineProfile(qApp);
  profile->setStorageName(QString::fromLatin1(kProfileName));
  profile->setOffTheRecord(false);
  profile->setPersistentCookiesPolicy(QQuickWebEngineProfile::ForcePersistentCookies);
  QQuickView view;
  view.rootContext()->setContextProperty(QStringLiteral("appleScripts"), QVariant::fromValue(QList<QWebEngineScript>{
      userScript(QStringLiteral("orchard-apple-capabilities"), QString::fromLatin1(kCapabilitiesShim), true),
      userScript(QStringLiteral("orchard-apple-bridge"),
                 QString::fromLatin1(kBridge).arg(jsString(QString::fromLatin1(kPageOrigin)), jsString(developerToken)), false)
  }));
  view.rootContext()->setContextProperty(QStringLiteral("appleProfile"), profile);
  view.rootContext()->setContextProperty(QStringLiteral("signInHtml"), html);
  view.rootContext()->setContextProperty(QStringLiteral("signInUrl"), QUrl(QString::fromLatin1(kPageUrl)));
  view.setResizeMode(QQuickView::SizeRootObjectToView);
  view.resize(520, 720);
  view.setTitle(QObject::tr("Sign in to Apple Music"));
  bool sent = false;
  AppleMusicLoginBridge bridge([&sent, &view, socketName](const QString &raw) {
    if (sent)
      return;
    const QJsonObject message = QJsonDocument::fromJson(raw.toUtf8()).object();
    const QString type = message.value(QStringLiteral("type")).toString();
    const QString token = message.value(QStringLiteral("token")).toString();
    QJsonObject result;
    if (type == QStringLiteral("authorized") && !token.isEmpty() && token.size() <= 16384)
      result.insert(QStringLiteral("token"), token);
    else if (type == QStringLiteral("error"))
      result.insert(QStringLiteral("error"), message.value(QStringLiteral("message")).toString());
    else
      return;
    sent = true;
    view.hide();
    sendAndQuit(socketName, result);
  });
  view.rootContext()->setContextProperty(QStringLiteral("loginBridge"), &bridge);
  view.setSource(QUrl(QStringLiteral("qrc:/auth/AppleMusicLoginView.qml")));
  if (view.status() == QQuickView::Error || !view.rootObject())
    return 1;
  QObject::connect(view.rootObject(), SIGNAL(closeRequested()), qApp, SLOT(quit()));
  view.show();
  return QCoreApplication::exec();
#else
  return 2;
#endif
}

int runAppleMusicLogout(const QString &socketName) {
#ifdef ORCHARD_WEBENGINE_COOKIE_ADAPTER
  QWebEngineProfile profile(QString::fromLatin1(kProfileName));
  QWebEnginePage page(&profile);
  // MusicKit keeps the Music User Token in the page origin's storage.
  QObject::connect(&page, &QWebEnginePage::loadFinished, qApp, [&profile, socketName] {
    profile.cookieStore()->deleteAllCookies();
    QTimer::singleShot(500, qApp, [socketName] { sendAndQuit(socketName, {{QStringLiteral("ok"), true}}); });
  });
  page.setHtml(QStringLiteral("<script>localStorage.clear();sessionStorage.clear();</script>"),
               QUrl(QString::fromLatin1(kPageUrl)));
  return QCoreApplication::exec();
#else
  Q_UNUSED(socketName);
  return 2;
#endif
}
