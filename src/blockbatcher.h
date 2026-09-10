#ifndef BLOCKBATCHER_H
#define BLOCKBATCHER_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020-2026 Raspberry Pi Ltd
 * Copyright (C) 2026 OpenHD
 */

#include <QByteArray>
#include <QtGlobal>

#include <cstddef>
#include <functional>

class BlockBatcher final
{
public:
    using Sink = std::function<bool(const quint8 *, std::size_t)>;

    BlockBatcher(std::size_t batchSize, Sink sink);
    bool append(const quint8 *data, std::size_t size);
    bool flush();
    std::size_t pendingBytes() const { return static_cast<std::size_t>(_buffer.size()); }

private:
    const std::size_t _batchSize;
    Sink _sink;
    QByteArray _buffer;
};

#endif // BLOCKBATCHER_H
