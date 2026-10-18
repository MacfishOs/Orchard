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
#include "auth_diagnostics.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QPointer>

#include <shlwapi.h>

using webview2::take;
using webview2::wide;

namespace {

QList<WebView2View *> &liveViews() {
  static QList<WebView2View *> views;
  return views;
}

QString originOf(const QUrl &url) {
  return url.adjusted(QUrl::RemovePath | QUrl::RemoveQuery | QUrl::RemoveFragment |
                      QUrl::StripTrailingSlash)
      .toString();
}

QString describe(const char *stage, HRESULT status) {
  if (status == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || status == HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND))
    return QObject::tr("Sign-in needs the Microsoft Edge WebView2 Runtime. Install it from "
                       "Microsoft and try again.");
  return QObject::tr("The sign-in browser could not start (%1, 0x%2).")
      .arg(QString::fromLatin1(stage))
      .arg(static_cast<quint32>(status), 8, 16, QLatin1Char('0'));
}

} // namespace

WebView2View::WebView2View(Options options, QObject *parent)
    : QObject(parent), m_options(std::move(options)), m_native(std::make_unique<Native>()) {
  liveViews().append(this);
}

WebView2View::~WebView2View() {
  liveViews().removeAll(this);
  if (m_native->controller)
    m_native->controller->Close();
}

bool WebView2View::isReady() const { return m_native->webview != nullptr; }

WebView2View *WebView2View::findReady(const QString &profile) {
  for (auto *view : liveViews())
    if (view->isReady() && !view->m_options.inPrivate && view->profile() == profile)
      return view;
  return nullptr;
}

void WebView2View::fail(const char *stage, long status) {
  if (m_failed)
    return;
  m_failed = true;
  m_pending.clear();
  authDiagnostic(QStringLiteral("webview2-error %1 0x%2")
                     .arg(QString::fromLatin1(stage))
                     .arg(static_cast<quint32>(status), 8, 16, QLatin1Char('0')));
  emit failed(describe(stage, status));
}

void WebView2View::create(WId parent) {
  const QPointer<WebView2View> self(this);
  const HWND window = reinterpret_cast<HWND>(parent);
  webview2::withEnvironment([self, window](ICoreWebView2Environment *environment, HRESULT status) {
    if (!self)
      return;
    if (FAILED(status) || !environment) {
      self->fail("environment", FAILED(status) ? status : E_POINTER);
      return;
    }
    self->m_native->environment = environment;
    ComPtr<ICoreWebView2Environment10> withOptions;
    ComPtr<ICoreWebView2ControllerOptions> options;
    if (FAILED(self->m_native->environment.As(&withOptions)) ||
        FAILED(withOptions->CreateCoreWebView2ControllerOptions(&options))) {
      self->fail("controller options", E_NOINTERFACE);
      return;
    }
    if (!self->m_options.profile.isEmpty())
      options->put_ProfileName(wide(self->m_options.profile));
    options->put_IsInPrivateModeEnabled(self->m_options.inPrivate);
    const HRESULT created = withOptions->CreateCoreWebView2ControllerWithOptions(
        window, options.Get(),
        Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
            [self](HRESULT result, ICoreWebView2Controller *controller) -> HRESULT {
              if (!self) {
                if (controller)
                  controller->Close();
                return S_OK;
              }
              if (FAILED(result) || !controller) {
                self->fail("controller", FAILED(result) ? result : E_POINTER);
                return S_OK;
              }
              self->m_native->controller = controller;
              self->attach();
              return S_OK;
            })
            .Get());
    if (FAILED(created))
      self->fail("create controller", created);
  });
}

