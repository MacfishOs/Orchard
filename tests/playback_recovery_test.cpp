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
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#include "auth/auth_manager.h"
#include "playback/playback_controller.h"
#include "providers/youtube/youtube_provider.h"

#include <QDataStream>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

namespace {
struct Invocation {
  QString method;
  QJsonObject payload;
};
QList<Invocation> invocations;

QByteArray silentWave() {
  const QByteArray samples(60 * 8000 * 2, '\0');
  QByteArray wave;
  QDataStream out(&wave, QIODevice::WriteOnly);
  out.setByteOrder(QDataStream::LittleEndian);
  out.writeRawData("RIFF", 4);
  out << quint32(36 + samples.size());
  out.writeRawData("WAVEfmt ", 8);
  out << quint32(16) << quint16(1) << quint16(1) << quint32(8000)
      << quint32(16000) << quint16(2) << quint16(16);
  out.writeRawData("data", 4);
  out << quint32(samples.size());
  out.writeRawData(samples.constData(), samples.size());
  return wave;
}
}

// Keep the real controller, proxy and Qt decoder; only resolution is scripted.
YouTubeProvider::YouTubeProvider(QObject *parent) : QObject(parent), m_runtime(nullptr) {}
quint64 YouTubeProvider::invoke(const QString &method, const QJsonValue &payload) {
  invocations.append({method, payload.toObject()});
  return invocations.size();
}
quint64 YouTubeProvider::loadAccountProfile(const QJsonObject &) { return 0; }
quint64 YouTubeProvider::enrichAccountProfile(const QJsonObject &) { return 0; }
void YouTubeProvider::cancelAll() {}

class PlaybackRecoveryTest final : public QObject {
  Q_OBJECT
private:
  QTemporaryDir m_settings;
  struct Session {
    YouTubeProvider provider;
    AuthManager auth{&provider, true};
    PlaybackController playback{&provider, &auth, nullptr};
  };

  QJsonObject stream() {
    return {{"url", "https://fixture.googlevideo.com/audio"},
            {"provider", "fixture"}, {"mimeType", "audio/wav"},
            {"contentLength", silentWave().size()}, {"durationSeconds", 60}};
  }

  void load(Session &session, bool online = true) {
    auto &playback = session.playback;
    playback.ensurePlaybackBackend();
    playback.m_track = {{"id", "abcdefghijk"}, {"type", "song"}, {"durationSeconds", 60}};
    playback.m_queue = {QVariantMap{{"id", "next"}, {"type", "song"}}};
    playback.m_history = {QVariantMap{{"id", "previous"}, {"type", "song"}}};
    playback.m_resumePaused = true;
    playback.m_proxy->setRangeReader([wave = silentWave()](const QJsonObject &, qint64 start,
                                                         qint64 end, auto done) {
      QTimer::singleShot(0, [wave, start, end, done] { done(wave.mid(start, end - start + 1), 0); });
    });
    playback.startResolvedStream(stream());
    QTRY_VERIFY(playback.m_player->isSeekable());
    QTRY_VERIFY(playback.m_player->mediaStatus() == QMediaPlayer::LoadedMedia ||
                playback.m_player->mediaStatus() == QMediaPlayer::BufferedMedia);
    playback.m_player->setPosition(42000);
    QTRY_COMPARE(playback.position(), 42.0);
    if (!online)
      playback.m_proxy->clear();
    invocations.clear();
  }

