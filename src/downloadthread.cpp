/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "downloadthread.h"
#include "config.h"
#include "curlnetworkconfig.h"
#include "curlretrypolicy.h"
#ifdef Q_OS_WIN
#include "windows/windowsdiskpreparation.h"
#endif
#include "openhdimagecustomizer.h"
#include "dependencies/mountutils/src/mountutils.hpp"
#include "drivelist/drivelist.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <utime.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <regex>
#include <QDebug>
#include <QProcess>
#include <QSettings>
#include <QtConcurrent/QtConcurrent>

#ifdef Q_OS_LINUX
#include <sys/ioctl.h>
#include <linux/fs.h>
#include "linux/udisks2api.h"
#endif
#ifdef Q_OS_DARWIN
#include "mac/macfile.h"
#endif

using namespace std;

QSettings settings;

DownloadThread::DownloadThread(const QByteArray &url, const QByteArray &localfilename, const QByteArray &expectedHash, QObject *parent) :
    QThread(parent), _startOffset(0), _lastDlTotal(0), _lastDlNow(0), _verifyTotal(0), _lastVerifyNow(0), _bytesWritten(0), _lastFailureOffset(0), _sectorsStart(-1), _url(url), _filename(localfilename), _expectedHash(expectedHash),
    _firstBlock(nullptr), _cancelled(false), _deviceOperationActive(false),
    _watchdogRecoveryRequested(false), _successful(false), _verifyEnabled(false), _cacheEnabled(false), _lastModified(0), _serverTime(0),  _lastFailureTime(0),
    _inputBufferSize(0), _lastFileError(FileError::Success), _file(FileOperations::create()),
    _writehash(OSLIST_HASH_ALGORITHM), _verifyhash(OSLIST_HASH_ALGORITHM)
{
    _writeBatcher.reset(new BlockBatcher(
        IMAGEWRITER_BLOCKSIZE,
        [this](const quint8 *data, std::size_t size) { return _writeBatch(data, size); }));
    CurlNetworkConfig::ensureInitialized();
    _ejectEnabled = false;
}

DownloadThread::~DownloadThread()
{
    _cancelled = true;
    _file->cancel();
    wait();
    if (_file->isOpen())
        _file->close();

    if (_firstBlock)
        qFreeAligned(_firstBlock);

}

void DownloadThread::setProxy(const QByteArray &proxy)
{
    CurlNetworkConfig::instance().setProxy(proxy);
}

QByteArray DownloadThread::proxy()
{
    return CurlNetworkConfig::instance().proxy();
}

void DownloadThread::setUserAgent(const QByteArray &ua)
{
    _useragent = ua;
}

/* Curl write callback function, let it call the object oriented version */
size_t DownloadThread::_curl_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    return static_cast<DownloadThread *>(userdata)->_writeData(ptr, size * nmemb);
}

int DownloadThread::_curl_xferinfo_callback(void *userdata, curl_off_t dltotal, curl_off_t dlnow, curl_off_t ultotal, curl_off_t ulnow)
{
    return (static_cast<DownloadThread *>(userdata)->_progress(dltotal, dlnow, ultotal, ulnow) == false);
}

size_t DownloadThread::_curl_header_callback( void *ptr, size_t size, size_t nmemb, void *userdata)
{
    int len = size*nmemb;
    string headerstr((char *) ptr, len);
    static_cast<DownloadThread *>(userdata)->_header(headerstr);

    return len;
}

QByteArray DownloadThread::_fileGetContentsTrimmed(const QString &filename)
{
    QByteArray result;
    QFile f(filename);

    if (f.exists() && f.open(f.ReadOnly))
    {
        result = f.readAll().trimmed();
        f.close();
    }

    return result;
}

