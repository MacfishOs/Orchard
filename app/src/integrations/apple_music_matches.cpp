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

#include "apple_music_matches.h"

#include "auth/auth_manager.h"
#include "providers/youtube/catalog/youtube_catalog.h"

#include <QJsonArray>

#include <algorithm>
#include <cmath>

namespace {
constexpr int kCandidates = 3;
constexpr double kMaxDriftSeconds = 5.0;

bool isAppleTrack(const QVariant &track) {
  return track.toMap().value(QStringLiteral("source")).toString() == QStringLiteral("apple_music");
}
} // namespace

AppleMusicMatches::AppleMusicMatches(YouTubeCatalog *catalog, AuthManager *auth, QObject *parent)
    : QObject(parent), m_catalog(catalog), m_auth(auth) {
  connect(m_catalog, &YouTubeCatalog::searchReady, this, &AppleMusicMatches::settle);
  connect(m_catalog, &YouTubeCatalog::requestFailed, this,
          [this](quint64 requestId, const QString &) { settle(requestId, {}); });
}

QVariantMap AppleMusicMatches::bestMatch(const QVariantMap &track, const QJsonObject &search) {
  QList<QVariantMap> candidates;
  for (const QJsonValue &section : search.value(QStringLiteral("sections")).toArray()) {
    if (section.toObject().value(QStringLiteral("key")).toString() != QStringLiteral("songs"))
      continue;
    for (const QJsonValue &item : section.toObject().value(QStringLiteral("items")).toArray()) {
      const QVariantMap candidate = item.toObject().toVariantMap();
      if (!candidate.value(QStringLiteral("id")).toString().isEmpty() && candidates.size() < kCandidates)
        candidates.append(candidate);
    }
  }
  if (candidates.isEmpty())
    return {};
  const double wanted = track.value(QStringLiteral("durationSeconds")).toDouble();
  QVariantMap best = candidates.first();
  double bestDrift = kMaxDriftSeconds;
  for (const QVariantMap &candidate : candidates) {
    const double seconds = candidate.value(QStringLiteral("durationSeconds")).toDouble();
    if (wanted <= 0 || seconds <= 0)
      continue;
    const double drift = std::abs(seconds - wanted);
    if (drift <= bestDrift) {
      bestDrift = drift;
      best = candidate;
    }
  }
  return best;
}

bool AppleMusicMatches::resolve(const QVariantList &tracks, int startIndex, Reply done) {
  if (std::none_of(tracks.cbegin(), tracks.cend(), isAppleTrack))
    return false;
  const quint64 jobId = ++m_nextJob;
  Job &job = m_jobs[jobId];
  job.tracks = tracks;
  job.startIndex = startIndex;
  job.done = std::move(done);
  const QJsonObject session = m_auth->sessionObject();
  for (int index = 0; index < tracks.size(); ++index) {
    if (!isAppleTrack(tracks.at(index)))
      continue;
    const QVariantMap track = tracks.at(index).toMap();
    const auto cached = m_cache.constFind(track.value(QStringLiteral("id")).toString());
    if (cached != m_cache.cend()) {
      job.tracks[index] = *cached;
      continue;
    }
    const QString query = track.value(QStringLiteral("title")).toString() + QLatin1Char(' ') +
                          track.value(QStringLiteral("artist")).toString();
    m_requests.insert(m_catalog->fetchSearch(query, QStringLiteral("songs"), session), {jobId, index});
    ++job.pending;
  }
  if (job.pending == 0)
    finish(jobId);
  return true;
}

void AppleMusicMatches::settle(quint64 requestId, const QJsonObject &search) {
  const auto request = m_requests.constFind(requestId);
  if (request == m_requests.cend())
    return;
  const auto [jobId, index] = *request;
  m_requests.erase(request);
  Job &job = m_jobs[jobId];
  const QVariantMap track = job.tracks.at(index).toMap();
  QVariantMap match = bestMatch(track, search);
  if (!match.isEmpty()) {
    // Apple's cover is the one the listener saw on the page.
    const QString cover = track.value(QStringLiteral("thumbnail")).toString();
    if (!cover.isEmpty())
      match.insert(QStringLiteral("thumbnail"), cover);
    m_cache.insert(track.value(QStringLiteral("id")).toString(), match);
  }
  job.tracks[index] = match;
  if (--job.pending == 0)
    finish(jobId);
}

void AppleMusicMatches::finish(quint64 jobId) {
  Job job = m_jobs.take(jobId);
  QVariantList playable;
  int start = -1;
  for (int index = 0; index < job.tracks.size(); ++index) {
    const QVariantMap track = job.tracks.at(index).toMap();
    if (track.isEmpty() || track.value(QStringLiteral("source")).toString() == QStringLiteral("apple_music"))
      continue;
    // The requested song, or the next one that survived matching.
    if (start < 0 && index >= job.startIndex)
      start = static_cast<int>(playable.size());
    playable.append(track);
  }
  if (job.done)
    job.done(playable, start < 0 ? 0 : start);
}
