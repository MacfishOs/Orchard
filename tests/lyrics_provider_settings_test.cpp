/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "lyrics/lyrics_provider_settings.h"

#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QVariantMap>

class LyricsProviderSettingsTest : public QObject {
  Q_OBJECT
  QTemporaryDir directory;

private slots:
  void initTestCase() {
    QVERIFY(directory.isValid());
    QCoreApplication::setOrganizationName(QStringLiteral("OrchardTests"));
    QCoreApplication::setApplicationName(QStringLiteral("LyricsProviderSettingsTest"));
    QSettings::setDefaultFormat(QSettings::IniFormat);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, directory.path());
  }

  void cleanup() { QSettings().clear(); }

  void defaultOrder() {
    LyricsProviderSettings settings;
    QCOMPARE(settings.enabledProviders(), (QStringList{"bini", "betterlyrics", "lyricsplus", "lrclib", "youtube"}));
    QCOMPARE(settings.label(QStringLiteral("betterlyrics")), QStringLiteral("BetterLyrics"));
  }

  void persistsOrderAndDisabledProviders() {
    {
      LyricsProviderSettings settings;
      settings.moveProvider(1, 0);
      settings.setEnabled(QStringLiteral("bini"), false);
      QSettings().sync();
    }
    LyricsProviderSettings loaded;
    QCOMPARE(loaded.providers().first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("betterlyrics"));
    QCOMPARE(loaded.enabledProviders(), (QStringList{"betterlyrics", "lyricsplus", "lrclib", "youtube"}));
    QVERIFY(!loaded.providers().at(1).toMap().value(QStringLiteral("enabled")).toBool());
    for (const auto &id : loaded.enabledProviders()) loaded.setEnabled(id, false);
    LyricsProviderSettings disabled;
    QVERIFY(disabled.enabledProviders().isEmpty());
  }

  void repairsUnknownAndDuplicateProviders() {
    QSettings().setValue(QStringLiteral("lyrics/providers"), QVariantList{
        QVariantMap{{"id", "unknown"}},
        QVariantMap{{"id", "betterlyrics"}, {"enabled", false}},
        QVariantMap{{"id", "betterlyrics"}, {"enabled", true}},
    });
    LyricsProviderSettings settings;
    QCOMPARE(settings.providers().size(), 5);
    QCOMPARE(settings.providers().first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("betterlyrics"));
    QVERIFY(!settings.enabledProviders().contains(QStringLiteral("betterlyrics")));
    const auto original = settings.providers();
    settings.moveProvider(-1, 0);
    settings.moveProvider(0, 5);
    settings.setEnabled(QStringLiteral("unknown"), false);
    QCOMPARE(settings.providers(), original);
  }
};

QTEST_GUILESS_MAIN(LyricsProviderSettingsTest)
#include "lyrics_provider_settings_test.moc"
