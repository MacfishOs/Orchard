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

#pragma once

#include <QJsonObject>
#include <QString>
#include <QVariantList>

// What the artist page uses from a TheAudioDB artist record.
struct AudioDbArtist {
  // First usable fanart or banner URL; empty when none.
  QString artwork;
  // {key, value} maps in display order; keys are "genre", "origin" and "formed".
  QVariantList facts;
};

AudioDbArtist parseAudioDbArtist(const QJsonObject &artist);
