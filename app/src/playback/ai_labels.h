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
#include <QJsonValue>
#include <QObject>
#include <QSet>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>

class YouTubeProvider;

// YouTube's own "Made with AI" disclosure per video id, fetched in the background and cached.
class AiLabels final : public QObject {
  Q_OBJECT
public:
  enum Label { Unknown = -1, Unlabelled = 0, MadeWithAi = 1 };

  explicit AiLabels(YouTubeProvider *provider = nullptr, QObject *parent = nullptr);
  ~AiLabels() override;

  Label label(const QString &trackId) const;
  // Replaces the lookup order. Known tracks are skipped; requests in flight continue.
  void check(const QVariantList &tracks);
  void cancel();
  void store(const QString &trackId, bool ai);

signals:
  void labelled(const QString &trackId, bool ai);

private:
  bool ensureDatabase() const;
  void pump();

  static constexpr int kMaxRequests = 3;
  static constexpr int kMaxStored = 20000;
  static constexpr int kMaxCached = 2000;
  // Uploaders can add the disclosure later, so a "no" expires.
  static constexpr qint64 kUnlabelledTtlSeconds = 7 * 24 * 3600;

  YouTubeProvider *m_provider;
  QVariantList m_queue;
  QHash<quint64, QString> m_pending;
  // Failed lookups stay unknown for the session instead of retrying on every queue change.
  QSet<QString> m_failed;
  mutable QHash<QString, Label> m_cache;
  mutable QSqlDatabase m_db;
  mutable bool m_dbAttempted{false};
  QString m_dbName;
};
