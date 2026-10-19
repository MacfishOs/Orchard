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

#include "webview2_item.h"
#include "webview2_view.h"

#include <QJsonValue>
#include <QQmlEngine>
#include <QQuickWindow>

#include <cmath>

WebView2Item::WebView2Item(QQuickItem *parent) : QQuickItem(parent) {}

WebView2Item::~WebView2Item() = default;

QUrl WebView2Item::url() const {
  return m_view && m_view->url().isValid() ? m_view->url() : m_requestedUrl;
}

void WebView2Item::setUrl(const QUrl &url) {
  if (url == this->url())
    return;
  m_requestedUrl = url;
  if (m_view)
    m_view->navigate(url);
  else
    emit urlChanged();
}

QString WebView2Item::title() const { return m_view ? m_view->title() : QString(); }
bool WebView2Item::loading() const { return m_view && m_view->loading(); }
int WebView2Item::loadProgress() const { return m_view ? m_view->loadProgress() : 0; }
bool WebView2Item::canGoBack() const { return m_view && m_view->canGoBack(); }

void WebView2Item::setProfile(const QString &profile) {
  if (profile == m_profile)
    return;
  if (m_view)
    qWarning("WebView2Item: profile is fixed once the view starts");
  m_profile = profile;
  emit profileChanged();
}

void WebView2Item::setUserScripts(const QStringList &scripts) {
  if (scripts == m_userScripts)
    return;
  if (m_view)
    qWarning("WebView2Item: userScripts are fixed once the view starts");
  m_userScripts = scripts;
  emit userScriptsChanged();
}

void WebView2Item::goBack() {
  if (m_view)
    m_view->goBack();
}

void WebView2Item::reload() {
  if (m_view)
    m_view->reload();
}

void WebView2Item::loadHtml(const QString &html, const QUrl &baseUrl) {
  m_requestedUrl = baseUrl;
  m_html = html;
  m_htmlPending = true;
  if (m_view) {
    m_htmlPending = false;
    m_view->loadHtml(html, baseUrl);
  }
}

void WebView2Item::runJavaScript(const QString &script, const QJSValue &callback) {
  if (!m_view)
    return;
  const QPointer<WebView2Item> self(this);
  m_view->runJavaScript(script, [self, callback](const QJsonValue &value) {
    if (!self || !callback.isCallable())
      return;
    QJSEngine *engine = qmlEngine(self);
    if (!engine)
      return;
    QJSValue function = callback;
    function.call({engine->toScriptValue(value.toVariant())});
  });
}

void WebView2Item::componentComplete() {
  QQuickItem::componentComplete();
  ensureView();
}

void WebView2Item::itemChange(ItemChange change, const ItemChangeData &value) {
  QQuickItem::itemChange(change, value);
  if (change == ItemSceneChange)
    ensureView();
  else if (change == ItemVisibleHasChanged && m_view)
    m_view->setVisible(value.boolValue);
}

void WebView2Item::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) {
  QQuickItem::geometryChange(newGeometry, oldGeometry);
  updateBounds();
}

void WebView2Item::ensureView() {
  QQuickWindow *window = this->window();
  if (m_view || !isComponentComplete() || !window)
    return;
  WebView2View::Options options;
  options.profile = m_profile;
  options.startupScripts = m_userScripts;
  m_view = new WebView2View(options, this);
  connect(m_view, &WebView2View::urlChanged, this, &WebView2Item::urlChanged);
  connect(m_view, &WebView2View::titleChanged, this, &WebView2Item::titleChanged);
  connect(m_view, &WebView2View::loadingChanged, this, &WebView2Item::loadingChanged);
  connect(m_view, &WebView2View::canGoBackChanged, this, &WebView2Item::canGoBackChanged);
  connect(m_view, &WebView2View::loadFinished, this, [this](bool ok) {
    if (ok)
      emit loadFinished();
  });
  connect(m_view, &WebView2View::webMessageReceived, this,
          [this](const QString &message, const QUrl &) { emit webMessageReceived(message); });
  connect(m_view, &WebView2View::failed, this, [this](const QString &message) {
    m_error = message;
    emit errorStringChanged();
  });
  // A frame follows every layout or window resize, so bounds track it there.
  connect(window, &QQuickWindow::afterAnimating, this, &WebView2Item::updateBounds);
  connect(window, &QWindow::xChanged, m_view, &WebView2View::notifyParentMoved);
  connect(window, &QWindow::yChanged, m_view, &WebView2View::notifyParentMoved);
  m_view->setVisible(isVisible());
  updateBounds();
  m_view->create(window->winId());
  if (m_htmlPending) {
    m_htmlPending = false;
    m_view->loadHtml(m_html, m_requestedUrl);
  } else if (m_requestedUrl.isValid()) {
    m_view->navigate(m_requestedUrl);
  }
}

void WebView2Item::updateBounds() {
  QQuickWindow *window = this->window();
  if (!m_view || !window)
    return;
  const qreal ratio = window->effectiveDevicePixelRatio();
  const QRectF scene = mapRectToScene(boundingRect());
  const QPoint topLeft(std::lround(scene.left() * ratio), std::lround(scene.top() * ratio));
  const QPoint bottomRight(std::lround(scene.right() * ratio), std::lround(scene.bottom() * ratio));
  m_view->setBounds(QRect(topLeft, QSize(bottomRight.x() - topLeft.x(), bottomRight.y() - topLeft.y())));
}
