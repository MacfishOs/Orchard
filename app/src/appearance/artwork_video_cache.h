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

#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QString>

// Downloads animated artwork loops through Qt's network stack and hands QML a
// file URL. Letting the media backend stream https itself makes FFmpeg open a
// GnuTLS session per loop, and each one parses the full system trust store.
class ArtworkVideoCache final : public QObject {
  Q_OBJECT

public:
  static constexpr qint64 kMaxFileBytes = 64LL * 1024 * 1024;
  static constexpr qint64 kMaxCacheBytes = 512LL * 1024 * 1024;

  // Empty dir means <CacheLocation>/artwork-videos.
  explicit ArtworkVideoCache(const QString &dir = QString(), QObject *parent = nullptr);

  // File URL for a cached loop. Otherwise starts a download and returns empty;
  // ready or failed follows. Non-http URLs, and http ones when
  // the cache is unwritable, come back unchanged.
  Q_INVOKABLE QString localUrl(const QString &remote);
  // Drops the cached file, e.g. after the media backend rejects it.
  Q_INVOKABLE void discard(const QString &remote);

signals:
  void ready(const QString &remote, const QString &local);
  // permanent is false for network trouble that a later attempt may get past.
  void failed(const QString &remote, bool permanent);

private:
  QString pathFor(const QString &remote) const;
  void prune();

  QString m_dir;
  QNetworkAccessManager m_network;
  QSet<QString> m_pending;
};
