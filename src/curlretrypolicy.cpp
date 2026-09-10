/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include "curlretrypolicy.h"

CurlRetryPolicy::CurlRetryPolicy(int maximumRetries)
    : _maximumRetries(maximumRetries)
{
}

CurlRetryPolicy::Action CurlRetryPolicy::next(CURLcode error, bool transferAdvanced)
{
    if (error == CURLE_OK || _retryCount >= _maximumRetries)
        return Action::Stop;

    Action action = Action::Stop;
    if ((error == CURLE_SSL_CONNECT_ERROR || error == CURLE_HTTP2) &&
        !_http11FallbackUsed)
    {
        _http11FallbackUsed = true;
        action = Action::RetryWithHttp11;
    }
    else if (error == CURLE_HTTP2_STREAM)
    {
        ++_http2Failures;
        if (_http2Failures >= 3 && !_http11FallbackUsed)
        {
            _http11FallbackUsed = true;
            action = Action::RetryWithHttp11;
        }
        else
            action = Action::Retry;
    }
    else if (!transferAdvanced && !_ipv4FallbackUsed &&
             (error == CURLE_COULDNT_RESOLVE_HOST ||
              error == CURLE_COULDNT_CONNECT ||
              error == CURLE_OPERATION_TIMEDOUT))
    {
        _ipv4FallbackUsed = true;
        action = Action::RetryWithIPv4;
    }
    else if (error == CURLE_PARTIAL_FILE || error == CURLE_OPERATION_TIMEDOUT ||
             (error == CURLE_RECV_ERROR && transferAdvanced))
    {
        action = Action::Retry;
    }

    if (action != Action::Stop)
        ++_retryCount;
    return action;
}