  void finishRecovery(Session &session) {
    session.provider.resultReady(session.playback.m_request, stream());
    QTRY_VERIFY(session.playback.m_player->isSeekable());
    QTRY_COMPARE(session.playback.m_player->position(), 42000);
    QCOMPARE(session.playback.position(), 42.0);
    QVERIFY(!session.playback.playing());
    QVERIFY(session.playback.errorMessage().isEmpty());
  }

private slots:
  void initTestCase() {
    QVERIFY(m_settings.isValid());
    QStandardPaths::setTestModeEnabled(true);
    QCoreApplication::setOrganizationName("OrchardTest");
    QCoreApplication::setApplicationName("PlaybackRecovery");
    QSettings::setDefaultFormat(QSettings::IniFormat);
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_settings.path());
  }

  void init() {
    QSettings settings;
    settings.clear();
    settings.setValue("playback/persistenceEnabled", false);
    settings.setValue("playback/autoplayEnabled", false);
    settings.setValue("playback/crossfadeEnabled", false);
    settings.setValue("playback/youtubeHistoryEnabled", false);
    invocations.clear();
  }

  void demuxFailureRefreshesAndResumesTheSameTrack() {
    Session session;
    load(session);
    auto &playback = session.playback;
    const auto queue = playback.queue();
    const auto history = playback.history();
    playback.m_proxy->setSuspended(true);
    playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(invocations.size(), 1);
    QCOMPARE(invocations.first().method, QString("playback.resolve"));
    QVERIFY(invocations.first().payload.value("refreshStream").toBool());
    QCOMPARE(invocations.first().payload.value("track").toObject().value("id").toString(),
             QString("abcdefghijk"));
    QCOMPARE(playback.position(), 42.0);
    QVERIFY(playback.loading());
    QCOMPARE(playback.queue(), queue);
    QCOMPARE(playback.history(), history);
    finishRecovery(session);
  }

  void proxyAndDecoderFailuresShareOneRecovery_data() {
    QTest::addColumn<bool>("proxyFirst");
    QTest::newRow("proxy first") << true;
    QTest::newRow("decoder first") << false;
  }

  void proxyAndDecoderFailuresShareOneRecovery() {
    QFETCH(bool, proxyFirst);
    Session session;
    load(session);
    auto &playback = session.playback;
    auto proxyError = [&] { playback.m_proxy->streamFailed(403, "Forbidden"); };
    auto decoderError = [&] {
      playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    };
    if (proxyFirst) { proxyError(); decoderError(); }
    else { decoderError(); proxyError(); }
    QTRY_COMPARE(invocations.size(), 1);
    finishRecovery(session);
    QCOMPARE(invocations.size(), 1);
  }

  void interruptedDownloadRefreshesWithoutRewinding() {
    Session session;
    load(session);
    session.playback.m_proxy->streamFailed(0, "Interrupted");
    QTRY_COMPARE(invocations.size(), 1);
    QCOMPARE(session.playback.position(), 42.0);
    finishRecovery(session);
  }

  void playingStreamContinuesPlayingAfterRecovery() {
    Session session;
    load(session);
    auto &playback = session.playback;
    playback.m_player->play();
    QTRY_VERIFY(playback.playing());
    QTRY_VERIFY(playback.m_player->position() >= 42000);
    playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(invocations.size(), 1);
    const double resumeAt = playback.position();
    QVERIFY(resumeAt >= 42.0);
    session.provider.resultReady(playback.m_request, stream());
    QTRY_VERIFY(playback.playing());
    QTRY_VERIFY(playback.m_player->position() >= qint64(resumeAt * 1000));
    QVERIFY(playback.m_player->position() < qint64((resumeAt + 2.0) * 1000));
    QVERIFY(playback.errorMessage().isEmpty());
  }

  void recoveryResolutionFailureIsReported() {
    Session session;
    load(session);
    auto &playback = session.playback;
    playback.m_player->errorOccurred(QMediaPlayer::NetworkError, "Network error");
    QTRY_COMPARE(invocations.size(), 1);
    session.provider.requestFailed(playback.m_request, "Unable to refresh stream");
    QCOMPARE(playback.errorMessage(), QString("Unable to refresh stream"));
    QVERIFY(!playback.loading());
    QVERIFY(!playback.playing());
    QCOMPARE(invocations.size(), 1);
  }

  void decoderTimelineResetKeepsTheLastPosition() {
    Session session;
    load(session);
    auto *player = session.playback.m_player;
    player->stop();
    player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(invocations.size(), 1);
    QCOMPARE(session.playback.position(), 42.0);
  }

  void seekingToTheBeginningResetsTheRecoveryPosition() {
    Session session;
    load(session);
    session.playback.seek(0.0);
    session.playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(invocations.size(), 1);
    QCOMPARE(session.playback.position(), 0.0);
  }

  void aSecondFailureStopsRetrying() {
    Session session;
    load(session);
    auto &playback = session.playback;
    playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(invocations.size(), 1);
    finishRecovery(session);
    playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Demuxing failed");
    QTRY_COMPARE(playback.errorMessage(), QString("Demuxing failed"));
    QCOMPARE(invocations.size(), 1);
    QVERIFY(!playback.loading());
  }

  void stopInvalidatesPendingRecovery() {
    Session session;
    load(session);
    session.playback.m_proxy->streamFailed(403, "Forbidden");
    session.playback.stop();
    QCoreApplication::sendPostedEvents(&session.playback, QEvent::MetaCall);
    QVERIFY(invocations.isEmpty());
    QVERIFY(session.playback.track().isEmpty());
    QVERIFY(session.playback.errorMessage().isEmpty());
  }

  void replacedSourceInvalidatesPendingRecovery() {
    Session session;
    load(session);
    auto &playback = session.playback;
    playback.m_proxy->streamFailed(403, "Forbidden");
    playback.m_resumePosition = 12.0;
    playback.m_resumePaused = true;
    playback.startResolvedStream(stream());
    QCoreApplication::sendPostedEvents(&playback, QEvent::MetaCall);
    QVERIFY(invocations.isEmpty());
    QVERIFY(!playback.m_retried);
  }

  void localMediaErrorsDoNotResolveOnlineStreams() {
    Session session;
    load(session, false);
    session.playback.m_player->errorOccurred(QMediaPlayer::ResourceError, "Broken file");
    QTRY_COMPARE(session.playback.errorMessage(), QString("Broken file"));
    QVERIFY(invocations.isEmpty());
  }

  void formatErrorsAreReportedWithoutRefreshing() {
    Session session;
    load(session);
    session.playback.m_player->errorOccurred(QMediaPlayer::FormatError, "Unsupported format");
    QTRY_COMPARE(session.playback.errorMessage(), QString("Unsupported format"));
    QVERIFY(invocations.isEmpty());
  }
};

QTEST_MAIN(PlaybackRecoveryTest)
#include "playback_recovery_test.moc"
