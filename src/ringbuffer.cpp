#include "ringbuffer.h"

#include <QElapsedTimer>
#include <QMutexLocker>

#include <limits>

RingBuffer::RingBuffer(std::size_t slotCount, std::size_t slotSize)
    : _slotSize(slotSize), _slots(static_cast<int>(slotCount))
{
    Q_ASSERT(slotCount > 0 && slotCount <= static_cast<std::size_t>(std::numeric_limits<int>::max()));
    Q_ASSERT(slotSize > 0 && slotSize <= static_cast<std::size_t>(std::numeric_limits<int>::max()));
    for (Slot &slot : _slots)
        slot.data.resize(static_cast<int>(slotSize));
}

bool RingBuffer::waitForState(QWaitCondition &condition, QMutexLocker &locker,
                              bool waitForData, int timeoutMs)
{
    QElapsedTimer timer;
    timer.start();
    while (!_cancelled && (waitForData ? _pending == 0 : _pending == _slots.size()))
    {
        if (timeoutMs < 0)
        {
            condition.wait(locker.mutex());
            continue;
        }
        const qint64 remaining = timeoutMs - timer.elapsed();
        if (remaining <= 0 || !condition.wait(locker.mutex(), static_cast<unsigned long>(remaining)))
            return false;
    }
    return !_cancelled;
}

quint8 *RingBuffer::acquireWriteSlot(int timeoutMs)
{
    QMutexLocker locker(&_mutex);
    if (_writeAcquired || !waitForState(_notFull, locker, false, timeoutMs))
        return nullptr;
    _writeAcquired = true;
    return reinterpret_cast<quint8 *>(_slots[_writeIndex].data.data());
}

bool RingBuffer::commitWrite(std::size_t bytesUsed)
{
    QMutexLocker locker(&_mutex);
    if (!_writeAcquired || _cancelled || bytesUsed > _slotSize)
        return false;
    _slots[_writeIndex].bytesUsed = bytesUsed;
    _writeIndex = (_writeIndex + 1) % _slots.size();
    ++_pending;
    _writeAcquired = false;
    _notEmpty.wakeOne();
    return true;
}

const quint8 *RingBuffer::acquireReadSlot(std::size_t &bytesUsed, int timeoutMs)
{
    QMutexLocker locker(&_mutex);
    bytesUsed = 0;
    if (_readAcquired || !waitForState(_notEmpty, locker, true, timeoutMs))
        return nullptr;
    _readAcquired = true;
    bytesUsed = _slots[_readIndex].bytesUsed;
    return reinterpret_cast<const quint8 *>(_slots[_readIndex].data.constData());
}

bool RingBuffer::releaseReadSlot()
{
    QMutexLocker locker(&_mutex);
    if (!_readAcquired)
        return false;
    _slots[_readIndex].bytesUsed = 0;
    _readIndex = (_readIndex + 1) % _slots.size();
    --_pending;
    _readAcquired = false;
    _notFull.wakeOne();
    return true;
}

void RingBuffer::cancel()
{
    QMutexLocker locker(&_mutex);
    _cancelled = true;
    _notEmpty.wakeAll();
    _notFull.wakeAll();
}

bool RingBuffer::reset()
{
    QMutexLocker locker(&_mutex);
    if (_pending != 0 || _readAcquired || _writeAcquired)
        return false;
    _readIndex = 0;
    _writeIndex = 0;
    _cancelled = false;
    return true;
}

bool RingBuffer::isCancelled() const
{
    QMutexLocker locker(&_mutex);
    return _cancelled;
}

std::size_t RingBuffer::pendingSlots() const
{
    QMutexLocker locker(&_mutex);
    return static_cast<std::size_t>(_pending);
}
