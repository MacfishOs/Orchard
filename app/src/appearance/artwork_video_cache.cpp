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

#include "artwork_video_cache.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>
#include <memory>

ArtworkVideoCache::ArtworkVideoCache(const QString &dir, QObject *parent)
    : QObject(parent),
      m_dir(dir.isEmpty()
                ? QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))
                      .filePath(QStringLiteral("artwork-videos"))
                : dir) {
  QDir().mkpath(m_dir);
}

QString ArtworkVideoCache::pathFor(const QString &remote) const {
  const QByteArray hash =
      QCryptographicHash::hash(remote.toUtf8(), QCryptographicHash::Sha1).toHex();
  return QDir(m_dir).filePath(QString::fromLatin1(hash) + QStringLiteral(".mp4"));
}

QString ArtworkVideoCache::localUrl(const QString &remote) {
  const QUrl url(remote);
  const QString scheme = url.scheme();
  if (scheme != QLatin1String("https") && scheme != QLatin1String("http"))
    return remote;

  const QString path = pathFor(remote);
  QFile file(path);
  if (file.exists()) {
    // mtime orders eviction, so a replayed loop counts as recent.
    if (file.open(QIODevice::ReadWrite))
      file.setFileTime(QDateTime::currentDateTimeUtc(), QFileDevice::FileModificationTime);
    return QUrl::fromLocalFile(path).toString();
  }
  if (m_pending.contains(remote))
    return {};

  auto out = std::make_shared<QSaveFile>(path);
  if (!out->open(QIODevice::WriteOnly))
    return remote;

  QNetworkRequest request(url);
  request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Orchard/3.0"));
  QNetworkReply *reply = m_network.get(request);
  m_pending.insert(remote);
  auto tooLarge = std::make_shared<bool>(false);
  connect(reply, &QNetworkReply::readyRead, this, [reply, out, tooLarge] {
    if (*tooLarge)
      return;
    if (out->size() + reply->bytesAvailable() > kMaxFileBytes) {
      *tooLarge = true;
      reply->abort();
      return;
    }
    out->write(reply->readAll());
  });
  connect(reply, &QNetworkReply::finished, this, [this, reply, out, tooLarge, remote, path] {
    reply->deleteLater();
    m_pending.remove(remote);
    const auto error = reply->error();
    if (error == QNetworkReply::NoError && !*tooLarge) {
      out->write(reply->readAll());
      if (out->commit()) {
        prune();
        emit ready(remote, QUrl::fromLocalFile(path).toString());
        return;
      }
    }
    out->cancelWriting();
    // Content errors (4xx and the like) sit in 201-299; the rest may clear up.
    const bool permanent =
        *tooLarge || (error >= QNetworkReply::ContentAccessDenied &&
                      error <= QNetworkReply::UnknownContentError);
    emit failed(remote, permanent);
  });
  return {};
}

void ArtworkVideoCache::discard(const QString &remote) {
  QFile::remove(pathFor(remote));
}

void ArtworkVideoCache::prune() {
  const QFileInfoList files =
      QDir(m_dir).entryInfoList({QStringLiteral("*.mp4")}, QDir::Files, QDir::Time);
  qint64 total = 0;
  for (const QFileInfo &info : files) {
    total += info.size();
    if (total > kMaxCacheBytes)
      QFile::remove(info.absoluteFilePath());
  }
}
