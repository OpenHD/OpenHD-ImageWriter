/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "curlnetworkconfig.h"

#include <QDebug>
#include <QMutexLocker>
#ifndef QT_NO_NETWORKPROXY
#include <QNetworkProxy>
#include <QNetworkProxyFactory>
#include <QNetworkProxyQuery>
#endif

void CurlNetworkConfig::ensureInitialized()
{
    static const CURLcode result = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (result != CURLE_OK)
        qWarning() << "curl_global_init failed:" << curl_easy_strerror(result);
}

CurlNetworkConfig &CurlNetworkConfig::instance()
{
    ensureInitialized();
    static CurlNetworkConfig config;
    return config;
}

QByteArray CurlNetworkConfig::proxy() const
{
    QMutexLocker locker(&_mutex);
    return _proxy;
}

void CurlNetworkConfig::setProxy(const QByteArray &proxy)
{
    QMutexLocker locker(&_mutex);
    _proxy = proxy;
    _proxyDetectionAttempted = !_proxy.isEmpty();
}

void CurlNetworkConfig::detectSystemProxy(const QUrl &url)
{
#ifndef QT_NO_NETWORKPROXY
    QMutexLocker locker(&_mutex);
    if (_proxyDetectionAttempted || !_proxy.isEmpty())
        return;
    _proxyDetectionAttempted = true;

    const QList<QNetworkProxy> proxies =
        QNetworkProxyFactory::systemProxyForQuery(QNetworkProxyQuery(url));
    for (const QNetworkProxy &proxy : proxies)
    {
        if (proxy.type() == QNetworkProxy::NoProxy || proxy.hostName().isEmpty())
            continue;
        QUrl proxyUrl;
        proxyUrl.setScheme(proxy.type() == QNetworkProxy::Socks5Proxy
                               ? QStringLiteral("socks5h") : QStringLiteral("http"));
        proxyUrl.setHost(proxy.hostName());
        proxyUrl.setPort(proxy.port());
        if (!proxy.user().isEmpty())
        {
            proxyUrl.setUserName(proxy.user());
            proxyUrl.setPassword(proxy.password());
        }
        _proxy = proxyUrl.toEncoded();
        qDebug() << "Using system proxy" << proxyUrl.host() << proxyUrl.port();
        break;
    }
#else
    Q_UNUSED(url)
#endif
}

void CurlNetworkConfig::applyLargeFileSettings(CURL *curl,
                                                const QByteArray &userAgent,
                                                char *errorBuffer) const
{
    if (!curl)
        return;
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 10L);
    curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_TIME, 60L);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_LIMIT, 100L);
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPALIVE, 1L);
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPIDLE, 30L);
    curl_easy_setopt(curl, CURLOPT_TCP_KEEPINTVL, 15L);
    curl_easy_setopt(curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS);
    curl_easy_setopt(curl, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS);
    if (errorBuffer)
        curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errorBuffer);
    if (!userAgent.isEmpty())
        curl_easy_setopt(curl, CURLOPT_USERAGENT, userAgent.constData());

    const QByteArray configuredProxy = proxy();
    if (!configuredProxy.isEmpty())
        curl_easy_setopt(curl, CURLOPT_PROXY, configuredProxy.constData());
}
