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

#include "video_ambient.h"

#include <algorithm>

namespace videoambient {

QList<QColor> grid(const QImage &frame, const QRectF &crop, int cols, int rows) {
  QList<QColor> colors;
  if (frame.isNull() || cols <= 0 || rows <= 0)
    return colors;
  const QRectF area = crop.isNull() ? QRectF(0, 0, 1, 1) : crop;
  const QRect pixels = QRect(qRound(area.x() * frame.width()), qRound(area.y() * frame.height()),
                             qRound(area.width() * frame.width()), qRound(area.height() * frame.height()))
                           .intersected(frame.rect());
  if (pixels.isEmpty())
    return colors;
  // Smooth downscaling area-averages, so each output pixel is its cell's mean.
  const QImage cells = frame.copy(pixels)
                           .convertToFormat(QImage::Format_RGB32)
                           .scaled(cols, rows, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
  colors.reserve(cols * rows);
  for (int y = 0; y < rows; ++y)
    for (int x = 0; x < cols; ++x)
      colors.append(QColor(cells.pixel(x, y)));
  return colors;
}

QColor backgroundTone(const QColor &color) {
  float h = 0, s = 0, l = 0;
  color.getHslF(&h, &s, &l);
  // Hue survives; lightness lands in the same dark band as artist palettes.
  const float tone = std::clamp(0.06f + l * 0.2f, 0.06f, 0.2f);
  const float saturation = std::min(s * 1.15f, 0.8f);
  return QColor::fromHslF(h < 0 ? 0 : h, saturation, tone);
}

} // namespace videoambient
