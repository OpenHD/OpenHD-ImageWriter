#ifndef CURLRETRYPOLICY_H
#define CURLRETRYPOLICY_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <curl/curl.h>

class CurlRetryPolicy final
{
public:
    enum class Action { Stop, Retry, RetryWithHttp11, RetryWithIPv4 };

    explicit CurlRetryPolicy(int maximumRetries = 8);
    Action next(CURLcode error, bool transferAdvanced);
    int retryCount() const { return _retryCount; }

private:
    int _maximumRetries;
    int _retryCount = 0;
    int _http2Failures = 0;
    bool _http11FallbackUsed = false;
    bool _ipv4FallbackUsed = false;
};

#endif // CURLRETRYPOLICY_H
