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

#include "album/audiodb_artist.h"
#include <QTest>
#include <QVariantMap>

class AudioDbArtistTest : public QObject {
  Q_OBJECT

private slots:
  void readsArtworkAndFacts() {
    const AudioDbArtist artist = parseAudioDbArtist(QJsonObject{
        {QStringLiteral("strArtistFanart"), QStringLiteral("https://r2.theaudiodb.com/a.jpg")},
        {QStringLiteral("strGenre"), QStringLiteral("Indie Pop")},
        {QStringLiteral("strCountry"), QStringLiteral("London, UK")},
        {QStringLiteral("intFormedYear"), QStringLiteral("2015")}});
    QCOMPARE(artist.artwork, QStringLiteral("https://r2.theaudiodb.com/a.jpg"));
    QCOMPARE(artist.facts.size(), 3);
    QCOMPARE(artist.facts[0].toMap().value(QStringLiteral("key")).toString(), QStringLiteral("genre"));
    QCOMPARE(artist.facts[1].toMap().value(QStringLiteral("value")).toString(), QStringLiteral("London, UK"));
    QCOMPARE(artist.facts[2].toMap().value(QStringLiteral("value")).toString(), QStringLiteral("2015"));
  }

  void skipsBlankAndZeroFields() {
    const AudioDbArtist artist = parseAudioDbArtist(QJsonObject{
        {QStringLiteral("strArtistFanart"), QStringLiteral("not a url")},
        {QStringLiteral("strArtistBanner"), QStringLiteral("https://r2.theaudiodb.com/b.jpg")},
        {QStringLiteral("strGenre"), QStringLiteral("  ")},
        {QStringLiteral("intFormedYear"), QStringLiteral("0")}});
    QCOMPARE(artist.artwork, QStringLiteral("https://r2.theaudiodb.com/b.jpg"));
    QVERIFY(artist.facts.isEmpty());
  }

  void emptyRecordGivesNothing() {
    const AudioDbArtist artist = parseAudioDbArtist({});
    QVERIFY(artist.artwork.isEmpty());
    QVERIFY(artist.facts.isEmpty());
  }
};

QTEST_GUILESS_MAIN(AudioDbArtistTest)
#include "audiodb_artist_test.moc"
