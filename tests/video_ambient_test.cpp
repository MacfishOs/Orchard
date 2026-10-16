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

  void samplingMatchesOwnedCrop() {
    for (const auto format : {QImage::Format_RGB32, QImage::Format_ARGB32,
                              QImage::Format_ARGB32_Premultiplied, QImage::Format_RGBX8888,
                              QImage::Format_RGBA8888, QImage::Format_RGBA8888_Premultiplied,
                              QImage::Format_RGB30, QImage::Format_A2RGB30_Premultiplied,
                              QImage::Format_BGR30, QImage::Format_A2BGR30_Premultiplied,
                              QImage::Format_CMYK8888, QImage::Format_RGB888}) {
      QImage image(301, 199, format);
      for (int y = 0; y < image.height(); ++y)
        for (int x = 0; x < image.width(); ++x)
          image.setPixelColor(x, y, QColor((x * 7) % 256, (y * 11) % 256,
                                          (x + y * 3) % 256, (x * y) % 256));
      for (const QRectF crop : {QRectF(), QRectF(0.13, 0.21, 0.73, 0.61),
                                QRectF(-0.1, 0, 1.2, 1), QRectF(0.99, 0.99, 0.01, 0.01)}) {
        const QRectF area = crop.isNull() ? QRectF(0, 0, 1, 1) : crop;
        const QRect pixels = QRect(qRound(area.x() * image.width()), qRound(area.y() * image.height()),
                                    qRound(area.width() * image.width()), qRound(area.height() * image.height()))
                                  .intersected(image.rect());
        const QImage reference = image.copy(pixels).convertToFormat(QImage::Format_RGB32)
                                      .scaled(3, 3, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        QList<QColor> expected;
        for (int y = 0; y < 3; ++y)
          for (int x = 0; x < 3; ++x)
            expected.append(QColor(reference.pixel(x, y)));
        QCOMPARE(videoambient::grid(image, crop, 3, 3), expected);
      }
    }
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
    QVERIFY(videoambient::artistEdge(QImage(), {}).isEmpty());
  }

  void artistSamplesTheVisibleLowerEdge() {
    QImage image(300, 200, QImage::Format_RGB32);
    image.fill(Qt::red);
    QPainter(&image).fillRect(QRect(60, 132, 180, 18), QColor(90, 150, 120));
    const auto colors = videoambient::artistEdge(image, QRectF(0.2, 0.25, 0.6, 0.5));
    QCOMPARE(colors.size(), 3);
    for (const QColor &color : colors)
      QCOMPARE(color, videoambient::artistTone(QColor(90, 150, 120)));
    QVERIFY(videoambient::artistEdge(image, QRectF(2, 2, 1, 1)).isEmpty());
  }

  void artistKeepsTheEdgeColorsAcrossThePage() {
    QImage image(300, 100, QImage::Format_RGB32);
    image.fill(Qt::white);
    QPainter painter(&image);
    painter.fillRect(QRect(0, 82, 100, 18), Qt::red);
    painter.fillRect(QRect(100, 82, 100, 18), Qt::green);
    painter.fillRect(QRect(200, 82, 100, 18), Qt::blue);
    painter.end();
    const auto colors = videoambient::artistEdge(image, {});
    QCOMPARE(colors, (QList<QColor>{videoambient::artistTone(Qt::red),
                                   videoambient::artistTone(Qt::green), videoambient::artistTone(Qt::blue)}));
    const QColor gray = videoambient::artistTone(QColor(166, 171, 180));
    QVERIFY(gray.red() > 95);
    QVERIFY(gray.blue() > gray.red());
    QCOMPARE(videoambient::artistTone(Qt::black).rgb(), QColor(Qt::black).rgb());
  }
};

QTEST_MAIN(VideoAmbientTest)
#include "video_ambient_test.moc"