void WebView2View::attach() {
  auto &native = *m_native;
  ComPtr<ICoreWebView2_2> withCookies;
  if (FAILED(native.controller->get_CoreWebView2(&native.webview)) ||
      FAILED(native.webview.As(&withCookies)) || FAILED(withCookies->get_CookieManager(&native.cookies))) {
    native.webview.Reset();
    fail("webview", E_NOINTERFACE);
    return;
  }
  const RECT bounds{m_bounds.left(), m_bounds.top(), m_bounds.left() + m_bounds.width(),
                    m_bounds.top() + m_bounds.height()};
  native.controller->put_Bounds(bounds);
  native.controller->put_IsVisible(m_visible);

  ComPtr<ICoreWebView2Settings> settings;
  if (SUCCEEDED(native.webview->get_Settings(&settings))) {
    settings->put_IsStatusBarEnabled(FALSE);
    ComPtr<ICoreWebView2Settings2> agent;
    if (!m_options.userAgent.isEmpty() && SUCCEEDED(settings.As(&agent)))
      agent->put_UserAgent(wide(m_options.userAgent));
  }
  for (const QString &script : m_options.startupScripts)
    native.webview->AddScriptToExecuteOnDocumentCreated(wide(script), nullptr);

  const QPointer<WebView2View> self(this);
  EventRegistrationToken token;
  native.webview->add_NavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
          [self](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *) -> HRESULT {
            if (self)
              self->setLoading(true, 10);
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_ContentLoading(
      Callback<ICoreWebView2ContentLoadingEventHandler>(
          [self](ICoreWebView2 *, ICoreWebView2ContentLoadingEventArgs *) -> HRESULT {
            if (self)
              self->setLoading(true, 60);
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
          [self](ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *args) -> HRESULT {
            if (!self)
              return S_OK;
            BOOL success = FALSE;
            args->get_IsSuccess(&success);
            self->setLoading(false, 100);
            emit self->loadFinished(success);
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_SourceChanged(
      Callback<ICoreWebView2SourceChangedEventHandler>(
          [self](ICoreWebView2 *view, ICoreWebView2SourceChangedEventArgs *) -> HRESULT {
            LPWSTR source = nullptr;
            if (!self || FAILED(view->get_Source(&source)))
              return S_OK;
            const QUrl url(take(source));
            if (url != self->m_url) {
              self->m_url = url;
              emit self->urlChanged();
            }
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_DocumentTitleChanged(
      Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
          [self](ICoreWebView2 *view, IUnknown *) -> HRESULT {
            LPWSTR title = nullptr;
            if (!self || FAILED(view->get_DocumentTitle(&title)))
              return S_OK;
            self->m_title = take(title);
            emit self->titleChanged();
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_HistoryChanged(
      Callback<ICoreWebView2HistoryChangedEventHandler>([self](ICoreWebView2 *view, IUnknown *) -> HRESULT {
        BOOL back = FALSE;
        if (!self || FAILED(view->get_CanGoBack(&back)) || bool(back) == self->m_canGoBack)
          return S_OK;
        self->m_canGoBack = back;
        emit self->canGoBackChanged();
        return S_OK;
      }).Get(),
      &token);
  native.webview->add_WebMessageReceived(
      Callback<ICoreWebView2WebMessageReceivedEventHandler>(
          [self](ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs *args) -> HRESULT {
            LPWSTR message = nullptr;
            LPWSTR source = nullptr;
            if (!self || FAILED(args->TryGetWebMessageAsString(&message)))
              return S_OK;
            args->get_Source(&source);
            const QString text = take(message);
            emit self->webMessageReceived(text, QUrl(take(source)));
            return S_OK;
          })
          .Get(),
      &token);
  native.webview->add_WebResourceRequested(
      Callback<ICoreWebView2WebResourceRequestedEventHandler>(
          [self](ICoreWebView2 *, ICoreWebView2WebResourceRequestedEventArgs *args) -> HRESULT {
            ComPtr<ICoreWebView2WebResourceRequest> request;
            LPWSTR uri = nullptr;
            if (!self || FAILED(args->get_Request(&request)) || FAILED(request->get_Uri(&uri)))
              return S_OK;
            const QUrl url(take(uri));
            const bool page = url.adjusted(QUrl::RemoveFragment) == self->m_htmlUrl.adjusted(QUrl::RemoveFragment);
            const QByteArray body = page ? self->m_html.toUtf8() : QByteArray();
            ComPtr<IStream> stream;
            stream.Attach(SHCreateMemStream(reinterpret_cast<const BYTE *>(body.constData()),
                                            static_cast<UINT>(body.size())));
            ComPtr<ICoreWebView2WebResourceResponse> response;
            self->m_native->environment->CreateWebResourceResponse(
                stream.Get(), page ? 200 : 404, page ? L"OK" : L"Not Found",
                L"Content-Type: text/html; charset=utf-8", &response);
            args->put_Response(response.Get());
            return S_OK;
          })
          .Get(),
      &token);

  authDiagnostic(QStringLiteral("webview2-ready profile=%1").arg(m_options.profile));
  auto pending = std::move(m_pending);
  for (auto &action : pending)
    action();
  emit ready();
}

void WebView2View::whenReady(std::function<void()> action) {
  if (isReady())
    action();
  else if (!m_failed)
    m_pending.push_back(std::move(action));
}

void WebView2View::setLoading(bool loading, int progress) {
  if (loading == m_loading && progress == m_progress)
    return;
  m_loading = loading;
  m_progress = progress;
  emit loadingChanged();
}

void WebView2View::navigate(const QUrl &url) {
  whenReady([this, url] { m_native->webview->Navigate(wide(url.toString(QUrl::FullyEncoded))); });
}

void WebView2View::loadHtml(const QString &html, const QUrl &baseUrl) {
  m_html = html;
  m_htmlUrl = baseUrl;
  whenReady([this, baseUrl] {
    const QString origin = originOf(baseUrl);
    if (m_native->filteredOrigin != origin) {
      if (!m_native->filteredOrigin.isEmpty())
        m_native->webview->RemoveWebResourceRequestedFilter(
            wide(m_native->filteredOrigin + QStringLiteral("/*")), COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
      m_native->filteredOrigin = origin;
      m_native->webview->AddWebResourceRequestedFilter(wide(origin + QStringLiteral("/*")),
                                                       COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
    }
    m_native->webview->Navigate(wide(baseUrl.toString(QUrl::FullyEncoded)));
  });
}

void WebView2View::reload() {
  whenReady([this] { m_native->webview->Reload(); });
}

void WebView2View::goBack() {
  whenReady([this] { m_native->webview->GoBack(); });
}

void WebView2View::runJavaScript(const QString &script, std::function<void(const QJsonValue &)> done) {
  if (m_failed) {
    if (done)
      done(QJsonValue());
    return;
  }
  const QPointer<WebView2View> self(this);
  whenReady([this, self, script, done = std::move(done)] {
    const HRESULT status = m_native->webview->ExecuteScript(
        wide(script), Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                          [self, done](HRESULT result, LPCWSTR json) -> HRESULT {
                            if (!self || !done)
                              return S_OK;
                            QJsonValue value;
                            if (SUCCEEDED(result) && json) {
                              const QByteArray wrapped =
                                  '[' + QString::fromWCharArray(json).toUtf8() + ']';
                              value = QJsonDocument::fromJson(wrapped).array().at(0);
                            }
                            done(value);
                            return S_OK;
                          })
                          .Get());
    if (FAILED(status) && done)
      done(QJsonValue());
  });
}

void WebView2View::setBounds(const QRect &bounds) {
  if (bounds == m_bounds)
    return;
  m_bounds = bounds;
  if (m_native->controller)
    m_native->controller->put_Bounds(RECT{bounds.left(), bounds.top(), bounds.left() + bounds.width(),
                                          bounds.top() + bounds.height()});
}

void WebView2View::setVisible(bool visible) {
  m_visible = visible;
  if (m_native->controller)
    m_native->controller->put_IsVisible(visible);
}

void WebView2View::notifyParentMoved() {
  if (m_native->controller)
    m_native->controller->NotifyParentWindowPositionChanged();
}

WebView2HiddenHost::WebView2HiddenHost() {
  m_window.setFlags(Qt::Tool | Qt::FramelessWindowHint);
  m_window.resize(1280, 800);
  m_window.create();
}
