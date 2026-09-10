#ifndef CURLNETWORKCONFIG_H
#define CURLNETWORKCONFIG_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2025-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QByteArray>
#include <QMutex>
#include <QUrl>
#include <curl/curl.h>

class CurlNetworkConfig final
{
public:
    static CurlNetworkConfig &instance();
    static void ensureInitialized();

    QByteArray proxy() const;
    void setProxy(const QByteArray &proxy);
    void detectSystemProxy(const QUrl &url);
    void applyLargeFileSettings(CURL *curl, const QByteArray &userAgent,
                                char *errorBuffer = nullptr) const;

private:
    CurlNetworkConfig() = default;
    CurlNetworkConfig(const CurlNetworkConfig &) = delete;
    CurlNetworkConfig &operator=(const CurlNetworkConfig &) = delete;

    QByteArray _proxy;
    bool _proxyDetectionAttempted = false;
    mutable QMutex _mutex;
};

#endif // CURLNETWORKCONFIG_H
