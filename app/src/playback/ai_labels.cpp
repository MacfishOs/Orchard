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

#include "ai_labels.h"
#include "providers/youtube/youtube_provider.h"

#include <QDateTime>
#include <QDir>
#include <QJsonObject>
#include <QSqlQuery>
#include <QStandardPaths>

AiLabels::AiLabels(YouTubeProvider *provider, QObject *parent)
    : QObject(parent), m_provider(provider) {
  m_dbName = QStringLiteral("orchard-ai-labels-%1").arg(reinterpret_cast<quintptr>(this));
  if (!m_provider)
    return;
  connect(m_provider, &YouTubeProvider::resultReady, this,
          [this](quint64 request, const QJsonValue &result) {
            const QString id = m_pending.take(request);
            if (id.isEmpty())
              return;
            store(id, result.toObject().value(QStringLiteral("ai")).toBool());
            pump();
          });
  connect(m_provider, &YouTubeProvider::requestFailed, this,
          [this](quint64 request, const QString &) {
            const QString id = m_pending.take(request);
            if (id.isEmpty())
              return;
            m_failed.insert(id);
            pump();
          });
}

AiLabels::~AiLabels() {
  if (m_dbAttempted) {
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(m_dbName);
  }
}

void AiLabels::check(const QVariantList &tracks) {
  m_queue = tracks;
  pump();
}

void AiLabels::cancel() {
  m_queue.clear();
  m_pending.clear();
}

void AiLabels::pump() {
  if (!m_provider)
    return;
  while (m_pending.size() < kMaxRequests && !m_queue.isEmpty()) {
    const QVariantMap track = m_queue.takeFirst().toMap();
    const QString id = track.value(QStringLiteral("id")).toString();
    const QString type = track.value(QStringLiteral("type")).toString();
    if (id.isEmpty() || (type != "song" && type != "track" && type != "video") ||
        label(id) != Unknown || m_failed.contains(id) ||
        std::find(m_pending.cbegin(), m_pending.cend(), id) != m_pending.cend())
      continue;
    m_pending.insert(m_provider->invoke(QStringLiteral("catalog.aiLabel"),
                                        QJsonObject{{"videoId", id}}),
                     id);
  }
}

bool AiLabels::ensureDatabase() const {
  if (m_dbAttempted)
    return m_db.isOpen();
  m_dbAttempted = true;
  const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  QDir().mkpath(dir);
  m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_dbName);
  m_db.setDatabaseName(QDir(dir).filePath(QStringLiteral("ai-labels.sqlite")));
  if (!m_db.open())
    return false;
  QSqlQuery query(m_db);
  query.exec("PRAGMA cache_size=-256");
  if (!query.exec("CREATE TABLE IF NOT EXISTS labels ("
                  "id TEXT PRIMARY KEY, ai INTEGER NOT NULL, checked_at INTEGER NOT NULL)")) {
    m_db.close();
    return false;
  }
  query.exec("CREATE INDEX IF NOT EXISTS labels_checked_at ON labels(checked_at)");
  return true;
}

AiLabels::Label AiLabels::label(const QString &trackId) const {
  if (trackId.isEmpty())
    return Unknown;
  const auto cached = m_cache.constFind(trackId);
  if (cached != m_cache.cend())
    return *cached;
  Label result = Unknown;
  if (ensureDatabase()) {
    QSqlQuery query(m_db);
    query.prepare("SELECT ai, checked_at FROM labels WHERE id=?");
    query.addBindValue(trackId);
    if (query.exec() && query.next()) {
      if (query.value(0).toBool())
        result = MadeWithAi;
      else if (QDateTime::currentSecsSinceEpoch() - query.value(1).toLongLong() <
               kUnlabelledTtlSeconds)
        result = Unlabelled;
    }
  }
  if (m_cache.size() >= kMaxCached)
    m_cache.clear();
  m_cache.insert(trackId, result);
  return result;
}

void AiLabels::store(const QString &trackId, bool ai) {
  m_cache.insert(trackId, ai ? MadeWithAi : Unlabelled);
  if (ensureDatabase()) {
    QSqlQuery query(m_db);
    query.prepare("INSERT OR REPLACE INTO labels (id,ai,checked_at) VALUES (?,?,?)");
    query.addBindValue(trackId);
    query.addBindValue(ai ? 1 : 0);
    query.addBindValue(QDateTime::currentSecsSinceEpoch());
    query.exec();
    QSqlQuery trim(m_db);
    trim.prepare("DELETE FROM labels WHERE id NOT IN "
                 "(SELECT id FROM labels ORDER BY checked_at DESC LIMIT ?)");
    trim.addBindValue(kMaxStored);
    trim.exec();
  }
  emit labelled(trackId, ai);
}
