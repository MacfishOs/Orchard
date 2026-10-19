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

#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTest>

class PageSessions : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool isSignedIn MEMBER signedIn NOTIFY statusChanged)
  Q_PROPERTY(QString status MEMBER appleStatus NOTIFY changed)
  Q_PROPERTY(QString homeSource MEMBER source NOTIFY homeSourceChanged)

public:
  bool signedIn{false};
  QString appleStatus{QStringLiteral("restoring")};
  QString source{QStringLiteral("apple_music")};
  QVariantMap saved;
  int reads{0};
  int writes{0};

  Q_INVOKABLE QVariantMap restoredPage() {
    ++reads;
    return saved;
  }

  Q_INVOKABLE void savePage(const QVariantMap &page) {
    ++writes;
    saved = page;
  }

signals:
  void statusChanged();
  void changed();
  void homeSourceChanged();
};

struct PageMemoryHarness {
  PageSessions sessions;
  QQmlEngine engine;
  QQmlComponent component{&engine};
  QScopedPointer<QObject> root;

  void create() {
    auto *context = engine.rootContext();
    for (const auto *name : {"OrchardAuth", "OrchardAppleMusic", "OrchardHome", "OrchardPlayback"})
      context->setContextProperty(QString::fromLatin1(name), &sessions);
    component.loadUrl(QUrl::fromLocalFile(QStringLiteral(
        ORCHARD_SOURCE_DIR "/app/qml/views/home/PageMemory.qml")));
    root.reset(component.create());
  }
};

class PageMemoryTest : public QObject {
  Q_OBJECT

private slots:
  void initTestCase() {
    qmlRegisterModule("Orchard", 1, 0);
  }

  void waitsForBothRestores_data() {
    QTest::addColumn<QString>("page");
    QTest::addColumn<bool>("authFirst");
    QTest::addColumn<QString>("appleStatus");
    for (const auto *page : {"artist", "album", "playlist", "search"}) {
      for (const bool authFirst : {true, false}) {
        for (const auto *status : {"connected", "disconnected"}) {
          const QByteArray name = QByteArray(page) + (authFirst ? "-auth-first-" : "-apple-first-") + status;
          QTest::newRow(name.constData()) << QString::fromLatin1(page) << authFirst << QString::fromLatin1(status);
        }
      }
    }
  }

  void waitsForBothRestores() {
    QFETCH(QString, page);
    QFETCH(bool, authFirst);
    QFETCH(QString, appleStatus);
    PageMemoryHarness harness;
    const QVariantMap saved{
        {"page", page}, {"item", QVariantMap{{"browseId", "am.artists.123"}}},
        {"query", "BLACKPINK"}, {"filter", "artists"}};
    harness.sessions.saved = saved;
    harness.create();
    QVERIFY2(harness.root, qPrintable(harness.component.errorString()));
    QSignalSpy restored(harness.root.data(), SIGNAL(restoreRequested(QVariant)));
    QVERIFY(restored.isValid());

    if (authFirst)
      harness.sessions.setProperty("isSignedIn", true);
    else
      harness.sessions.setProperty("status", appleStatus);
    QTest::qWait(1);
    QCOMPARE(restored.count(), 0);
    QCOMPARE(harness.sessions.reads, 0);
    QVERIFY(!harness.root->property("restored").toBool());

    if (authFirst)
      harness.sessions.setProperty("status", appleStatus);
    else
      harness.sessions.setProperty("isSignedIn", true);
    QTRY_COMPARE(restored.count(), 1);
    QCOMPARE(restored.at(0).at(0).toMap(), saved);
    QCOMPARE(harness.sessions.reads, 1);

    emit harness.sessions.statusChanged();
    emit harness.sessions.changed();
    emit harness.sessions.homeSourceChanged();
    QTest::qWait(1);
    QCOMPARE(restored.count(), 1);
    QCOMPARE(harness.sessions.reads, 1);
  }

  void restoresWhenAlreadySettled_data() {
    QTest::addColumn<QString>("source");
    QTest::addColumn<QString>("appleStatus");
    QTest::newRow("apple-connected") << QString("apple_music") << QString("connected");
    QTest::newRow("apple-disconnected") << QString("apple_music") << QString("disconnected");
    QTest::newRow("youtube-apple-still-restoring") << QString("youtube") << QString("restoring");
  }

  void restoresWhenAlreadySettled() {
    QFETCH(QString, source);
    QFETCH(QString, appleStatus);
    PageMemoryHarness harness;
    harness.sessions.signedIn = true;
    harness.sessions.source = source;
    harness.sessions.appleStatus = appleStatus;
    harness.sessions.saved = {{"page", "library"}};
    harness.create();
    QVERIFY2(harness.root, qPrintable(harness.component.errorString()));
    QSignalSpy restored(harness.root.data(), SIGNAL(restoreRequested(QVariant)));
    QCOMPARE(restored.count(), 0);
    QTRY_COMPARE(restored.count(), 1);
    QCOMPARE(harness.sessions.reads, 1);
  }

  void switchingSourceReleasesPendingRestore() {
    PageMemoryHarness harness;
    harness.sessions.signedIn = true;
    harness.sessions.saved = {{"page", "search"}, {"query", "BLACKPINK"}};
    harness.create();
    QVERIFY2(harness.root, qPrintable(harness.component.errorString()));
    QSignalSpy restored(harness.root.data(), SIGNAL(restoreRequested(QVariant)));
    QTest::qWait(1);
    QCOMPARE(restored.count(), 0);
    harness.sessions.setProperty("homeSource", "youtube");
    QTRY_COMPARE(restored.count(), 1);
  }

  void preservesSavedPageWhileWaiting() {
    PageMemoryHarness harness;
    harness.sessions.signedIn = true;
    const QVariantMap saved{{"page", "artist"}, {"item", QVariantMap{{"browseId", "am.artists.123"}}}};
    harness.sessions.saved = saved;
    harness.create();
    QVERIFY2(harness.root, qPrintable(harness.component.errorString()));
    harness.root->setProperty("page", "home");
    harness.root->setProperty("query", "startup");
    QTest::qWait(350);
    QCOMPARE(harness.sessions.writes, 0);
    QCOMPARE(harness.sessions.saved, saved);

    harness.sessions.setProperty("status", "connected");
    QTRY_VERIFY(harness.root->property("restored").toBool());
    harness.root->setProperty("page", "search");
    harness.root->setProperty("query", "BLACKPINK");
    QTRY_COMPARE(harness.sessions.writes, 1);
    QCOMPARE(harness.sessions.saved.value("page").toString(), QString("search"));
    QCOMPARE(harness.sessions.saved.value("query").toString(), QString("BLACKPINK"));
  }

  void rechecksSessionBeforeDeferredRestore() {
    PageMemoryHarness harness;
    harness.sessions.appleStatus = QStringLiteral("connected");
    harness.sessions.saved = {{"page", "artist"}};
    harness.create();
    QVERIFY2(harness.root, qPrintable(harness.component.errorString()));
    QSignalSpy restored(harness.root.data(), SIGNAL(restoreRequested(QVariant)));
    harness.sessions.setProperty("isSignedIn", true);
    harness.sessions.setProperty("isSignedIn", false);
    QTest::qWait(1);
    QCOMPARE(restored.count(), 0);
    harness.sessions.setProperty("isSignedIn", true);
    QTRY_COMPARE(restored.count(), 1);
  }
};

QTEST_GUILESS_MAIN(PageMemoryTest)
#include "page_memory_test.moc"
