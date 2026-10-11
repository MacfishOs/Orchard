/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#include "discord.h"
#include "auth/auth_manager.h"
#include "providers/youtube/catalog/youtube_catalog.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>
#include <utility>

QString Discord::publicImageUrl(const QString &value)
{
    const QUrl url(value.trimmed());
    return url.isValid() && !url.host().isEmpty() &&
                   (url.scheme() == QLatin1String("https") || url.scheme() == QLatin1String("http"))
        ? url.toString() : QString();
}

void Discord::connectArtistCatalog()
{
    if (!m_catalog) return;
    connect(m_catalog, &YouTubeCatalog::artistReady, this,
            [this](quint64 requestId, const QJsonObject &artist) {
        if (requestId != m_artistYouTubeRequest || m_artistArtworkKey.isEmpty()) return;
        m_artistYouTubeRequest = 0;
        finishArtistArtwork(m_artistArtworkKey, publicImageUrl(artist.value(QLatin1String("thumbnail")).toString()));
    });
    connect(m_catalog, &YouTubeCatalog::requestFailed, this,
            [this](quint64 requestId, const QString &) {
        if (requestId != m_artistYouTubeRequest || m_artistArtworkKey.isEmpty()) return;
        m_artistYouTubeRequest = 0;
        finishArtistArtwork(m_artistArtworkKey, {});
    });
}

void Discord::updateArtistArtwork()
{
    const QStringList names = m_track.value(QStringLiteral("artists")).toStringList();
    const QString name = (names.isEmpty() ? m_track.value(QStringLiteral("artist")).toString()
                                          : names.first()).trimmed();
    const QStringList browseIds = m_track.value(QStringLiteral("artistBrowseIds")).toStringList();
    const QString browseId = browseIds.value(0).trimmed();
    const QString key = name.isEmpty() || !m_enabled ? QString()
        : name.toCaseFolded() + QLatin1Char('|') + browseId;
    if (key == m_artistArtworkKey) return;

    m_artistArtworkKey = key;
    m_artistImage.clear();
    m_artistYouTubeRequest = 0;
    if (QNetworkReply *reply = std::exchange(m_artistReply, nullptr)) {
        // abort() emits finished synchronously; keep the handler out of it.
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
    if (key.isEmpty()) return;
    if (m_artistImageCache.contains(key)) {
        m_artistImage = m_artistImageCache.value(key);
        return;
    }

    QUrl url(QStringLiteral("https://www.theaudiodb.com/api/v1/json/123/search.php"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("s"), name);
    url.setQuery(query);
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "Orchard Desktop/3.0");
    request.setTransferTimeout(4000);
    auto *reply = m_artistNetwork.get(request);
    m_artistReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, key, browseId] {
        if (m_artistReply != reply) { reply->deleteLater(); return; }
        m_artistReply = nullptr;
        QString image;
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonDocument document = QJsonDocument::fromJson(reply->readAll());
            const QJsonArray artists = document.object().value(QLatin1String("artists")).toArray();
            const QJsonObject artist = artists.isEmpty() ? QJsonObject() : artists.first().toObject();
            image = publicImageUrl(artist.value(QLatin1String("strArtistThumb")).toString());
            if (image.isEmpty())
                image = publicImageUrl(artist.value(QLatin1String("strArtistCutout")).toString());
        }
        reply->deleteLater();
        if (key != m_artistArtworkKey) return;
        if (!image.isEmpty()) finishArtistArtwork(key, image);
        else requestYouTubeArtistArtwork(key, browseId);
    });
}

void Discord::requestYouTubeArtistArtwork(const QString &key, const QString &browseId)
{
    // TheAudioDB missed; ask the artist's own channel to cover the tiny circle.
    if (!m_catalog || !m_auth || browseId.isEmpty()) {
        finishArtistArtwork(key, {});
        return;
    }
    m_artistYouTubeRequest = m_catalog->fetchArtist(browseId, m_auth->sessionObject());
}

void Discord::finishArtistArtwork(const QString &key, const QString &imageUrl)
{
    if (key != m_artistArtworkKey) return;
    m_artistImage = imageUrl;
    if (m_artistImageCache.size() >= 128) m_artistImageCache.clear();
    m_artistImageCache.insert(key, imageUrl);
    refresh(true);
}
