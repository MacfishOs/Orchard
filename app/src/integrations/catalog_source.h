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

#include <QObject>
#include <QString>

// The one service the catalog pages read from: "youtube" or "apple_music". Never mixed.
class CatalogSource final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString source READ source WRITE setSource NOTIFY changed)
  Q_PROPERTY(bool apple READ apple NOTIFY changed)

public:
  explicit CatalogSource(QObject *parent = nullptr);

  [[nodiscard]] QString source() const { return m_source; }
  [[nodiscard]] bool apple() const { return m_source == QStringLiteral("apple_music"); }
  void setSource(const QString &source);

signals:
  void changed();

private:
  QString m_source{QStringLiteral("youtube")};
};
