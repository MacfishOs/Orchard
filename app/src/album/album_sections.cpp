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

#include "album_controller.h"

#include "auth/auth_manager.h"
#include "integrations/apple_music.h"
#include "integrations/catalog_source.h"
#include "providers/youtube/catalog/youtube_catalog.h"

#include <QJsonArray>
#include <QPointer>

void AlbumController::setAppleMusic(AppleMusic *appleMusic, CatalogSource *source) {
  m_appleMusic = appleMusic;
  m_source = source;
  connect(source, &CatalogSource::changed, this, &AlbumController::retry);
}

void AlbumController::openSection(const QVariantMap &section) {
  const QVariantMap selected = section;
  closeSection();
  m_expandedSection = selected;
  const QVariantMap payload = selected.value(QStringLiteral("browsePayload")).toMap();
  const QString browseId = payload.value(QStringLiteral("browseId")).toString();
  if (browseId.isEmpty()) {
    emit sectionChanged();
    return;
  }
  m_sectionLoading = true;
  if (AppleMusic::isAppleMusicId(browseId)) {
    const quint64 id = (quint64{1} << 63) | ++m_appleRequests;
    m_sectionRequest = id;
    if (!m_appleMusic) {
      receiveSection(id, {}, tr("Connect Apple Music in Settings to open this."));
      return;
    }
    QPointer<AlbumController> self(this);
    m_appleMusic->artistView(browseId, payload.value(QStringLiteral("params")).toString(),
        [self, id](const QJsonObject &page, const QString &error) {
          if (self) self->receiveSection(id, page, error);
        });
  } else {
    m_sectionRequest = m_catalog->fetchBrowse(QJsonObject::fromVariantMap(payload), m_auth->sessionObject());
  }
  emit sectionChanged();
}

void AlbumController::closeSection() {
  m_sectionRequest = 0;
  m_expandedSection.clear();
  m_sectionLoading = false;
  m_sectionError.clear();
  emit sectionChanged();
}

void AlbumController::retrySection() {
  if (!m_expandedSection.isEmpty())
    openSection(m_expandedSection);
}

void AlbumController::receiveSection(quint64 requestId, const QJsonObject &page, const QString &error) {
  if (!m_sectionRequest || requestId != m_sectionRequest)
    return;
  m_sectionRequest = 0;
  m_sectionLoading = false;
  m_sectionError = error;
  if (error.isEmpty()) {
    QJsonArray items = page.value(QStringLiteral("items")).toArray();
    if (!page.contains(QStringLiteral("items"))) {
      for (const auto &section : page.value(QStringLiteral("sections")).toArray())
        for (const auto &item : section.toObject().value(QStringLiteral("items")).toArray())
          items.append(item);
    }
    m_expandedSection.insert(QStringLiteral("items"), items.toVariantList());
  }
  emit sectionChanged();
}
