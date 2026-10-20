/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QVariantList>

class LyricsProviderSettings final : public QObject {
  Q_OBJECT
  Q_PROPERTY(QVariantList providers READ providers NOTIFY changed)

public:
  explicit LyricsProviderSettings(QObject *parent = nullptr);
  QVariantList providers() const { return m_providers; }
  QStringList enabledProviders() const;
  Q_INVOKABLE void setEnabled(const QString &id, bool enabled);
  Q_INVOKABLE void moveProvider(int from, int to);
  Q_INVOKABLE QString label(const QString &id) const;

signals:
  void changed();

private:
  void save();
  QSettings m_settings;
  QVariantList m_providers;
};
