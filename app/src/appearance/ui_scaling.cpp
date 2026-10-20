/* Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#include "ui_scaling.h"

#include <QSettings>
#include <algorithm>
#include <cmath>

double UiScaling::savedScale() {
    bool ok = false;
    const double value = QSettings().value(QStringLiteral("appearance/uiScale"), 1.0).toDouble(&ok);
    return ok && std::isfinite(value) ? std::clamp(value, minimum, maximum) : 1.0;
}

void UiScaling::configure() {
    const double scale = savedScale();
    if (scale == 1.0)
        return;
    bool ok = false;
    const double environmentScale = qEnvironmentVariable("QT_SCALE_FACTOR").toDouble(&ok);
    const double base = ok && std::isfinite(environmentScale) && environmentScale > 0
        ? environmentScale : 1.0;
    // Qt combines this application preference with each monitor's native DPI.
    qputenv("QT_SCALE_FACTOR", QByteArray::number(base * scale, 'g', 12));
}
