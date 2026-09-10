#ifndef WRITEPROGRESSWATCHDOG_H
#define WRITEPROGRESSWATCHDOG_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QtGlobal>

class WriteProgressWatchdog final
{
public:
    struct Configuration
    {
        qint64 warningAfterMs = 30000;
        qint64 recoverAfterMs = 60000;
        qint64 hardTimeoutAfterMs = 180000;
    };

    struct Snapshot
    {
        quint64 downloaded = 0;
        quint64 written = 0;
        quint64 verified = 0;
        bool deviceOperationActive = false;
    };

    enum class Action
    {
        None,
        Warn,
        RequestRecovery,
        HardTimeout
    };

    WriteProgressWatchdog();
    explicit WriteProgressWatchdog(Configuration configuration);

    void start(qint64 nowMs);
    void start(qint64 nowMs, const Snapshot &snapshot);
    void stop();
    bool isRunning() const { return _running; }
    qint64 stalledForMs(qint64 nowMs) const;
    Action observe(qint64 nowMs, const Snapshot &snapshot);

private:
    bool madeProgress(const Snapshot &snapshot) const;
    void resetProgress(qint64 nowMs, const Snapshot &snapshot);

    Configuration _configuration;
    Snapshot _lastSnapshot;
    qint64 _lastProgressMs = 0;
    bool _running = false;
    bool _operationWasActive = false;
    bool _warningSent = false;
    bool _recoveryRequested = false;
    bool _hardTimeoutSent = false;
};

#endif // WRITEPROGRESSWATCHDOG_H
