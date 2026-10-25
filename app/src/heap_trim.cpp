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

#include "heap_trim.h"

#include <QObject>
#include <QQmlEngine>
#include <QTimer>

#if defined(__GLIBC__)
#include <malloc.h>
#endif

void startHeapTrim(QObject *owner, QQmlEngine *engine) {
#if defined(__GLIBC__)
  mallopt(M_TRIM_THRESHOLD, 64 * 1024);
  mallopt(M_MMAP_THRESHOLD, 64 * 1024);

  auto *timer = new QTimer(owner);
  timer->setInterval(3000);
  timer->setTimerType(Qt::CoarseTimer);
  QObject::connect(timer, &QTimer::timeout, owner, [engine] {
    if (engine) {
      engine->collectGarbage();
    }
    malloc_trim(0);
  });
  timer->start();
#else
  Q_UNUSED(owner);
  Q_UNUSED(engine);
#endif
}