bool DownloadThread::_openAndPrepareDevice()
{
    QSettings settings_;
    std::cout << "_____________________________-DEBUG-_______________________________________" << std::endl;

    if (settings_.value("justUpdate").toBool())
    {
    std::cout << "running update procedure without modifying the image" << std::endl;
    return true;
    }

    emit preparationStatusUpdate(tr("opening drive"));

    if (_filename.startsWith("/dev/update-"))
    {
    std::cout << "running update procedure without modifying the image" << std::endl;
    }

    if (_filename.startsWith("/dev/"))
    {
        unmount_disk(_filename.constData());
    }

#ifdef Q_OS_WIN
    qDebug() << "device" << _filename;
    WindowsDiskPreparation::LockedVolumes lockedVolumes;

    std::regex windriveregex("\\\\\\\\.\\\\PHYSICALDRIVE([0-9]+)", std::regex_constants::icase);
    std::cmatch m;

    if (std::regex_match(_filename.constData(), m, windriveregex))
    {
        const auto devices = Drivelist::ListStorageDevices();
        const QByteArray target = _filename.toLower();
        const Drivelist::DeviceDescriptor *targetDevice = nullptr;
        if (!devices.empty() && devices.front().device == "__error__")
        {
            emit error(tr("Cannot safely enumerate target volumes: %1")
                       .arg(QString::fromStdString(devices.front().error)));
            return false;
        }
        for (const Drivelist::DeviceDescriptor &device : devices)
        {
            if (QByteArray::fromStdString(device.device).toLower() == target)
            {
                targetDevice = &device;
                break;
            }
        }
        if (!targetDevice)
        {
            emit error(tr("The selected storage device is no longer available."));
            return false;
        }

        QString preparationError;
        if (!lockedVolumes.lockAndDismount(targetDevice->mountpoints, &preparationError))
        {
            emit error(tr("Cannot lock the target volumes: %1").arg(preparationError));
            return false;
        }
        if (!WindowsDiskPreparation::clearPartitionTable(
                QString::fromUtf8(_filename), &preparationError))
        {
            emit error(preparationError);
            return false;
        }
    }

#endif

#ifdef Q_OS_DARWIN
    _filename.replace("/dev/disk", "/dev/rdisk");

    _lastFileError = _file->openDevice(QString::fromUtf8(_filename), true);
    if (_lastFileError != FileError::Success)
    {
        MacFile authorizedFile;
        const auto authopenresult = authorizedFile.authOpen(_filename);
        if (authopenresult == MacFile::authOpenCancelled) {
            emit error(tr("Authentication cancelled"));
            return false;
        } else if (authopenresult == MacFile::authOpenError ||
                   (_lastFileError = _file->adoptNativeHandle(authorizedFile.handle(), false, true)) != FileError::Success) {
            QString msg = tr("Error running authopen to gain access to disk device '%1'").arg(QString(_filename));
            msg += "<br>"+tr("Please verify if 'Raspberry Pi Imager' is allowed access to 'removable volumes' in privacy settings (under 'files and folders' or alternatively give it 'full disk access').");
            QStringList args("x-apple.systempreferences:com.apple.preference.security?Privacy_RemovableVolume");
            QProcess::execute("open", args);
            emit error(msg);
            return false;
        }
    }
#else
    _lastFileError = _file->openDevice(QString::fromUtf8(_filename), true);
    if (_lastFileError != FileError::Success)
    {
#ifdef Q_OS_LINUX
#ifndef QT_NO_DBUS
        /* Opening device directly did not work, ask udisks2 to do it for us,
         * if necessary prompting for authorization */
        UDisks2Api udisks;
        int fd = udisks.authOpen(_filename);
        if (fd != -1)
        {
            _lastFileError = _file->adoptNativeHandle(fd, true, true);
        }
#endif
        if (_lastFileError != FileError::Success)
        {
            emit error(tr("Cannot open storage device '%1': %2.")
                       .arg(QString(_filename), fileErrorMessage(_lastFileError)));
            return false;
        }
#else
        emit error(tr("Cannot open storage device '%1': %2.")
                   .arg(QString(_filename), fileErrorMessage(_lastFileError)));
        return false;
#endif
    }
#endif

#ifdef Q_OS_WIN
    // The physical drive handle now prevents competing writers. Releasing the
    // volume handles here also restores their mount-manager bindings later.
    lockedVolumes.release();
#endif

#ifdef Q_OS_LINUX
    /* Optional optimizations for Linux */

    if (_filename.startsWith("/dev/"))
    {
        QString devname = _filename.mid(5);

        /* On some internal SD card readers CID/CSD is available, print it for debugging purposes */
        QByteArray cid = _fileGetContentsTrimmed("/sys/block/"+devname+"/device/cid");
        QByteArray csd = _fileGetContentsTrimmed("/sys/block/"+devname+"/device/csd");
        if (!cid.isEmpty())
            qDebug() << "SD card CID:" << cid;
        if (!csd.isEmpty())
            qDebug() << "SD card CSD:" << csd;

        QByteArray discardmax = _fileGetContentsTrimmed("/sys/block/"+devname+"/queue/discard_max_bytes");

        if (discardmax.isEmpty() || discardmax == "0")
        {
            qDebug() << "BLKDISCARD not supported";
        }
        else
        {
            /* DISCARD/TRIM the SD card */
            uint64_t devsize, range[2];
            int fd = static_cast<int>(_file->nativeHandle());

            if (::ioctl(fd, BLKGETSIZE64, &devsize) == -1) {
                qDebug() << "Error getting device/sector size with BLKGETSIZE64 ioctl():" << strerror(errno);
            }
            else
            {
                qDebug() << "Try to perform TRIM/DISCARD on device";
                range[0] = 0;
                range[1] = devsize;
                emit preparationStatusUpdate(tr("discarding existing data on drive"));
                _timer.start();
                if (::ioctl(fd, BLKDISCARD, &range) == -1)
                {
                    qDebug() << "BLKDISCARD failed.";
                }
                else
                {
                    qDebug() << "BLKDISCARD successful. Discarding took" << _timer.elapsed() / 1000 << "seconds";
                }
            }
        }
    }
#endif

#ifndef Q_OS_WIN
    // Zero out MBR
    quint64 knownsize = 0;
    if (_file->size(knownsize) != FileError::Success)
    {
        emit error(tr("Cannot determine storage device size."));
        return false;
    }
    QByteArray emptyMB(1024*1024, 0);

    emit preparationStatusUpdate(tr("zeroing out first and last MB of drive"));
    qDebug() << "Zeroing out first and last MB of drive";
    _timer.start();

    std::size_t zeroed = 0;
    if (!_performDeviceWrite(reinterpret_cast<const quint8 *>(emptyMB.constData()),
                             static_cast<std::size_t>(emptyMB.size()), zeroed) ||
        !_flushDevice())
    {
        if (!_cancelled)
            emit error(tr("Write error while zero'ing out MBR"));
        return false;
    }

    // Zero out last part of card (may have GPT backup table)
    if (knownsize > static_cast<quint64>(emptyMB.size()))
    {
        zeroed = 0;
        if ((_lastFileError = _file->seek(knownsize-static_cast<quint64>(emptyMB.size()))) != FileError::Success ||
            !_performDeviceWrite(reinterpret_cast<const quint8 *>(emptyMB.constData()),
                                 static_cast<std::size_t>(emptyMB.size()), zeroed) ||
            !_flushDevice())
        {
            if (!_cancelled)
                emit error(tr("Write error while trying to zero out last part of card.<br>"
                              "Card could be advertising wrong capacity (possible counterfeit)."));
            return false;
        }
    }
    emptyMB.clear();
    if ((_lastFileError = _file->seek(0)) != FileError::Success)
    {
        emit error(tr("Cannot seek to the start of the storage device."));
        return false;
    }
    qDebug() << "Done zeroing out start and end of drive. Took" << _timer.elapsed() / 1000 << "seconds";
#endif

#ifdef Q_OS_LINUX
    _sectorsStart = _sectorsWritten();
#endif

    return true;
}

