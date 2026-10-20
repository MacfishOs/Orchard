/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <QObject>
#include <QSettings>
#include <memory>

class StartupSettings final : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool available READ available CONSTANT)
  Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
  Q_PROPERTY(QString error READ error NOTIFY changed)

public:
  explicit StartupSettings(QObject *parent = nullptr);
  StartupSettings(const QString &launcher, std::unique_ptr<QSettings> registration,
                  QObject *parent = nullptr);

  bool available() const { return m_registration != nullptr; }
  bool enabled() const { return m_enabled; }
  QString error() const { return m_error; }
  Q_INVOKABLE void setEnabled(bool enabled);

signals:
  void changed();

private:
  QString m_command;
  std::unique_ptr<QSettings> m_registration;
  QString m_error;
  bool m_enabled = false;
};
