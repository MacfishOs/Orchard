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
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#include "audiodb_artist.h"

#include <QUrl>
#include <QVariantMap>

namespace {

void addFact(QVariantList &facts, const QString &key, const QString &value) {
  const QString trimmed = value.trimmed();
  // TheAudioDB fills unknown years with "0".
  if (trimmed.isEmpty() || trimmed == QStringLiteral("0"))
    return;
  facts.append(QVariantMap{{QStringLiteral("key"), key}, {QStringLiteral("value"), trimmed}});
}

} // namespace

AudioDbArtist parseAudioDbArtist(const QJsonObject &artist) {
  AudioDbArtist result;
  for (const auto *field : {"strArtistFanart", "strArtistFanart2", "strArtistFanart3", "strArtistBanner"}) {
    const QString candidate = artist.value(QLatin1String(field)).toString().trimmed();
    const QUrl url(candidate);
    if (url.isValid() && !url.host().isEmpty() &&
        (url.scheme() == QStringLiteral("https") || url.scheme() == QStringLiteral("http"))) {
      result.artwork = candidate;
      break;
    }
  }
  addFact(result.facts, QStringLiteral("genre"), artist.value(QStringLiteral("strGenre")).toString());
  addFact(result.facts, QStringLiteral("origin"), artist.value(QStringLiteral("strCountry")).toString());
  addFact(result.facts, QStringLiteral("formed"), artist.value(QStringLiteral("intFormedYear")).toString());
  return result;
}
