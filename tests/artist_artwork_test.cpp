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

#include "appearance/video_ambient.h"

#include <QFile>
#include <QJSEngine>
#include <QTest>

namespace {
bool load(QJSEngine &engine, const char *name) {
  const QByteArray relative = QByteArray("../app/qml/components/detail/") + name;
  QFile file(QTest::qFindTestData(relative.constData(), __FILE__, __LINE__));
  if (!file.open(QIODevice::ReadOnly))
    return false;
  QString source = QString::fromUtf8(file.readAll());
  source.remove(QStringLiteral(".pragma library"));
  return !engine.evaluate(source, file.fileName()).isError();
}
} // namespace

class ArtistArtworkTest : public QObject {
  Q_OBJECT

private slots:
  void choosesH264AtTheRequiredSize() {
    QJSEngine engine;
    QVERIFY(load(engine, "hlsVariant.js"));
    const QString master = QStringLiteral(
        "#EXTM3U\n"
        "#EXT-X-STREAM-INF:CODECS=\"avc1.64001f\",RESOLUTION=1280x720,BANDWIDTH=2000000\n720.m3u8\n"
        "#EXT-X-STREAM-INF:CODECS=\"hvc1.2\",RESOLUTION=1920x1080,BANDWIDTH=6000000\nhevc.m3u8\n"
        "#EXT-X-STREAM-INF:CODECS=\"avc1.640028\",RESOLUTION=1920x1080,BANDWIDTH=4000000\n1080.m3u8\n"
        "#EXT-X-STREAM-INF:CODECS=\"avc1.640028\",RESOLUTION=1920x1080,BANDWIDTH=5000000\nrich.m3u8\n"
        "#EXT-X-STREAM-INF:CODECS=\"avc1.640028\",VIDEO-RANGE=PQ,RESOLUTION=1920x1080,BANDWIDTH=8000000\nhdr.m3u8\n");
    const auto pick = engine.globalObject().property("pick");
    const QString base = QStringLiteral("https://example.com/art/master.m3u8");
    QCOMPARE(pick.call({master, base, 600}).toString(), QString("https://example.com/art/720.m3u8"));
    for (const int height : {900, 2160})
      QCOMPARE(pick.call({master, base, height}).toString(), QString("https://example.com/art/rich.m3u8"));
  }

  void resolvesTheCompleteFileFromByteRanges() {
    QJSEngine engine;
    QVERIFY(load(engine, "hlsVariant.js"));
    const QString media = QStringLiteral(
        "#EXTM3U\n#EXT-X-MAP:URI=\"clip.mp4\",BYTERANGE=\"879@0\"\n"
        "#EXTINF:5.06667,\n#EXT-X-BYTERANGE:6414679@879\nclip.mp4\n"
        "#EXTINF:5.23333,\n#EXT-X-BYTERANGE:5681274@6415558\nclip.mp4\n"
        "#EXTINF:4.5,\n#EXT-X-BYTERANGE:5290749@12096832\nclip.mp4\n#EXT-X-ENDLIST\n");
    const QString base = QStringLiteral("https://example.com/art/media.m3u8");
    const auto resolve = engine.globalObject().property("mediaSource");
    QCOMPARE(resolve.call({media, base}).toString(), QString("https://example.com/art/clip.mp4"));
    for (const QString &playlist : {
             QString(media).remove("#EXT-X-ENDLIST"),
             QString(media).replace("#EXTM3U", "#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"key\""),
             QString(media).replace("#EXTINF:4.5,", "#EXT-X-MAP:URI=\"other.mp4\"\n#EXTINF:4.5,"),
             QString("#EXTM3U\n#EXTINF:5,\nfirst.mp4\n#EXTINF:5,\nlast.mp4\n#EXT-X-ENDLIST"),
             QString("#EXTM3U\n#EXT-X-MAP:URI=\"clip.mp4\"\n#EXT-X-ENDLIST")})
      QCOMPARE(resolve.call({playlist, base}).toString(), base);
  }

  void resolvesRelativeMediaUrls() {
    QJSEngine engine;
    QVERIFY(load(engine, "hlsVariant.js"));
    const auto resolve = engine.globalObject().property("resolve");
    const QString base = QStringLiteral("https://example.com/art/variants/media.m3u8?token=old");
    QCOMPARE(resolve.call({"../clip.mp4?token=a/../b", base}).toString(),
             QString("https://example.com/art/clip.mp4?token=a/../b"));
    QCOMPARE(resolve.call({"/clip.mp4", base}).toString(), QString("https://example.com/clip.mp4"));
    QCOMPARE(resolve.call({"//cdn.example/clip.mp4", base}).toString(), QString("https://cdn.example/clip.mp4"));
  }

  void posterAndVideoUseTheSameTone() {
    QJSEngine engine;
    QVERIFY(load(engine, "heroTint.js"));
    const auto pageRgb = engine.globalObject().property("pageRgb");
    for (const char *hex : {"a6abb4", "ffffff", "000000", "00ffff", "ff0000", "0e111c"}) {
      const QColor color(QString("#") + QLatin1String(hex));
      const QColor expected = videoambient::artistTone(color);
      const auto rgb = pageRgb.call({QString::fromLatin1(hex)});
      QCOMPARE(rgb.property(0).toInt(), expected.red());
      QCOMPARE(rgb.property(1).toInt(), expected.green());
      QCOMPARE(rgb.property(2).toInt(), expected.blue());
    }
    QVERIFY(pageRgb.call({"not-a-color"}).isNull());
    QVERIFY(pageRgb.call({""}).isNull());
  }
};

QTEST_GUILESS_MAIN(ArtistArtworkTest)
#include "artist_artwork_test.moc"
