/* SPDX-License-Identifier: Apache-2.0 */
#ifndef ROCKCHIPIMAGEVERIFY_H
#define ROCKCHIPIMAGEVERIFY_H

#include <QByteArray>
#include <QIODevice>
#include <QString>
#include <functional>
#include <limits>

// Read the same sector range that was written, including the zero-padded
// final sector. The callback is the real USB transport in production.
inline bool verifyRockchipImage(QIODevice &source, quint64 bytes, quint32 startLba,
        const std::function<bool(quint32, quint16, quint8 *, QString *)> &read,
        const std::function<bool()> &cancelled, QString *error,
        const std::function<void(quint64)> &progress = {})
{
    if (error) error->clear();
    const quint64 sectors = bytes / 512 + (bytes % 512 != 0);
    if (!bytes || sectors > quint64((std::numeric_limits<quint32>::max)()) - startLba + 1)
    {
        if (error) *error = QStringLiteral("Invalid image sector range.");
        return false;
    }
    constexpr int chunkSize = 128 * 512;
    QByteArray expected(chunkSize, '\0'), actual(chunkSize, '\0');
    quint64 done = 0;
    quint32 lba = startLba;
    while (done < bytes)
    {
        if (cancelled()) return false;
        expected.fill('\0');
        const qint64 count = qMin<quint64>(bytes - done, chunkSize);
        if (source.read(expected.data(), count) != count)
        {
            if (error) *error = QStringLiteral("Unable to read complete source image at byte %1.").arg(done);
            return false;
        }
        const quint16 chunkSectors = static_cast<quint16>((count + 511) / 512);
        if (!read(lba, chunkSectors, reinterpret_cast<quint8 *>(actual.data()), error))
            return false;
        if (expected.left(chunkSectors * 512) != actual.left(chunkSectors * 512))
        {
            if (error) *error = QStringLiteral("Image readback mismatch at sector %1.").arg(lba);
            return false;
        }
        done += count;
        lba += chunkSectors;
        if (progress) progress(done);
    }
    return !cancelled();
}
#endif
