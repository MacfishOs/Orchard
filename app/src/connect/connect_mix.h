/* Copyright (C) 2026 SFG545. Licensed under the PolyForm Shield License 1.0.0, see LICENSE-POLYFORM-SHIELD. */
#pragma once
#include "playback/adaptive_mix/adaptive_mix_worker.h"
#include "playback/audio_stream_proxy.h"
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <functional>

// Remote Smart Crossfade for a Connect target (spec: Mix Host). The target uploads both songs'
// encoded bytes as AudioChunk streams, this desktop's adaptive-mix worker plans and renders the
// pair, and the overlap goes back as a PCM stream stamped with the target's own media time.
// The target keeps the clock, the output and the final say over when the splice plays.
class ConnectMixHost final : public QObject {
  Q_OBJECT
public:
  using Respond = std::function<void(const QString &id, bool ok, const QJsonObject &result, const QString &error)>;
  // Returns the stream id, or empty when the core refused the stream.
  using SendStream = std::function<QString(const QString &sessionId, const QJsonObject &meta, const QByteArray &payload)>;
  ConnectMixHost(Respond respond, SendStream send, QObject *parent = nullptr);
  // A finished "source" stream whose meta names {mix, role: outgoing|incoming}.
  void acceptSource(const QString &sessionId, const QJsonObject &header, const QByteArray &bytes);
  // MixPrepare: {mix, request, codecs}. Answers once both sources are here and rendered.
  void prepare(const QString &id, const QString &sessionId, const QJsonObject &params);
  void dropSession(const QString &sessionId);

private:
  struct Job {
    QString sessionId;
    QString rpcId;
    QJsonObject request;
    QStringList codecs;
    QByteArray outgoing;
    QByteArray incoming;
    quint64 serial{0};
  };
  Job &job(const QString &mixId, const QString &sessionId);
  void startNext();
  void finish(const QJsonObject &header, const QByteArray &pcm);
  void abandon(const QString &error);
  AdaptiveMixWorker m_worker;
  AudioStreamProxy m_outgoingProxy;
  AudioStreamProxy m_incomingProxy;
  QHash<QString, Job> m_jobs;
  QString m_running;
  quint64 m_serial{0};
  Respond m_respond;
  SendStream m_send;
};