void DownloadThread::run()
{
    if (isImage() && !_openAndPrepareDevice())
    {
        return;
    }

    qDebug() << "Image URL:" << _url;
    if (_url.startsWith("file://") && _url.at(7) != '/')
    {
        /* libcurl does not like UNC paths in the form of file://1.2.3.4/share */
        _url.replace("file://", "file:////");
        qDebug() << "Corrected UNC URL to:" << _url;
    }

    char errorBuf[CURL_ERROR_SIZE] = {0};
    _c = curl_easy_init();
    if (!_c)
    {
        _onDownloadError(tr("Unable to initialize the download engine"));
        return;
    }
    CurlNetworkConfig &networkConfig = CurlNetworkConfig::instance();
    networkConfig.detectSystemProxy(QUrl::fromEncoded(_url));
    networkConfig.applyLargeFileSettings(_c, _useragent, errorBuf);
    curl_easy_setopt(_c, CURLOPT_WRITEFUNCTION, &DownloadThread::_curl_write_callback);
    curl_easy_setopt(_c, CURLOPT_WRITEDATA, this);
    curl_easy_setopt(_c, CURLOPT_XFERINFOFUNCTION, &DownloadThread::_curl_xferinfo_callback);
    curl_easy_setopt(_c, CURLOPT_PROGRESSDATA, this);
    curl_easy_setopt(_c, CURLOPT_NOPROGRESS, 0);
    curl_easy_setopt(_c, CURLOPT_URL, _url.constData());
    curl_easy_setopt(_c, CURLOPT_HEADERFUNCTION, &DownloadThread::_curl_header_callback);
    curl_easy_setopt(_c, CURLOPT_HEADERDATA, this);
    if (_inputBufferSize)
        curl_easy_setopt(_c, CURLOPT_BUFFERSIZE, _inputBufferSize);

    emit preparationStatusUpdate(tr("starting download"));
    _timer.start();
    CURLcode ret = curl_easy_perform(_c);

    CurlRetryPolicy retryPolicy;
    while (!_cancelled)
    {
        const bool transferAdvanced = _lastDlNow != _lastFailureOffset;
        const CurlRetryPolicy::Action retryAction = retryPolicy.next(ret, transferAdvanced);
        if (retryAction == CurlRetryPolicy::Action::Stop)
            break;

        time_t t = time(NULL);
        qWarning() << "Download interrupted:" << curl_easy_strerror(ret)
                   << "retry" << retryPolicy.retryCount() << "at offset" << _lastDlNow;

        if (retryAction == CurlRetryPolicy::Action::RetryWithHttp11)
        {
            qWarning() << "Retrying download with HTTP/1.1";
            curl_easy_setopt(_c, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
        }
        else if (retryAction == CurlRetryPolicy::Action::RetryWithIPv4)
        {
            qWarning() << "Retrying download with IPv4";
            curl_easy_setopt(_c, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
        }

        /* If last failure happened less than 5 seconds ago, something else may
           be wrong. Sleep some time to prevent hammering server */
        if (t - _lastFailureTime < 5)
        {
            qDebug() << "Backing off for 5 seconds";
            for (int waited = 0; waited < 50 && !_cancelled; ++waited)
                QThread::msleep(100);
        }
        _lastFailureTime = t;

        if (_cancelled)
        {
            ret = CURLE_ABORTED_BY_CALLBACK;
            break;
        }

        _startOffset = _lastDlNow;
        _lastFailureOffset = _lastDlNow;
        curl_easy_setopt(_c, CURLOPT_RESUME_FROM_LARGE, _startOffset);

        ret = curl_easy_perform(_c);
    }

    char *primaryIp = nullptr;
    char *effectiveUrl = nullptr;
    curl_easy_getinfo(_c, CURLINFO_PRIMARY_IP, &primaryIp);
    curl_easy_getinfo(_c, CURLINFO_EFFECTIVE_URL, &effectiveUrl);
    const QString primaryIpText = primaryIp ? QString::fromUtf8(primaryIp) : QString();
    const QString effectiveUrlText = effectiveUrl ? QString::fromUtf8(effectiveUrl) : QString();
    curl_easy_cleanup(_c);
    _c = nullptr;

    switch (ret)
    {
    case CURLE_OK:
        _successful = true;
        qDebug() << "Download done in" << _timer.elapsed() / 1000 << "seconds";
        _onDownloadSuccess();
        break;
    case CURLE_WRITE_ERROR:
        deleteDownloadedFile();

#ifdef Q_OS_WIN
        if (_lastFileError == FileError::AccessDenied)
        {
            QString msg = tr("Access denied error while writing file to disk.");
            QSettings registry("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows Defender\\Windows Defender Exploit Guard\\Controlled Folder Access",
                               QSettings::Registry64Format);
            if (registry.value("EnableControlledFolderAccess").toInt() == 1)
            {
                msg += "<br>"+tr("Controlled Folder Access seems to be enabled. Please add openhdimagewriter.exe to the list of allowed apps and try again.");
            }
            _onDownloadError(msg);
        }
        else
#endif
            if (!_cancelled)
                _onDownloadError(tr("Error writing file to disk"));
        break;
    case CURLE_ABORTED_BY_CALLBACK:
        deleteDownloadedFile();
        break;
    default:
        deleteDownloadedFile();
        QString errorMsg;

        if (!errorBuf[0])
            /* No detailed error message text provided, use standard text for libcurl result code */
            errorMsg += curl_easy_strerror(ret);
        else
            errorMsg += errorBuf;

        if (!primaryIpText.isEmpty())
            errorMsg += QString(" - Server IP: ") + primaryIpText;
        if (!effectiveUrlText.isEmpty() && effectiveUrlText != QString::fromUtf8(_url))
            errorMsg += QString(" - Effective URL: ") + effectiveUrlText;

        _onDownloadError(tr("Error downloading: %1").arg(errorMsg));
    }
}

size_t DownloadThread::_writeData(const char *buf, size_t len)
{
    _writeCache(buf, len);

    if (!_filename.isEmpty())
    {
        return _writeFile(buf, len);
    }
    else
    {
        _buf.append(buf, len);
        return len;
    }
}

void DownloadThread::_writeCache(const char *buf, size_t len)
{
    if (!_cacheEnabled || _cancelled)
        return;

    if (_cachefile.write(buf, len) != len)
    {
        qDebug() << "Error writing to cache file. Disabling caching.";
        _cacheEnabled = false;
        _cachefile.remove();
    }
}

void DownloadThread::setCacheFile(const QString &filename, qint64 filesize)
{
    _cachefile.setFileName(filename);
    if (_cachefile.open(QIODevice::WriteOnly))
    {
        _cacheEnabled = true;
        if (filesize)
        {
            /* Pre-allocate space */
            _cachefile.resize(filesize);
        }
    }
    else
    {
        qDebug() << "Error opening cache file for writing. Disabling caching.";
    }
}

void DownloadThread::_hashData(const char *buf, size_t len)
{
    _writehash.addData(buf, len);
}

bool DownloadThread::_writeBatch(const quint8 *data, std::size_t size)
{
    std::size_t written = 0;
    const bool succeeded = _performDeviceWrite(data, size, written);
    _bytesWritten += written;
    if (!succeeded)
    {
        qDebug() << "Write error:" << fileErrorMessage(_lastFileError)
                 << "while writing batch:" << size << "written:" << written;
        return false;
    }
    return true;
}

bool DownloadThread::_performDeviceWrite(const quint8 *data, std::size_t size,
                                         std::size_t &bytesWritten)
{
    bytesWritten = 0;
    for (int attempt = 0; attempt < 2 && bytesWritten < size; ++attempt)
    {
        std::size_t currentWrite = 0;
        _deviceOperationActive.store(true);
        _lastFileError = _file->writeSequential(data + bytesWritten, size - bytesWritten,
                                                currentWrite);
        _deviceOperationActive.store(false);
        bytesWritten += currentWrite;
        if (_lastFileError == FileError::Success && bytesWritten == size)
            return true;

        const bool watchdogCancelled =
            _lastFileError == FileError::Cancelled &&
            _watchdogRecoveryRequested.exchange(false) && !_cancelled.load();
        if (!watchdogCancelled)
            break;
        qWarning() << "Retrying interrupted device write in compatibility mode at byte"
                   << bytesWritten << "of" << size;
        _file->resetCancellation();
    }
    if (_lastFileError == FileError::Success)
        _lastFileError = FileError::IoError;
    return false;
}

bool DownloadThread::_flushDevice()
{
    for (int attempt = 0; attempt < 2; ++attempt)
    {
        _deviceOperationActive.store(true);
        _lastFileError = _file->flush();
        _deviceOperationActive.store(false);
        if (_lastFileError == FileError::Success)
            return true;

        const bool watchdogCancelled =
            _lastFileError == FileError::Cancelled &&
            _watchdogRecoveryRequested.exchange(false) && !_cancelled.load();
        if (!watchdogCancelled)
            return false;
        qWarning() << "Retrying interrupted device flush in compatibility mode";
        _file->resetCancellation();
    }
    return false;
}

size_t DownloadThread::_writeFile(const char *buf, size_t len)
{
    if (_cancelled)
        return len;

    if (!_firstBlock)
    {
        _writehash.addData(buf, len);
        _firstBlock = (char *) qMallocAligned(len, 4096);
        if (!_firstBlock)
        {
            _lastFileError = FileError::IoError;
            return 0;
        }
        _firstBlockSize = len;
        ::memcpy(_firstBlock, buf, len);

        _lastFileError = _file->seek(static_cast<quint64>(len));
        return _lastFileError == FileError::Success ? len : 0;
    }
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QFuture<void> wh = QtConcurrent::run(&DownloadThread::_hashData, this, buf, len);
#else
    QFuture<void> wh = QtConcurrent::run(this, &DownloadThread::_hashData, buf, len);
#endif

    const bool accepted = _writeBatcher->append(reinterpret_cast<const quint8 *>(buf), len);

    wh.waitForFinished();
    return accepted ? len : 0;
}

bool DownloadThread::_progress(curl_off_t dltotal, curl_off_t dlnow, curl_off_t /*ultotal*/, curl_off_t /*ulnow*/)
{
    if (dltotal)
        _lastDlTotal = _startOffset + dltotal;
    _lastDlNow   = _startOffset + dlnow;

    return !_cancelled;
}

void DownloadThread::_header(const string &header)
{
    if (header.compare(0, 6, "Date: ") == 0)
    {
        _serverTime = curl_getdate(header.data()+6, NULL);
    }
    else if (header.compare(0, 15, "Last-Modified: ") == 0)
    {
        _lastModified = curl_getdate(header.data()+15, NULL);
    }
    qDebug() << "Received header:" << header.c_str();
}

void DownloadThread::cancelDownload()
{
    _cancelled = true;
    _file->cancel();
    //deleteDownloadedFile();
}

bool DownloadThread::deviceOperationActive() const
{
    return _deviceOperationActive.load();
}

void DownloadThread::requestWriteRecovery()
{
    if (!_cancelled.load() && _deviceOperationActive.load())
    {
        _watchdogRecoveryRequested.store(true);
        _file->cancel();
    }
}

QByteArray DownloadThread::data()
{
    return _buf;
}

bool DownloadThread::successfull()
{
    return _successful;
}

time_t DownloadThread::lastModified()
{
    return _lastModified;
}

time_t DownloadThread::serverTime()
{
    return _serverTime;
}

void DownloadThread::deleteDownloadedFile()
{
    if (!_filename.isEmpty())
    {
        _file->close();
        if (_cachefile.isOpen())
            _cachefile.remove();
        if (!_filename.startsWith("/dev/") && !_filename.startsWith("\\\\.\\"))
        {
            //_file.remove();
        }
    }
}

uint64_t DownloadThread::dlNow()
{
    return _lastDlNow;
}

uint64_t DownloadThread::dlTotal()
{
    return _lastDlTotal;
}

uint64_t DownloadThread::verifyNow()
{
    return _lastVerifyNow;
}

uint64_t DownloadThread::verifyTotal()
{
    return _verifyTotal;
}

uint64_t DownloadThread::bytesWritten()
{
    if (_sectorsStart != -1)
        return qMin((uint64_t) (_sectorsWritten()-_sectorsStart)*512, (uint64_t) _bytesWritten);
    else
        return _bytesWritten;
}

void DownloadThread::_onDownloadSuccess()
{
    _writeComplete();
}

void DownloadThread::_onDownloadError(const QString &msg)
{
    _cancelled = true;
    emit error(msg);
}

void DownloadThread::_closeFiles()
{
    _file->close();
    if (_cachefile.isOpen())
        _cachefile.close();
}

void DownloadThread::_writeComplete()
{
    if (!_writeBatcher->flush())
    {
        if (!_cancelled)
            DownloadThread::_onDownloadError(tr("Error writing final block to storage"));
        _closeFiles();
        return;
    }

    QByteArray computedHash = _writehash.result().toHex();
    qDebug() << "Hash of uncompressed image:" << computedHash;
    if (!_expectedHash.isEmpty() && _expectedHash != computedHash)
    {
        qDebug() << "Mismatch with expected hash:" << _expectedHash;
        if (_cachefile.isOpen())
            _cachefile.remove();
        DownloadThread::_onDownloadError(tr("Download corrupt. Hash does not match"));
        _closeFiles();
        return;
    }
    if (_cacheEnabled && _expectedHash == computedHash)
    {
        _cachefile.close();
        emit cacheFileUpdated(computedHash);
    }

    if (!_flushDevice())
    {
        if (!_cancelled)
            DownloadThread::_onDownloadError(tr("Error writing to storage (while flushing)"));
        _closeFiles();
        return;
    }

    qDebug() << "Write done in" << _timer.elapsed() / 1000 << "seconds";

    /* Verify */
    if (_verifyEnabled && !_verify())
    {
        _closeFiles();
        return;
    }

    emit finalizing();

    if (_firstBlock)
    {
        qDebug() << "Writing first block (which we skipped at first)";
        std::size_t written = 0;
        if ((_lastFileError = _file->seek(0)) != FileError::Success ||
            !_performDeviceWrite(reinterpret_cast<const quint8 *>(_firstBlock),
                                 _firstBlockSize, written) ||
            !_flushDevice())
        {
            qFreeAligned(_firstBlock);
            _firstBlock = nullptr;

            if (!_cancelled)
                DownloadThread::_onDownloadError(tr("Error writing first block (partition table)"));
            return;
        }
        _bytesWritten += _firstBlockSize;
        qFreeAligned(_firstBlock);
        _firstBlock = nullptr;
    }

    _closeFiles();

#ifdef Q_OS_DARWIN
    QThread::sleep(1);
    _filename.replace("/dev/rdisk", "/dev/disk");
#endif
    QSettings settings_;

    const bool useSettings = settings_.value("useSettings").toBool();
    // qDebug() << "This is the Debug Filename" << _filename;
    // qDebug() << "This is the Debug Settings" << useSettings;

    if (!useSettings)
        eject_disk(_filename.constData());

    if (useSettings)
    {
        if (!_customizeImage())
            return;

        if (_ejectEnabled)
            eject_disk(_filename.constData());
    }

    emit success();
}

bool DownloadThread::_verify()
{
    char *verifyBuf = (char *) qMallocAligned(IMAGEWRITER_VERIFY_BLOCKSIZE, 4096);
    if (!verifyBuf)
    {
        DownloadThread::_onDownloadError(tr("Unable to allocate verification buffer."));
        return false;
    }
    _lastVerifyNow = 0;
    _verifyTotal = _file->position();
    QElapsedTimer t1;
    t1.start();

#ifdef Q_OS_LINUX
    /* Make sure we are reading from the drive and not from cache */
    //fcntl(_file->nativeHandle(), F_SETFL, O_DIRECT | fcntl(_file->nativeHandle(), F_GETFL));
    posix_fadvise(static_cast<int>(_file->nativeHandle()), 0, 0, POSIX_FADV_DONTNEED);
#endif

    if (!_firstBlock)
    {
        _lastFileError = _file->seek(0);
    }
    else
    {
        _verifyhash.addData(_firstBlock, _firstBlockSize);
        _lastFileError = _file->seek(_firstBlockSize);
        _lastVerifyNow += _firstBlockSize;
    }
    if (_lastFileError != FileError::Success)
    {
        qFreeAligned(verifyBuf);
        DownloadThread::_onDownloadError(tr("Error seeking on storage during verification."));
        return false;
    }

    while (_verifyEnabled && _lastVerifyNow < _verifyTotal && !_cancelled)
    {
        std::size_t lenRead = 0;
        const std::size_t requested = static_cast<std::size_t>(qMin(
            static_cast<quint64>(IMAGEWRITER_VERIFY_BLOCKSIZE),
            static_cast<quint64>(_verifyTotal-_lastVerifyNow)));
        _lastFileError = _file->readSequential(reinterpret_cast<quint8 *>(verifyBuf), requested, lenRead);
        if (_lastFileError != FileError::Success || lenRead == 0)
        {
            qFreeAligned(verifyBuf);
            if (_cancelled)
                return true;
            DownloadThread::_onDownloadError(tr("Error reading from storage.<br>"
                                                "SD card may be broken."));
            return false;
        }

        _verifyhash.addData(verifyBuf, static_cast<int>(lenRead));
        _lastVerifyNow += lenRead;
    }
    qFreeAligned(verifyBuf);

    qDebug() << "Verify hash:" << _verifyhash.result().toHex();
    qDebug() << "Verify done in" << t1.elapsed() / 1000.0 << "seconds";

    if (_verifyhash.result() == _writehash.result() || !_verifyEnabled || _cancelled)
    {
        return true;
    }
    else
    {
        DownloadThread::_onDownloadError(tr("Verifying write failed. Contents of SD card is different from what was written to it."));
    }

    return false;
}

void DownloadThread::setVerifyEnabled(bool verify)
{
    _verifyEnabled = verify;
}

bool DownloadThread::isImage()
{
    return true;
}

void DownloadThread::setInputBufferSize(int len)
{
    _inputBufferSize = len;
}

qint64 DownloadThread::_sectorsWritten()
{
#ifdef Q_OS_LINUX
    if (!_filename.startsWith("/dev/"))
        return -1;

    QFile f("/sys/class/block/"+_filename.mid(5)+"/stat");
    if (!f.open(f.ReadOnly))
        return -1;
    QByteArray ioline = f.readAll().simplified();
    f.close();

    QList<QByteArray> stats = ioline.split(' ');

    if (stats.count() >= 6)
        return stats.at(6).toLongLong(); /* write sectors */
#endif
    return -1;
}

bool DownloadThread::_customizeImage()
{
    QString folder;
    std::vector<std::string> mountpoints;
    QByteArray devlower = _filename.toLower();

    emit preparationStatusUpdate(tr("Waiting for FAT partition to be mounted"));

#ifdef Q_OS_WIN
    QString nativeError;
    if (!WindowsDiskPreparation::rescanDisk(QString::fromUtf8(_filename), &nativeError))
    {
        _onDownloadError(nativeError);
        return false;
    }
#endif

    /* See if OS auto-mounted the device */
    for (int tries = 0; tries < 3; tries++)
    {
        QThread::sleep(1);
        auto l = Drivelist::ListStorageDevices();
        for (auto i : l)
        {
            if (QByteArray::fromStdString(i.device).toLower() == devlower && i.mountpoints.size())
            {
                mountpoints = i.mountpoints;
                break;
            }
        }
    }

#ifdef Q_OS_WIN
    if (mountpoints.empty())
    {
        const QString mountpoint = WindowsDiskPreparation::ensureDriveLetter(
            QString::fromUtf8(_filename), 7000, &nativeError);
        if (mountpoint.isEmpty())
        {
            _onDownloadError(nativeError);
            return false;
        }
        mountpoints.push_back(mountpoint.toStdString());
    }
#endif

#ifdef Q_OS_LINUX
    bool manualmount = false;

    if (mountpoints.empty())
    {
        /* Manually mount folder */
        manualmount = true;
        auto makePartitionPath = [&](const QString &base, int n) -> QString {
            const QByteArray b = base.toLatin1();
            if (!b.isEmpty() && isdigit(static_cast<unsigned char>(b.at(b.size()-1))))
                return base + "p" + QString::number(n);
            return base + QString::number(n);
        };

        auto hasConfigTxt = [&](const QString &mp) -> bool {
            return QFileInfo::exists(mp + "/config.txt");
        };

        const bool isRoot = (::access(devlower.constData(), W_OK) == 0);
        bool found = false;

        // Assume no target have >128 partitions
        for (int part = 1; part <= 128 && !found; ++part)
        {
            const QString fatpartition = makePartitionPath(_filename, part);
            if (!QFileInfo::exists(fatpartition))
                continue;

            if (!isRoot) {
#ifndef QT_NO_DBUS
                UDisks2Api udisks2;
                QString mp = udisks2.mountDevice(fatpartition);
                if (mp.isEmpty())
                    continue; // not all partitions are made to be mounted

                if (hasConfigTxt(mp)) {
                    mountpoints.push_back(mp.toStdString());
                    found = true; // yay
                } else {
                    // not a config
                    QProcess::execute("udisksctl", QStringList() << "unmount" << "-b" << fatpartition);
                }
#else
                Q_UNUSED(fatpartition);
#endif
            } else {
                // Running as root: mount directly to a temp dir
                QTemporaryDir td;
                QString mp = td.path();
                QStringList args;
                args << "-t" << "vfat" << fatpartition << mp;

                if (QProcess::execute("mount", args) != 0)
                    continue; // not all partitions are made to be mounted

                if (hasConfigTxt(mp)) {
                    mountpoints.push_back(mp.toStdString());
                    td.setAutoRemove(false);
                    found = true; //yay
                } else {
                    QProcess::execute("umount", QStringList() << mp);
                }
            }
        }

        if (!found)
        {
            emit error(tr("Error mounting FAT32 partition or config.txt not found"));
            return false;
        }
    }
#endif

    if (mountpoints.empty())
    {
        //
        qDebug() << "drive info. searching for:" << devlower;
        auto l = Drivelist::ListStorageDevices();
        for (auto i : l)
        {
            qDebug() << "drive" << QByteArray::fromStdString(i.device).toLower();
            for (auto mp : i.mountpoints) {
                qDebug() << "mountpoint:" << QByteArray::fromStdString(mp);
            }
        }
        //

        emit error(tr("This Image doesn't support OpenHD settings, proceed with caution!"));
        return false;
    }

    /* Some operating system take longer to complete mounting FAT32
       wait up to 3 seconds for config.txt file to appear */
    QString configFilename;
    bool foundFile = false;

    for (int tries = 0; tries < 3; tries++)
    {
        /* Search all mountpoints, as on some systems FAT partition
           may not be first volume */
        for (auto mp : mountpoints)
        {
            folder = QString::fromStdString(mp);
            if (folder.right(1) == '\\')
                folder.chop(1);
            configFilename = folder+"/config.txt";

            if (QFile::exists(configFilename))
            {
                foundFile = true;
                break;
            }
        }
        if (foundFile)
            break;
        QThread::sleep(1);
    }

    if (!foundFile)
    {
        emit error(tr("Unable to customize. File '%1' does not exist.").arg(configFilename));
        return false;
    }

    emit preparationStatusUpdate(tr("Customizing image"));

    if (!_config.isEmpty())
    {
        auto configItems = _config.split('\n');
        configItems.removeAll("");
        QByteArray config;

        QFile f(configFilename);
        if (f.open(f.ReadOnly))
        {
            config = f.readAll();
            f.close();
        }

        for (QByteArray item : configItems)
        {
            if (config.contains("#"+item)) {
                /* Uncomment existing line */
                config.replace("#"+item, item);
            } else if (config.contains("\n"+item)) {
                /* config.txt already contains the line */
            } else {
                /* Append new line to config.txt */
                if (config.right(1) != "\n")
                    config += "\n"+item+"\n";
                else
                    config += item+"\n";
            }
        }

        if (f.open(f.WriteOnly) && f.write(config) == config.length())
        {
            f.close();
        }
        else
        {
            emit error(tr("Error writing to config.txt on FAT partition"));
            return false;
        }
    }

    if (_initFormat == "auto")
    {
        /* Do an attempt at auto-detecting what customization format a custom
           image provided by the user supports */
        QByteArray issue;
        QFile fi(folder+"/issue.txt");
        if (fi.exists() && fi.open(fi.ReadOnly))
        {
            issue = fi.readAll();
            fi.close();
        }

        if (QFile::exists(folder+"/user-data"))
        {
            /* If we have user-data file on FAT partition, then it must be cloudinit */
            _initFormat = "cloudinit";
            qDebug() << "user-data found on FAT partition. Assuming cloudinit support";
        }
        else if (issue.contains("pi-gen"))
        {
            /* If issue.txt mentions pi-gen, and there is no user-data file assume
             * it is a RPI OS flavor, and use the old systemd unit firstrun script stuff */
            _initFormat = "systemd";
            qDebug() << "copying openhd detection file";
        }
        else
        {
            /* Fallback to writing cloudinit file, as it does not hurt having one
             * Will just have no customization if OS does not support it */
            _initFormat = "cloudinit";
            qDebug() << "Unknown what customization method image supports. Falling back to cloudinit";
        }
    }

    QSettings settings_;
    if (settings_.value("justUpdate").toBool())
        qDebug() << "Writing OpenHD-Update";

    qDebug() << "Writing OpenHD-Settings";
    const OpenHDImageCustomizer::Result customizationResult =
        OpenHDImageCustomizer::apply(folder, settings_);
    if (!customizationResult.succeeded())
    {
        QString message;
        switch (customizationResult.error)
        {
        case OpenHDImageCustomizer::Error::CreateDirectory:
            message = tr("Error creating openhd folder on FAT partition");
            break;
        case OpenHDImageCustomizer::Error::WriteSettings:
            message = tr("Error writing settings.json on FAT partition");
            break;
        case OpenHDImageCustomizer::Error::QOpenHDConfigNotFound:
            message = tr("QOpenHD.conf not found at the selected path.");
            break;
        case OpenHDImageCustomizer::Error::ReplaceQOpenHDConfig:
            message = tr("Error replacing existing QOpenHD.conf on FAT partition");
            break;
        case OpenHDImageCustomizer::Error::CopyQOpenHDConfig:
            message = tr("Error copying QOpenHD.conf to FAT partition");
            break;
        case OpenHDImageCustomizer::Error::InvalidCertificate:
            message = tr("Premium certificate is invalid: %1").arg(customizationResult.detail);
            break;
        case OpenHDImageCustomizer::Error::ReplaceCertificate:
            message = tr("Error replacing existing premium certificate on FAT partition");
            break;
        case OpenHDImageCustomizer::Error::CopyCertificate:
            message = tr("Error copying premium certificate to FAT partition");
            break;
        case OpenHDImageCustomizer::Error::None:
            break;
        }

        emit error(message);
        return false;
    }
    emit finalizing();

#ifdef Q_OS_LINUX
    if (manualmount)
    {
        if (::access(devlower.constData(), W_OK) != 0)
        {
#ifndef QT_NO_DBUS
            UDisks2Api udisks2;
            udisks2.unmountDrive(devlower);
#endif
        }
        else
        {
            QStringList args;
            args << folder;
            QProcess::execute("umount", args);
            QDir d;
            d.rmdir(folder);
        }
    }
#endif

#ifndef Q_OS_WIN
    ::sync();
#endif

    return true;
}
