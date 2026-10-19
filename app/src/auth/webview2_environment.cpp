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

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>

namespace webview2 {
namespace {

struct EnvironmentState {
  ComPtr<ICoreWebView2Environment> environment;
  HRESULT status{S_OK};
  bool started{false};
  bool done{false};
  std::vector<EnvironmentReady> waiters;
};

EnvironmentState &environmentState() {
  static EnvironmentState state;
  return state;
}

void finishEnvironment(HRESULT status, ICoreWebView2Environment *environment) {
  auto &state = environmentState();
  state.done = true;
  state.status = status;
  state.environment = environment;
  auto waiters = std::move(state.waiters);
  for (auto &waiter : waiters)
    waiter(state.environment.Get(), status);
}

} // namespace

void withEnvironment(EnvironmentReady ready) {
  auto &state = environmentState();
  if (state.done) {
    ready(state.environment.Get(), state.status);
    return;
  }
  state.waiters.push_back(std::move(ready));
  if (state.started)
    return;
  state.started = true;
  const QString loaderPath =
      QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("WebView2Loader.dll"));
  HMODULE loader = LoadLibraryW(wide(QDir::toNativeSeparators(loaderPath)));
  using Create = decltype(&CreateCoreWebView2EnvironmentWithOptions);
  const auto create = loader ? reinterpret_cast<Create>(
                                   GetProcAddress(loader, "CreateCoreWebView2EnvironmentWithOptions"))
                             : nullptr;
  if (!create) {
    finishEnvironment(HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND), nullptr);
    return;
  }
  const QString folder = QDir::toNativeSeparators(
      QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation))
          .filePath(QStringLiteral("WebView2")));
  const HRESULT status = create(
      nullptr, wide(folder), nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [](HRESULT result, ICoreWebView2Environment *environment) -> HRESULT {
            finishEnvironment(result, environment);
            return S_OK;
          })
          .Get());
  if (FAILED(status))
    finishEnvironment(status, nullptr);
}

} // namespace webview2
