/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "startup_settings.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>

namespace {

QString launcherPath() {
  const QString bootstrapper = qEnvironmentVariable("ORCHARD_BOOTSTRAPPER");
  if (!bootstrapper.isEmpty() && QFileInfo::exists(bootstrapper))
    return QFileInfo(bootstrapper).absoluteFilePath();
  return QCoreApplication::applicationFilePath();
}

std::unique_ptr<QSettings> registration() {
#ifdef Q_OS_WIN
  return std::make_unique<QSettings>(
      QStringLiteral("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"),
      QSettings::NativeFormat);
#else
  return nullptr;
#endif
}

} // namespace

StartupSettings::StartupSettings(QObject *parent)
    : StartupSettings(launcherPath(), registration(), parent) {}

StartupSettings::StartupSettings(const QString &launcher,
                                 std::unique_ptr<QSettings> registration,
                                 QObject *parent)
    : QObject(parent),
      m_command(QStringLiteral("\"%1\"").arg(QDir::toNativeSeparators(launcher))),
      m_registration(std::move(registration)) {
  m_enabled = available() &&
              m_registration->value(QStringLiteral("Orchard")).toString() == m_command;
}

void StartupSettings::setEnabled(bool value) {
  if (!available())
    return;
  // QSettings retains its first error, so retries need a fresh handle.
  m_registration = std::make_unique<QSettings>(m_registration->fileName(), m_registration->format());
  m_error.clear();
  if (value)
    m_registration->setValue(QStringLiteral("Orchard"), m_command);
  else if (m_registration->value(QStringLiteral("Orchard")).toString() == m_command)
    m_registration->remove(QStringLiteral("Orchard"));
  m_registration->sync();
  if (m_registration->status() != QSettings::NoError)
    m_error = tr("Could not change Windows startup. Check that your account can change startup apps.");
  else
    m_enabled = value;
  emit changed();
}
