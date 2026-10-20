/*
 * Copyright (C) 2026 SFG545
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <QString>
#include <QStringList>
#include <QUrl>
#include <QUrlQuery>

inline QString youtubeShareUrl(const QString &input, bool collection = false)
{
    QString id = input.trimmed();
    if (id.isEmpty())
        return QStringLiteral("https://music.youtube.com");
    if (id.startsWith(QLatin1String("local:")) || id.startsWith(QLatin1String("local-playlist:")))
        return {};

    const QUrl url(id);
    QString host = url.host().toLower();
    if (host.startsWith(QLatin1String("www.")))
        host.remove(0, 4);
    const QStringList path = url.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
    const QUrlQuery query(url);
    if ((host == QLatin1String("song.link") || host == QLatin1String("album.link")) &&
        path.size() == 2 && path.first() == QLatin1String("y")) {
        collection = collection || host == QLatin1String("album.link");
        id = path.last();
    } else if (host == QLatin1String("youtu.be") && !path.isEmpty()) {
        id = path.first();
    } else if (host == QLatin1String("youtube.com") || host == QLatin1String("music.youtube.com") ||
               host == QLatin1String("m.youtube.com")) {
        if (query.hasQueryItem(QStringLiteral("v"))) {
            id = query.queryItemValue(QStringLiteral("v"));
        } else if (query.hasQueryItem(QStringLiteral("list"))) {
            id = query.queryItemValue(QStringLiteral("list"));
            collection = true;
        } else if (path.size() == 2 &&
                   (path.first() == QLatin1String("shorts") || path.first() == QLatin1String("embed") ||
                    path.first() == QLatin1String("live"))) {
            id = path.last();
        } else {
            return input.trimmed();
        }
    } else if (!host.isEmpty()) {
        return input.trimmed();
    }

    if (id.startsWith(QLatin1String("VL"))) {
        id.remove(0, 2);
        collection = true;
    }
    if (id.startsWith(QLatin1String("MPRE")))
        return QStringLiteral("https://music.youtube.com/browse/") + QString::fromLatin1(QUrl::toPercentEncoding(id));

    collection = collection || id.startsWith(QLatin1String("OLAK")) ||
                 id.startsWith(QLatin1String("PL")) || id.startsWith(QLatin1String("RD"));
    QUrl result(QStringLiteral("https://music.youtube.com/") +
                (collection ? QStringLiteral("playlist") : QStringLiteral("watch")));
    QUrlQuery resultQuery;
    resultQuery.addQueryItem(collection ? QStringLiteral("list") : QStringLiteral("v"), id);
    result.setQuery(resultQuery);
    return result.toString(QUrl::FullyEncoded);
}
