/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "startup_settings.h"

#include <QDir>
#include <QTemporaryDir>
#include <QUuid>
#include <QtTest>

class StartupSettingsTest : public QObject {
  Q_OBJECT

private slots:
#ifdef Q_OS_WIN
  void nativeRegistrationRoundTrip() {
    const QString key = QStringLiteral("HKEY_CURRENT_USER\\Software\\OrchardTests\\%1")
                            .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const QString launcher = QStringLiteral("C:/Music Apps/Orchárd.exe");
    StartupSettings startup(launcher, std::make_unique<QSettings>(key, QSettings::NativeFormat));
    startup.setEnabled(true);
    const bool enabled = startup.enabled();
    const QString error = startup.error();
    QSettings stored(key, QSettings::NativeFormat);
    const QString command = stored.value(QStringLiteral("Orchard")).toString();
    startup.setEnabled(false);
    stored.sync();
    const bool removed = !stored.contains(QStringLiteral("Orchard"));
    stored.clear();
    stored.sync();
    QVERIFY(enabled);
    QVERIFY(error.isEmpty());
    QCOMPARE(command, QStringLiteral("\"C:\\Music Apps\\Orchárd.exe\""));
    QVERIFY(removed);
  }
#endif

  void enableDisableAndPersist() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("run.ini"));
    const QString launcher = directory.filePath(QStringLiteral("Music Apps/Orchárd.exe"));
    QSettings stored(path, QSettings::IniFormat);
    stored.setValue(QStringLiteral("AnotherApp"), QStringLiteral("keep.exe"));
    stored.sync();

    StartupSettings startup(launcher, std::make_unique<QSettings>(path, QSettings::IniFormat));
    QVERIFY(startup.available());
    QVERIFY(!startup.enabled());
    QSignalSpy changed(&startup, &StartupSettings::changed);
    startup.setEnabled(true);
    QVERIFY(startup.enabled());
    QVERIFY(startup.error().isEmpty());
    QCOMPARE(changed.size(), 1);
    stored.sync();
    QCOMPARE(stored.value(QStringLiteral("Orchard")).toString(),
             QStringLiteral("\"%1\"").arg(QDir::toNativeSeparators(launcher)));

    StartupSettings reopened(launcher, std::make_unique<QSettings>(path, QSettings::IniFormat));
    QVERIFY(reopened.enabled());
    reopened.setEnabled(false);
    QVERIFY(!reopened.enabled());
    stored.sync();
    QVERIFY(!stored.contains(QStringLiteral("Orchard")));
    QCOMPARE(stored.value(QStringLiteral("AnotherApp")).toString(), QStringLiteral("keep.exe"));
  }

  void preserveOtherInstallation() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("run.ini"));
    QSettings stored(path, QSettings::IniFormat);
    stored.setValue(QStringLiteral("Orchard"), QStringLiteral("\"other/Orchard.exe\""));
    stored.sync();
    StartupSettings startup(QStringLiteral("this/Orchard.exe"),
                            std::make_unique<QSettings>(path, QSettings::IniFormat));
    QVERIFY(!startup.enabled());
    startup.setEnabled(false);
    stored.sync();
    QCOMPARE(stored.value(QStringLiteral("Orchard")).toString(), QStringLiteral("\"other/Orchard.exe\""));
  }

  void reportWriteFailure() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("blocked"));
    QVERIFY(QDir().mkpath(path));
    StartupSettings startup(QStringLiteral("Orchard.exe"),
                            std::make_unique<QSettings>(path, QSettings::IniFormat));
    startup.setEnabled(true);
    QVERIFY(!startup.enabled());
    QVERIFY(!startup.error().isEmpty());
    QVERIFY(QDir().rmdir(path));
    startup.setEnabled(true);
    QVERIFY(startup.enabled());
    QVERIFY(startup.error().isEmpty());
  }

  void unsupportedPlatform() {
    StartupSettings startup(QStringLiteral("Orchard"), nullptr);
    QVERIFY(!startup.available());
    startup.setEnabled(true);
    QVERIFY(!startup.enabled());
  }
};

QTEST_GUILESS_MAIN(StartupSettingsTest)
#include "startup_settings_test.moc"
