#ifndef RINGBUFFER_H
#define RINGBUFFER_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QByteArray>
#include <QMutex>
#include <QVector>
#include <QWaitCondition>

#include <cstddef>

class RingBuffer final
{
public:
    RingBuffer(std::size_t slotCount, std::size_t slotSize);

    quint8 *acquireWriteSlot(int timeoutMs = -1);
    bool commitWrite(std::size_t bytesUsed);
    const quint8 *acquireReadSlot(std::size_t &bytesUsed, int timeoutMs = -1);
    bool releaseReadSlot();

    void cancel();
    bool reset();
    bool isCancelled() const;
    std::size_t pendingSlots() const;
    std::size_t slotSize() const { return _slotSize; }

private:
    struct Slot
    {
        QByteArray data;
        std::size_t bytesUsed = 0;
    };

    bool waitForState(QWaitCondition &condition, QMutexLocker &locker,
                      bool waitForData, int timeoutMs);

    const std::size_t _slotSize;
    QVector<Slot> _slots;
    mutable QMutex _mutex;
    QWaitCondition _notEmpty;
    QWaitCondition _notFull;
    int _readIndex = 0;
    int _writeIndex = 0;
    int _pending = 0;
    bool _writeAcquired = false;
    bool _readAcquired = false;
    bool _cancelled = false;
};

#endif // RINGBUFFER_H
