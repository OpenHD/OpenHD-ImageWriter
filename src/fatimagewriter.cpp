#include "fatimagewriter.h"
#include "archivepathvalidator.h"
#include "dependencies/fatfs/ff.h"
#include "dependencies/fatfs/diskio.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QMutex>
#include <QMutexLocker>

namespace {
QMutex filesystemMutex;
// FatFs's registered volumes are global; hold filesystemMutex for the full operation.
QFile *activeImage = nullptr;

bool transferRange(LBA_t sector, UINT count, qint64 *offset, qint64 *length)
{
    if (!activeImage || !count) return false;
    *offset = static_cast<qint64>(sector) * 512;
    *length = static_cast<qint64>(count) * 512;
    return *offset >= 0 && *offset <= activeImage->size() &&
        *length <= activeImage->size() - *offset;
}
}

extern "C" {
DSTATUS disk_status(BYTE drive) { return drive == 0 && activeImage ? 0 : STA_NOINIT; }
DSTATUS disk_initialize(BYTE drive) { return disk_status(drive); }
DRESULT disk_read(BYTE drive, BYTE *buffer, LBA_t sector, UINT count)
{
    qint64 offset, length;
    if (drive || !transferRange(sector, count, &offset, &length)) return RES_PARERR;
    return activeImage->seek(offset) && activeImage->read(reinterpret_cast<char *>(buffer), length) == length
        ? RES_OK : RES_ERROR;
}
DRESULT disk_write(BYTE drive, const BYTE *buffer, LBA_t sector, UINT count)
{
    qint64 offset, length;
    if (drive || !transferRange(sector, count, &offset, &length)) return RES_PARERR;
    return activeImage->seek(offset) && activeImage->write(reinterpret_cast<const char *>(buffer), length) == length
        ? RES_OK : RES_ERROR;
}
DRESULT disk_ioctl(BYTE drive, BYTE command, void *buffer)
{
    if (drive || !activeImage) return RES_NOTRDY;
    switch (command) {
    case CTRL_SYNC: return activeImage->flush() ? RES_OK : RES_ERROR;
    case GET_SECTOR_COUNT: *static_cast<LBA_t *>(buffer) = activeImage->size() / 512; return RES_OK;
    case GET_SECTOR_SIZE: *static_cast<WORD *>(buffer) = 512; return RES_OK;
    case GET_BLOCK_SIZE: *static_cast<DWORD *>(buffer) = 1; return RES_OK;
    default: return RES_PARERR;
    }
}
}

bool FatImageWriter::install(const QString &imagePath, const QString &stagingDirectory,
                             QString *error, const std::function<bool()> &cancelled)
{
    QMutexLocker lock(&filesystemMutex);
    QFile image(imagePath);
    if (!QFileInfo(imagePath).isFile() || !image.open(QIODevice::ReadWrite) ||
        image.size() < 512 || image.size() % 512 || image.size() / 512 > 0xffffffffULL) {
        if (error) *error = QStringLiteral("Cannot open the FAT partition image.");
        return false;
    }
    activeImage = &image;
    FATFS filesystem = {};
    const auto finish = [&](bool ok, const QString &detail) {
        f_mount(nullptr, "0:", 0);
        activeImage = nullptr;
        if (error && !ok) *error = detail;
        return ok;
    };
    FRESULT result = f_mount(&filesystem, "0:", 1);
    if (result != FR_OK) return finish(false, QStringLiteral("Invalid FAT image (error %1).").arg(result));
    QDir staging(stagingDirectory);
    if (!staging.exists()) return finish(false, QStringLiteral("Configuration staging directory is missing."));
    QDirIterator entries(stagingDirectory, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden,
                         QDirIterator::Subdirectories);
    while (entries.hasNext()) {
        if (cancelled && cancelled()) return finish(false, QStringLiteral("Cancelled."));
        const QString source = entries.next();
        const auto info = entries.fileInfo();
        QString relative;
        if (info.isSymLink() || !ArchivePathValidator::normalizeRelativePath(staging.relativeFilePath(source), relative))
            return finish(false, QStringLiteral("Unsafe configuration file path."));
        const QByteArray target = ("0:/" + relative).toUtf8();
        // Create parents explicitly: no dependency on directory iteration order.
        const QStringList components = relative.split('/');
        QString parent = "0:";
        const int directories = info.isDir() ? components.size() : components.size() - 1;
        for (int i = 0; i < directories; ++i) {
            parent += '/' + components.at(i);
            result = f_mkdir(parent.toUtf8().constData());
            FILINFO existing = {};
            if (result != FR_OK && (result != FR_EXIST ||
                f_stat(parent.toUtf8().constData(), &existing) != FR_OK || !(existing.fattrib & AM_DIR)))
                return finish(false, QStringLiteral("Cannot create %1 (FAT error %2).").arg(parent).arg(result));
        }
        if (info.isDir()) continue;
        QFile input(source);
        if (!info.isFile() || info.size() > 0xffffffffLL || !input.open(QIODevice::ReadOnly))
            return finish(false, QStringLiteral("Cannot read configuration file %1.").arg(relative));
        FIL output = {};
        result = f_open(&output, target.constData(), FA_CREATE_ALWAYS | FA_WRITE);
        if (result != FR_OK) return finish(false, QStringLiteral("Cannot create %1 (FAT error %2).").arg(relative).arg(result));
        bool ok = true;
        QByteArray buffer(65536, '\0');
        while (!input.atEnd()) {
            if (cancelled && cancelled()) { ok = false; break; }
            const qint64 bytes = input.read(buffer.data(), buffer.size());
            UINT written = 0;
            if (bytes <= 0 || f_write(&output, buffer.constData(), static_cast<UINT>(bytes), &written) != FR_OK || written != bytes) {
                ok = false; break;
            }
        }
        if (f_close(&output) != FR_OK) ok = false;
        if (!ok) return finish(false, QStringLiteral("Could not write %1 (cancelled, I/O error or config partition full).").arg(relative));
        // Read through the filesystem again, checking both content and final size.
        input.seek(0);
        FIL verify = {};
        result = f_open(&verify, target.constData(), FA_READ);
        if (result != FR_OK) return finish(false, QStringLiteral("Cannot verify %1.").arg(relative));
        ok = f_size(&verify) == static_cast<FSIZE_t>(input.size());
        while (ok && !input.atEnd()) {
            if (cancelled && cancelled()) { ok = false; break; }
            const QByteArray expected = input.read(buffer.size());
            UINT read = 0;
            ok = !expected.isEmpty() && f_read(&verify, buffer.data(), expected.size(), &read) == FR_OK &&
                read == static_cast<UINT>(expected.size()) && QByteArray(buffer.constData(), read) == expected;
        }
        if (f_close(&verify) != FR_OK) ok = false;
        if (!ok) return finish(false, QStringLiteral("Configuration readback failed for %1.").arg(relative));
    }
    if (!image.flush()) return finish(false, QStringLiteral("Could not flush the configuration image."));
    return finish(true, {});
}
