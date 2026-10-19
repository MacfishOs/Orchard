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

#include "catalog_source.h"

#include <QSettings>

namespace {
// Kept under its Home-only name so existing choices carry over.
const QString kSettingKey = QStringLiteral("playback/homeSource");
} // namespace

CatalogSource::CatalogSource(QObject *parent) : QObject(parent) {
  if (QSettings().value(kSettingKey).toString() == QStringLiteral("apple_music"))
    m_source = QStringLiteral("apple_music");
}

void CatalogSource::setSource(const QString &source) {
  if ((source != QStringLiteral("youtube") && source != QStringLiteral("apple_music")) || source == m_source)
    return;
  m_source = source;
  QSettings().setValue(kSettingKey, source);
  emit changed();
}
