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

#include <QJsonValue>
#include <QList>
#include <QNetworkCookie>
#include <QObject>
#include <QRect>
#include <QStringList>
#include <QUrl>
#include <QWindow>

#include <functional>
#include <memory>
#include <vector>

// One WebView2 controller hosted in a native window. All views share one
// environment rooted in Orchard's local data folder; profiles separate sites.
class WebView2View final : public QObject {
  Q_OBJECT

public:
  struct Options {
    QString profile;
    bool inPrivate{false};
    QString userAgent;
    // Injected at document creation in every frame, before page scripts.
    QStringList startupScripts;
  };

  explicit WebView2View(Options options, QObject *parent = nullptr);
  ~WebView2View() override;

  void create(WId parent);
  [[nodiscard]] bool isReady() const;
  [[nodiscard]] QString profile() const { return m_options.profile; }
  [[nodiscard]] QUrl url() const { return m_url; }
  [[nodiscard]] QString title() const { return m_title; }
  [[nodiscard]] bool loading() const { return m_loading; }
  [[nodiscard]] int loadProgress() const { return m_progress; }
  [[nodiscard]] bool canGoBack() const { return m_canGoBack; }

  // Calls before ready() are queued in order.
  void navigate(const QUrl &url);
  // Serves html at baseUrl so the page gets that origin.
  void loadHtml(const QString &html, const QUrl &baseUrl);
  void reload();
  void goBack();
  // done receives the script's completion value decoded from JSON.
  void runJavaScript(const QString &script, std::function<void(const QJsonValue &)> done = {});

  // Physical pixels relative to the parent window.
  void setBounds(const QRect &bounds);
  void setVisible(bool visible);
  void notifyParentMoved();

  void cookies(const QUrl &url, std::function<void(const QList<QNetworkCookie> &)> done);
  void setCookie(const QNetworkCookie &cookie);
  void deleteCookies(const QUrl &url, std::function<void()> done = {});
  // Clears cookies, storage and cache of this view's profile.
  void clearProfileData(std::function<void(bool)> done);

  // First ready view in profile; cookie readers share its cookie manager.
  static WebView2View *findReady(const QString &profile);

signals:
  void ready();
  void failed(const QString &message);
  void urlChanged();
  void titleChanged();
  void loadingChanged();
  void loadFinished(bool ok);
  void canGoBackChanged();
  void webMessageReceived(const QString &message, const QUrl &source);

private:
  struct Native;
  void whenReady(std::function<void()> action);
  void attach();
  void fail(const char *stage, long status);
  void setLoading(bool loading, int progress);

  Options m_options;
  std::unique_ptr<Native> m_native;
  std::vector<std::function<void()>> m_pending;
  QUrl m_url;
  QString m_title;
  QString m_html;
  QUrl m_htmlUrl;
  QRect m_bounds;
  bool m_visible{true};
  bool m_loading{false};
  int m_progress{0};
  bool m_canGoBack{false};
  bool m_failed{false};
};

// Native host window for views with no Qt Quick surface.
class WebView2HiddenHost final {
public:
  WebView2HiddenHost();
  [[nodiscard]] WId winId() const { return m_window.winId(); }

private:
  QWindow m_window;
};
