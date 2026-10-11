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

#include "appearance/video_ambient.h"
#include <QPainter>
#include <QTest>

class VideoAmbientTest : public QObject {
  Q_OBJECT

private slots:
  void averagesEachCell() {
    QImage image(300, 300, QImage::Format_RGB32);
    image.fill(Qt::black);
    QPainter painter(&image);
    painter.fillRect(QRect(0, 0, 100, 100), Qt::red);
    painter.fillRect(QRect(200, 200, 100, 100), Qt::blue);
    painter.end();
    const QList<QColor> cells = videoambient::grid(image, {}, 3, 3);
    QCOMPARE(cells.size(), 9);
    QVERIFY(cells[0].red() > 200 && cells[0].blue() < 40);
    QVERIFY(cells[8].blue() > 200 && cells[8].red() < 40);
    QVERIFY(cells[4].value() < 40);
  }

  void cropSkipsBars() {
    // Black bars top and bottom; the picture between them is green.
    QImage image(300, 300, QImage::Format_RGB32);
    image.fill(Qt::black);
    QPainter(&image).fillRect(QRect(0, 60, 300, 180), Qt::green);
    const QList<QColor> cells = videoambient::grid(image, QRectF(0, 0.2, 1, 0.6), 3, 3);
    QVERIFY(cells[0].green() > 200);
    QVERIFY(cells[8].green() > 200);
  }

  void tonesStayDarkAndKeepHue() {
    const QColor white = videoambient::backgroundTone(Qt::white);
    QVERIFY(white.lightnessF() <= 0.21);
    const QColor red = videoambient::backgroundTone(QColor(230, 40, 40));
    QVERIFY(red.lightnessF() <= 0.21);
    QVERIFY(red.lightnessF() >= 0.05);
    QVERIFY(red.red() > red.green() && red.red() > red.blue());
  }

  void emptyFrameGivesNothing() {
    QVERIFY(videoambient::grid(QImage(), {}, 3, 3).isEmpty());
  }
};

QTEST_MAIN(VideoAmbientTest)
#include "video_ambient_test.moc"
