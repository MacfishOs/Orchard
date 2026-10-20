/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "lyrics_provider_settings.h"

#include <QVariantMap>

LyricsProviderSettings::LyricsProviderSettings(QObject *parent) : QObject(parent) {
  const QVariantList defaults{
      QVariantMap{{"id", "bini"}, {"name", "Bini Lyrics"}, {"enabled", true}},
      QVariantMap{{"id", "betterlyrics"}, {"name", "BetterLyrics"}, {"enabled", true}},
      QVariantMap{{"id", "lyricsplus"}, {"name", "LyricsPlus"}, {"enabled", true}},
      QVariantMap{{"id", "lrclib"}, {"name", "LRCLIB"}, {"enabled", true}},
      QVariantMap{{"id", "youtube"}, {"name", "YouTube Music"}, {"enabled", true}},
  };
  const QVariantList saved = m_settings.value(QStringLiteral("lyrics/providers")).toList();
  QStringList seen;
  for (const auto &entry : saved) {
    const auto value = entry.toMap();
    const QString id = value.value(QStringLiteral("id")).toString();
    if (seen.contains(id)) continue;
    for (const auto &item : defaults) {
      auto provider = item.toMap();
      if (provider.value(QStringLiteral("id")).toString() != id) continue;
      provider.insert(QStringLiteral("enabled"), value.value(QStringLiteral("enabled"), true).toBool());
      m_providers.append(provider);
      seen.append(id);
      break;
    }
  }
  for (const auto &item : defaults)
    if (!seen.contains(item.toMap().value(QStringLiteral("id")).toString())) m_providers.append(item);
}

QStringList LyricsProviderSettings::enabledProviders() const {
  QStringList result;
  for (const auto &entry : m_providers) {
    const auto provider = entry.toMap();
    if (provider.value(QStringLiteral("enabled")).toBool())
      result.append(provider.value(QStringLiteral("id")).toString());
  }
  return result;
}

QString LyricsProviderSettings::label(const QString &id) const {
  for (const auto &entry : m_providers) {
    const auto provider = entry.toMap();
    if (provider.value(QStringLiteral("id")).toString() == id)
      return provider.value(QStringLiteral("name")).toString();
  }
  return id;
}

void LyricsProviderSettings::setEnabled(const QString &id, bool enabled) {
  for (qsizetype index = 0; index < m_providers.size(); ++index) {
    auto provider = m_providers.at(index).toMap();
    if (provider.value(QStringLiteral("id")).toString() != id) continue;
    if (provider.value(QStringLiteral("enabled")).toBool() == enabled) return;
    provider.insert(QStringLiteral("enabled"), enabled);
    m_providers[index] = provider;
    save();
    return;
  }
}

void LyricsProviderSettings::moveProvider(int from, int to) {
  if (from < 0 || to < 0 || from >= m_providers.size() || to >= m_providers.size() || from == to) return;
  m_providers.move(from, to);
  save();
}

void LyricsProviderSettings::save() {
  m_settings.setValue(QStringLiteral("lyrics/providers"), m_providers);
  emit changed();
}
