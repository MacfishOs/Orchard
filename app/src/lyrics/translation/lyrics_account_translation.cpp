/* Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
#include "lyrics_translator.h"
#include "remote_translation.h"
#include "account/orchard_account.h"
#include "lyrics/lyrics_controller.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QTimer>

void LyricsTranslator::setAccount(OrchardAccount *account) {
  if (m_account) disconnect(m_account, nullptr, this, nullptr);
  m_account = account;
  if (account) connect(account, &OrchardAccount::statusChanged, this, [this] {
    if (m_provider != QStringLiteral("orchard")) return;
    ++*m_generation;
    cancelRemote();
    m_key.clear();
    sync();
  });
  if (m_provider == QStringLiteral("orchard")) { m_key.clear(); sync(); }
}

void LyricsTranslator::runAccountRemote() {
  if (!m_account || !m_account->isSignedIn()) {
    setStatus(QStringLiteral("failed"), tr("Sign in to Orchard to translate lyrics."));
    return;
  }
  QStringList texts;
  for (const QString &text : std::as_const(m_texts))
    if (!text.isEmpty() && !texts.contains(text)) texts.append(text);
  if (texts.isEmpty()) { setStatus(QStringLiteral("ready")); return; }
  const int generation = m_generation->load();
  const QString songId = m_lyrics->trackId();
  QPointer<LyricsTranslator> guard(this);
  m_account->withAccessToken([guard, generation, songId, texts](const QString &token) {
    if (!guard || generation != guard->m_generation->load()) return;
    auto *self = guard.data();
    if (token.isEmpty()) {
      self->setStatus(QStringLiteral("failed"), self->tr("Sign in to Orchard again."));
      return;
    }
    QNetworkRequest request(self->m_account->serviceUrl().resolved(QUrl(QStringLiteral("/lyrics/translate"))));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    request.setTransferTimeout(130000);
    QJsonArray input;
    for (const QString &text : texts) input.append(text);
    const QJsonObject payload{{QStringLiteral("song_id"), songId}, {QStringLiteral("lines"), input}};
    auto *reply = self->m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    self->m_reply = reply;
    // Qt's transfer timeout is an inactivity timeout; this bounds total wait too.
    QTimer::singleShot(130000, reply, [reply] { if (!reply->isFinished()) reply->abort(); });
    self->setStatus(QStringLiteral("translating"), self->tr("Translating with Orchard Account"));
    connect(reply, &QNetworkReply::finished, self, [self, reply, generation, texts] {
      if (reply != self->m_reply || generation != self->m_generation->load()) { reply->deleteLater(); return; }
      self->m_reply = nullptr;
      const QByteArray body = reply->readAll();
      const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
      const auto error = reply->error();
      reply->deleteLater();
      if (error != QNetworkReply::NoError || http >= 300) {
        const QString code = QJsonDocument::fromJson(body).object().value(QStringLiteral("error")).toString();
        const bool timedOut = error == QNetworkReply::TimeoutError || error == QNetworkReply::OperationCanceledError || http == 504;
        const QString message = timedOut ? self->tr("Translation took too long. Try again.")
            : code == QStringLiteral("translation_busy") ? self->tr("Translation is busy. Try again shortly.")
            : code == QStringLiteral("translation_invalid_result") ? self->tr("The model returned invalid lyric lines. Try again.")
            : http == 429 ? self->tr("The account or IP has reached 10 songs today. Resets at 00:00 UTC.")
            : http == 409 ? self->tr("This song is being translated. Try again shortly.")
            : http == 401 ? self->tr("Sign in to Orchard again.")
            : self->tr("Account translation failed. Try again later.");
        self->setStatus(QStringLiteral("failed"), message);
        return;
      }
      const QStringList outputs = parseRemoteTranslation(body, QStringLiteral("orchard"), texts.size());
      if (outputs.size() != texts.size()) {
        self->setStatus(QStringLiteral("failed"), self->tr("The translation returned an invalid number of lines."));
        return;
      }
      for (qsizetype i = 0; i < texts.size(); ++i)
        for (const int index : self->m_pending.take(texts.at(i)))
          self->m_lines[index] = texts.at(i).simplified().compare(outputs.at(i).simplified(), Qt::CaseInsensitive) == 0
              ? QString() : outputs.at(i);
      self->setStatus(QStringLiteral("ready"), self->tr("Translated with Orchard Account"));
    });
  });
}
