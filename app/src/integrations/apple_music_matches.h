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

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QVariantList>
#include <functional>

class AuthManager;
class YouTubeCatalog;

// Apple Music songs play through their YouTube Music match until Apple Music playback exists.
class AppleMusicMatches final : public QObject {
  Q_OBJECT

public:
  using Reply = std::function<void(const QVariantList &tracks, int startIndex)>;

  AppleMusicMatches(YouTubeCatalog *catalog, AuthManager *auth, QObject *parent = nullptr);

  // False when [tracks] holds no Apple Music songs. Otherwise [done] later gets the
  // tracks with matches swapped in and unmatched songs dropped; the start follows the requested song.
  bool resolve(const QVariantList &tracks, int startIndex, Reply done);

  // The closest-duration song among YouTube's top results, or the first one.
  static QVariantMap bestMatch(const QVariantMap &track, const QJsonObject &search);

private:
  struct Job {
    QVariantList tracks;
    int startIndex{0};
    int pending{0};
    Reply done;
  };

  void settle(quint64 requestId, const QJsonObject &search);
  void finish(quint64 jobId);

  YouTubeCatalog *m_catalog;
  AuthManager *m_auth;
  quint64 m_nextJob{0};
  QHash<quint64, Job> m_jobs;
  // Search request id to {job id, track index}.
  QHash<quint64, QPair<quint64, int>> m_requests;
  QHash<QString, QVariantMap> m_cache;
};
