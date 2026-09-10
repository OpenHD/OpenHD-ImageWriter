#include "blockbatcher.h"

#include <algorithm>
#include <limits>
#include <utility>

BlockBatcher::BlockBatcher(std::size_t batchSize, Sink sink)
    : _batchSize(batchSize), _sink(std::move(sink))
{
    Q_ASSERT(batchSize > 0 && batchSize <= static_cast<std::size_t>(std::numeric_limits<int>::max()));
    _buffer.reserve(static_cast<int>(batchSize));
}

bool BlockBatcher::append(const quint8 *data, std::size_t size)
{
    if ((!data && size) || !_sink)
        return false;

    std::size_t consumed = 0;
    while (consumed < size)
    {
        const std::size_t available = _batchSize - static_cast<std::size_t>(_buffer.size());
        const std::size_t chunk = std::min(available, size - consumed);
        _buffer.append(reinterpret_cast<const char *>(data + consumed), static_cast<int>(chunk));
        consumed += chunk;
        if (static_cast<std::size_t>(_buffer.size()) == _batchSize && !flush())
            return false;
    }
    return true;
}

bool BlockBatcher::flush()
{
    if (_buffer.isEmpty())
        return true;
    if (!_sink(reinterpret_cast<const quint8 *>(_buffer.constData()),
               static_cast<std::size_t>(_buffer.size())))
        return false;
    _buffer.clear();
    return true;
}
