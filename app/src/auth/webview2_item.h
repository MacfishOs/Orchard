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

#include "webview2_view.h"

#include <QJSValue>
#include <QPointer>
#include <QQuickItem>
#include <QStringList>
#include <QUrl>

// Places a WebView2 controller over this item's rectangle in its window.
// Matches the parts of QtWebView's WebView that the sign-in views use.
class WebView2Item : public QQuickItem {
  Q_OBJECT
  Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
  Q_PROPERTY(QString title READ title NOTIFY titleChanged)
  Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
  Q_PROPERTY(int loadProgress READ loadProgress NOTIFY loadingChanged)
  Q_PROPERTY(bool canGoBack READ canGoBack NOTIFY canGoBackChanged)
  // Set once, before the view starts. Empty selects the default profile.
  Q_PROPERTY(QString profile READ profile WRITE setProfile NOTIFY profileChanged)
  Q_PROPERTY(QStringList userScripts READ userScripts WRITE setUserScripts NOTIFY userScriptsChanged)
  Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
  explicit WebView2Item(QQuickItem *parent = nullptr);
  ~WebView2Item() override;

  [[nodiscard]] QUrl url() const;
  void setUrl(const QUrl &url);
  [[nodiscard]] QString title() const;
  [[nodiscard]] bool loading() const;
  [[nodiscard]] int loadProgress() const;
  [[nodiscard]] bool canGoBack() const;
  [[nodiscard]] QString profile() const { return m_profile; }
  void setProfile(const QString &profile);
  [[nodiscard]] QStringList userScripts() const { return m_userScripts; }
  void setUserScripts(const QStringList &scripts);
  [[nodiscard]] QString errorString() const { return m_error; }
  [[nodiscard]] WebView2View *webView() const { return m_view; }

  Q_INVOKABLE void goBack();
  Q_INVOKABLE void reload();
  Q_INVOKABLE void loadHtml(const QString &html, const QUrl &baseUrl);
  Q_INVOKABLE void runJavaScript(const QString &script, const QJSValue &callback = QJSValue());

signals:
  void urlChanged();
  void titleChanged();
  void loadingChanged();
  void canGoBackChanged();
  void profileChanged();
  void userScriptsChanged();
  void errorStringChanged();
  void loadFinished();
  void webMessageReceived(const QString &message);

protected:
  void componentComplete() override;
  void itemChange(ItemChange change, const ItemChangeData &value) override;
  void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
  void ensureView();
  void updateBounds();

  QPointer<WebView2View> m_view;
  QUrl m_requestedUrl;
  QString m_profile;
  QStringList m_userScripts;
  QString m_error;
  QString m_html;
  bool m_htmlPending{false};
};
