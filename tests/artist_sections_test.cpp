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

#include "album/album_controller.h"
#include "auth/auth_manager.h"
#include "providers/runtime/provider_runtime.h"
#include "providers/youtube/catalog/youtube_catalog.h"
#include "providers/youtube/youtube_provider.h"

#include <QJsonArray>
#include <QSignalSpy>
#include <QTest>

namespace {
QVariantMap shelf(const QString &id) {
  return {{"title", id}, {"items", QVariantList{QVariantMap{{"browseId", "preview"}}}},
          {"browsePayload", QVariantMap{{"browseId", id}, {"params", "shelf-params"}}}};
}

struct Harness {
  YouTubeProvider provider;
  YouTubeCatalog catalog{&provider};
  AuthManager auth{&provider};
  AlbumController artist{&catalog, &auth, nullptr, true};
  ProviderRuntime *runtime{provider.findChild<ProviderRuntime *>()};
  QList<QVariantList> requests;

  Harness() {
    QObject::disconnect(runtime, &ProviderRuntime::invokeRequested, nullptr, nullptr);
    requests.clear();
    QObject::connect(runtime, &ProviderRuntime::invokeRequested, &artist,
                     [this](quint64 id, const QString &method, const QJsonValue &payload) {
                       requests.append({QVariant::fromValue(id), method, QVariant::fromValue(payload)});
                     });
  }

  quint64 requestId() const { return requests.last().at(0).toULongLong(); }
};
} // namespace

class ArtistSectionsTest : public QObject {
  Q_OBJECT
private slots:
  void loadsFullShelfThroughProvider() {
    Harness h;
    const auto section = shelf("Live Albums");
    h.artist.openSection(section);
    QVERIFY(h.artist.sectionLoading());
    QCOMPARE(h.artist.expandedSection(), section);
    QCOMPARE(h.requests.size(), 1);
    QCOMPARE(h.requests.last().at(1).toString(), QString("catalog.browse"));
    const auto payload = h.requests.last().at(2).value<QJsonValue>().toObject();
    QCOMPARE(payload.value("browseId").toString(), QString("Live Albums"));
    QCOMPARE(payload.value("params").toString(), QString("shelf-params"));
    const QJsonArray items{QJsonObject{{"browseId", "one"}}, QJsonObject{{"browseId", "two"}}};
    emit h.provider.resultReady(h.requestId(), QJsonObject{{"sections", QJsonArray{
        QJsonObject{{"items", items}}}}});
    QVERIFY(!h.artist.sectionLoading());
    QCOMPARE(h.artist.expandedSection().value("items").toList(), items.toVariantList());
    QCOMPARE(h.artist.expandedSection().value("title").toString(), QString("Live Albums"));
  }

  void staleResponsesCannotReplaceAnotherShelf() {
    Harness h;
    h.artist.openSection(shelf("Albums"));
    const auto first = h.requestId();
    h.artist.openSection(shelf("Live Albums"));
    const auto second = h.requestId();
    emit h.provider.resultReady(first, QJsonObject{{"sections", QJsonArray{}}});
    QVERIFY(h.artist.sectionLoading());
    QCOMPARE(h.artist.expandedSection(), shelf("Live Albums"));
    h.artist.closeSection();
    emit h.provider.resultReady(second, QJsonObject{{"sections", QJsonArray{}}});
    QVERIFY(h.artist.expandedSection().isEmpty());
    QVERIFY(!h.artist.sectionLoading());
  }

  void failureRetainsPreviewAndCanRetry() {
    Harness h;
    const auto section = shelf("Albums");
    h.artist.openSection(section);
    emit h.provider.requestFailed(h.requestId(), "Unavailable");
    QCOMPARE(h.artist.expandedSection(), section);
    QCOMPARE(h.artist.sectionError(), QString("Unavailable"));
    QVERIFY(!h.artist.sectionLoading());
    h.artist.retrySection();
    QCOMPARE(h.requests.size(), 2);
    QCOMPARE(h.artist.expandedSection(), section);
    QVERIFY(h.artist.sectionLoading());
    QVERIFY(h.artist.sectionError().isEmpty());
    h.artist.clear();
    emit h.provider.requestFailed(h.requestId(), "Too late");
    QVERIFY(h.artist.expandedSection().isEmpty());
    QVERIFY(h.artist.sectionError().isEmpty());
  }

  void completeShelfNeedsNoRequest() {
    Harness h;
    auto section = shelf("Albums");
    section.remove("browsePayload");
    h.artist.openSection(section);
    QCOMPARE(h.artist.expandedSection(), section);
    QVERIFY(!h.artist.sectionLoading());
    QVERIFY(h.requests.isEmpty());
  }
};

QTEST_GUILESS_MAIN(ArtistSectionsTest)
#include "artist_sections_test.moc"
