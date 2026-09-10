/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include "writeprogresswatchdog.h"

WriteProgressWatchdog::WriteProgressWatchdog()
    : WriteProgressWatchdog(Configuration())
{
}

WriteProgressWatchdog::WriteProgressWatchdog(Configuration configuration)
    : _configuration(configuration)
{
    Q_ASSERT(_configuration.warningAfterMs >= 0);
    Q_ASSERT(_configuration.recoverAfterMs >= _configuration.warningAfterMs);
    Q_ASSERT(_configuration.hardTimeoutAfterMs > _configuration.recoverAfterMs);
}

void WriteProgressWatchdog::start(qint64 nowMs)
{
    start(nowMs, Snapshot());
}

void WriteProgressWatchdog::start(qint64 nowMs, const Snapshot &snapshot)
{
    _running = true;
    _operationWasActive = snapshot.deviceOperationActive;
    resetProgress(nowMs, snapshot);
}

void WriteProgressWatchdog::stop()
{
    _running = false;
    _operationWasActive = false;
}

qint64 WriteProgressWatchdog::stalledForMs(qint64 nowMs) const
{
    return _running && nowMs > _lastProgressMs ? nowMs - _lastProgressMs : 0;
}

bool WriteProgressWatchdog::madeProgress(const Snapshot &snapshot) const
{
    return snapshot.downloaded != _lastSnapshot.downloaded ||
           snapshot.written != _lastSnapshot.written ||
           snapshot.verified != _lastSnapshot.verified;
}

void WriteProgressWatchdog::resetProgress(qint64 nowMs, const Snapshot &snapshot)
{
    _lastSnapshot = snapshot;
    _lastProgressMs = nowMs;
    _warningSent = false;
    _recoveryRequested = false;
    _hardTimeoutSent = false;
}

WriteProgressWatchdog::Action WriteProgressWatchdog::observe(
    qint64 nowMs, const Snapshot &snapshot)
{
    if (!_running)
        return Action::None;

    if (!snapshot.deviceOperationActive)
    {
        _operationWasActive = false;
        resetProgress(nowMs, snapshot);
        return Action::None;
    }

    if (!_operationWasActive || madeProgress(snapshot))
    {
        _operationWasActive = true;
        resetProgress(nowMs, snapshot);
        return Action::None;
    }

    _lastSnapshot = snapshot;
    const qint64 stalledMs = stalledForMs(nowMs);
    if (!_hardTimeoutSent && stalledMs >= _configuration.hardTimeoutAfterMs)
    {
        _hardTimeoutSent = true;
        return Action::HardTimeout;
    }
    if (!_recoveryRequested && stalledMs >= _configuration.recoverAfterMs)
    {
        _recoveryRequested = true;
        return Action::RequestRecovery;
    }
    if (!_warningSent && stalledMs >= _configuration.warningAfterMs)
    {
        _warningSent = true;
        return Action::Warn;
    }
    return Action::None;
}
