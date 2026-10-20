/* Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#pragma once

namespace UiScaling {
constexpr double minimum = 0.75;
constexpr double maximum = 2.5;
double savedScale();
// Call after setting the application identity, before constructing QApplication.
void configure();
}
