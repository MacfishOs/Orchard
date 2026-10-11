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

#include "artist_video_backdrop.h"

#include "appearance/video_ambient.h"
#include "auth/auth_manager.h"
#include "letterbox.h"
#include "providers/youtube/youtube_provider.h"

#include <QJsonObject>
#include <QVideoFrame>
#include <QVideoSink>

namespace {

// Above 1080p YouTube only offers VP9 or AV1, so 1440p is the ceiling for a background.
// A tenth of upscaling is invisible under the scrims and saves a tier.
int heightCap(int target) {
  for (const int cap : {720, 1080})
    if (target <= cap * 11 / 10)
      return cap;
  return 1440;
}
constexpr int kAmbientCells = 3;

} // namespace

ArtistVideoBackdrop::ArtistVideoBackdrop(YouTubeProvider *provider, AuthManager *auth, QObject *parent)
    : QObject(parent), m_provider(provider), m_auth(auth) {
  connect(m_provider, &YouTubeProvider::resultReady, this, &ArtistVideoBackdrop::receive);
  connect(m_provider, &YouTubeProvider::requestFailed, this, &ArtistVideoBackdrop::fail);
  connect(&m_proxy, &AudioStreamProxy::streamFailed, this, [this](int, const QString &) {
    clearStream();
    m_status = QStringLiteral("error");
    emit changed();
  });
  // The shell eases between samples, so once a second still reads as continuous.
  m_frameTimer.setInterval(1000);
  connect(&m_frameTimer, &QTimer::timeout, this, &ArtistVideoBackdrop::sampleFrame);
}

void ArtistVideoBackdrop::watchFrames(QObject *sink) {
  m_sink = qobject_cast<QVideoSink *>(sink);
  if (m_sink) {
    sampleFrame();
    m_frameTimer.start();
  } else {
    m_frameTimer.stop();
  }
}

// Polls on the GUI thread; the sink's frame signal can fire on the decoder thread.
void ArtistVideoBackdrop::sampleFrame() {
  if (!m_sink) {
    m_frameTimer.stop();
    return;
  }
  const QVideoFrame frame = m_sink->videoFrame();
  if (!frame.isValid())
    return;
  const QImage image = frame.toImage();
  m_crop = letterbox::accumulate(m_crop, letterbox::contentRect(image));
  const QList<QColor> cells = videoambient::grid(image, m_crop, kAmbientCells, kAmbientCells);
  if (cells.isEmpty())
    return;
  QVariantList ambient;
  ambient.reserve(cells.size());
  for (const QColor &cell : cells)
    ambient.append(videoambient::backgroundTone(cell));
  if (ambient == m_ambient)
    return;
  m_ambient = ambient;
  emit ambientChanged();
}

void ArtistVideoBackdrop::clearAmbient() {
  m_crop = {};
  if (m_ambient.isEmpty())
    return;
  m_ambient.clear();
  emit ambientChanged();
}

void ArtistVideoBackdrop::setVideoId(const QString &id) {
  if (id == m_videoId)
    return;
  m_videoId = id;
  m_retried = false;
  clearAmbient();
  if (m_videoId.isEmpty()) {
    m_request = 0;
    clearStream();
    m_status.clear();
    emit changed();
    return;
  }
  resolve();
}

void ArtistVideoBackdrop::setTargetHeight(int height) {
  height = qMax(0, height);
  if (height == m_targetHeight)
    return;
  m_targetHeight = height;
  emit changed();
  // Resizing down keeps the sharper stream; only a bigger cap is worth a reload.
  if (!m_videoId.isEmpty() && heightCap(height) > m_requestedCap)
    resolve();
}

void ArtistVideoBackdrop::retry() {
  if (m_videoId.isEmpty() || m_retried || m_request != 0)
    return;
  m_retried = true;
  resolve();
}

void ArtistVideoBackdrop::resolve() {
  clearStream();
  m_status = QStringLiteral("loading");
  m_requestedCap = heightCap(m_targetHeight);
  m_request = m_provider->invoke(QStringLiteral("playback.resolveVideo"), QJsonObject{
      {QStringLiteral("session"), m_auth->sessionObject()},
      {QStringLiteral("streamQuality"), QStringLiteral("high")},
      {QStringLiteral("maxHeight"), m_requestedCap},
      {QStringLiteral("track"), QJsonObject{{QStringLiteral("id"), m_videoId},
                                            {QStringLiteral("type"), QStringLiteral("video")}}}});
  emit changed();
}

void ArtistVideoBackdrop::receive(quint64 requestId, const QJsonValue &result) {
  if (requestId == 0 || requestId != m_request)
    return;
  m_request = 0;
  // The proxy keeps YouTube's User-Agent and Origin headers on every range request.
  m_source = m_proxy.open(result.toObject());
  m_status = m_source.isEmpty() ? QStringLiteral("error") : QStringLiteral("ready");
  emit changed();
}

void ArtistVideoBackdrop::fail(quint64 requestId, const QString &) {
  if (requestId == 0 || requestId != m_request)
    return;
  m_request = 0;
  m_status = QStringLiteral("error");
  emit changed();
}

void ArtistVideoBackdrop::clearStream() {
  if (m_source.isEmpty())
    return;
  m_source.clear();
  m_proxy.clear();
}
