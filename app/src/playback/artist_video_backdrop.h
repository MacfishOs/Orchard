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
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include "audio_stream_proxy.h"

#include <QJsonValue>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

class AuthManager;
class QVideoSink;
class YouTubeProvider;

// Resolves one music video into a picture-only stream for the artist page backdrop.
// Independent of playback, so the song that is playing keeps playing.
class ArtistVideoBackdrop final : public QObject {
  Q_OBJECT
  // Empty stops the stream and releases the proxy.
  Q_PROPERTY(QString videoId READ videoId WRITE setVideoId NOTIFY changed)
  Q_PROPERTY(QUrl source READ source NOTIFY changed)
  // "", "loading", "ready" or "error".
  Q_PROPERTY(QString status READ status NOTIFY changed)
  // Device pixels the picture covers vertically; picks the stream height. Only upgrades re-resolve.
  Q_PROPERTY(int targetHeight READ targetHeight WRITE setTargetHeight NOTIFY changed)
  // Dark background tones sampled from the playing picture, 3x3 row-major; empty until a frame arrives.
  Q_PROPERTY(QVariantList ambient READ ambient NOTIFY ambientChanged)
public:
  ArtistVideoBackdrop(YouTubeProvider *provider, AuthManager *auth, QObject *parent = nullptr);

  [[nodiscard]] QString videoId() const { return m_videoId; }
  void setVideoId(const QString &id);
  [[nodiscard]] QUrl source() const { return m_source; }
  [[nodiscard]] QString status() const { return m_status; }
  [[nodiscard]] int targetHeight() const { return m_targetHeight; }
  void setTargetHeight(int height);
  [[nodiscard]] QVariantList ambient() const { return m_ambient; }

  // Re-resolves after the signed URL expired or the picture failed to load.
  Q_INVOKABLE void retry();
  // Samples the backdrop's VideoOutput sink for ambient colors; null stops sampling.
  Q_INVOKABLE void watchFrames(QObject *sink);

signals:
  void changed();
  void ambientChanged();

private:
  void resolve();
  void receive(quint64 requestId, const QJsonValue &result);
  void fail(quint64 requestId, const QString &message);
  void clearStream();
  void sampleFrame();
  void clearAmbient();

  YouTubeProvider *m_provider;
  AuthManager *m_auth;
  AudioStreamProxy m_proxy;
  QString m_videoId;
  QString m_status;
  QUrl m_source;
  quint64 m_request{0};
  int m_targetHeight{0};
  // Stream height cap the current stream was requested with.
  int m_requestedCap{0};
  // One automatic retry per video; signed URLs can expire while the page is open.
  bool m_retried{false};
  QPointer<QVideoSink> m_sink;
  QTimer m_frameTimer;
  // Picture area inside baked-in bars, so the bars do not tint the ambient.
  QRectF m_crop;
  QVariantList m_ambient;
};
