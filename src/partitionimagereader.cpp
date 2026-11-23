#include "partitionimagereader.h"

#include "config.h"
#include <archive.h>
#include <archive_entry.h>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <algorithm>

namespace {
constexpr qint64 NetworkBudget = 64LL * 1024 * 1024;
constexpr quint64 NetworkDecodedBudget = 256ULL * 1024 * 1024;
constexpr qint64 NetworkDeadlineMs = 30000;

using Archive = std::unique_ptr<struct archive, decltype(&archive_read_free)>;

Archive makeArchive()
{
    Archive reader(archive_read_new(), &archive_read_free);
    archive_read_support_filter_all(reader.get());
    archive_read_support_format_zip(reader.get());
    archive_read_support_format_7zip(reader.get());
    archive_read_support_format_raw(reader.get());
    return reader;
}

bool nextFile(struct archive *reader, struct archive_entry **entry)
{
    int status;
    do {
        status = archive_read_next_header(reader, entry);
    } while (status == ARCHIVE_OK && archive_entry_filetype(*entry) == AE_IFDIR);
    return status == ARCHIVE_OK && archive_entry_filetype(*entry) == AE_IFREG;
}

QString entryPath(struct archive_entry *entry)
{
    const char *path = archive_entry_pathname_utf8(entry);
    return QString::fromUtf8(path ? path : archive_entry_pathname(entry));
}

bool isNestedArchive(QString name)
{
    name = name.toLower();
    return name.endsWith(".xz") || name.endsWith(".bz2") || name.endsWith(".gz") ||
           name.endsWith(".zst") || name.endsWith(".7z") || name.endsWith(".zip");
}
}

struct PartitionImageReader::Input
{
    Input(const QUrl &source, const std::atomic_bool &stop)
        : url(source), cancelled(stop), file(source.toLocalFile()) { elapsed.start(); }

    QUrl url;
    const std::atomic_bool &cancelled;
    QFile file;
    std::unique_ptr<QNetworkAccessManager> network;
    QNetworkReply *reply = nullptr;
    QElapsedTimer elapsed;
    QByteArray buffer = QByteArray(64 * 1024, Qt::Uninitialized);
    QByteArray nestedBuffer = QByteArray(64 * 1024, Qt::Uninitialized);
    Archive outer{nullptr, &archive_read_free};
    Archive nested{nullptr, &archive_read_free};
    bool compressed = false;
    bool unavailable = false;
    qint64 networkBytes = 0;
    qint64 networkSize = 0;
    qint64 networkOffset = 0;
    qint64 requestOffset = 0;
    quint64 cursor = 0;
    quint64 imageBytes = 0;
    quint64 entryBytes = 0;

    struct archive *imageArchive() const { return nested ? nested.get() : outer.get(); }

    void openNetwork(qint64 offset)
    {
        if (!network)
            network.reset(new QNetworkAccessManager);
        delete reply;
        QNetworkRequest request(url);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        request.setRawHeader("Accept-Encoding", "identity");
        request.setRawHeader("Range", "bytes=" + QByteArray::number(offset) + "-");
        requestOffset = networkOffset = offset;
        reply = network->get(request);
        reply->setReadBufferSize(buffer.size());
    }

    bool waitForNetworkData()
    {
        while (!reply->bytesAvailable() && !reply->isFinished() && !cancelled.load() &&
               elapsed.elapsed() < NetworkDeadlineMs) {
            QEventLoop wait;
            QTimer poll;
            poll.setSingleShot(true);
            QObject::connect(&poll, &QTimer::timeout, &wait, &QEventLoop::quit);
            QObject::connect(reply, &QNetworkReply::readyRead, &wait, &QEventLoop::quit);
            QObject::connect(reply, &QNetworkReply::finished, &wait, &QEventLoop::quit);
            poll.start(100);
            wait.exec();
        }
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool validRange = status == 206 && reply->rawHeader("Content-Range")
            .startsWith("bytes " + QByteArray::number(requestOffset) + "-");
        if (cancelled.load() || elapsed.elapsed() >= NetworkDeadlineMs || networkBytes >= NetworkBudget ||
            reply->error() != QNetworkReply::NoError ||
            (!validRange && (status != 200 || requestOffset != 0))) {
            unavailable = true;
            return false;
        }
        return true;
    }

    qint64 readNetwork(char *data, qint64 length)
    {
        if (networkSize && networkOffset == networkSize)
            return 0;
        if (!waitForNetworkData())
            return -1;
        if (!reply->bytesAvailable() && reply->isFinished())
            return 0;
        const qint64 n = reply->read(data, std::min(length, NetworkBudget - networkBytes));
        if (n > 0) {
            networkBytes += n;
            networkOffset += n;
        }
        return n;
    }

    static la_ssize_t readSource(struct archive *, void *data, const void **buffer)
    {
        auto &self = *static_cast<Input *>(data);
        if (self.cancelled.load())
            return -1;
        char *bytes = self.buffer.data();
        *buffer = bytes;
        return self.reply ? self.readNetwork(bytes, self.buffer.size())
                          : self.file.read(bytes, self.buffer.size());
    }

    static la_int64_t seekSource(struct archive *, void *data, la_int64_t offset, int whence)
    {
        auto &self = *static_cast<Input *>(data);
        const bool local = self.file.isOpen();
        const qint64 length = local ? self.file.size() : self.networkSize;
        const qint64 position = local ? self.file.pos() : self.networkOffset;
        const qint64 base = whence == SEEK_END ? length : (whence == SEEK_CUR ? position : 0);
        if (offset < -base || offset > length - base)
            return ARCHIVE_FATAL;
        const qint64 target = base + offset;
        if (local)
            return self.file.seek(target) ? target : ARCHIVE_FATAL;
        if (target == length)
            self.networkOffset = target;
        else if (target != position)
            self.openNetwork(target);
        return target;
    }

    static la_ssize_t readNested(struct archive *, void *data, const void **buffer)
    {
        auto &self = *static_cast<Input *>(data);
        if (self.cancelled.load())
            return -1;
        char *bytes = self.nestedBuffer.data();
        *buffer = bytes;
        return archive_read_data(self.outer.get(), bytes, self.nestedBuffer.size());
    }

    bool openOuter()
    {
        outer = makeArchive();
        if (file.isOpen() || networkSize)
            archive_read_set_seek_callback(outer.get(), &seekSource);
        return archive_read_open(outer.get(), this, nullptr, &readSource, nullptr) == ARCHIVE_OK;
    }

    bool reset()
    {
        nested.reset();
        outer.reset();
        cursor = 0;
        entryBytes = 0;
        if (url.isLocalFile()) {
            if ((!file.isOpen() && !file.open(QIODevice::ReadOnly)) || !file.seek(0))
                return false;
        } else {
            openNetwork(0);
            if (!waitForNetworkData())
                return false;
            const QByteArray range = reply->rawHeader("Content-Range");
            networkSize = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 206
                ? range.mid(range.lastIndexOf('/') + 1).toLongLong() : 0;
        }
        if (!compressed)
            return true;

        struct archive_entry *entry = nullptr;
        if (!openOuter() || !nextFile(outer.get(), &entry))
            return false;
        if ((archive_format(outer.get()) & ARCHIVE_FORMAT_BASE_MASK) != ARCHIVE_FORMAT_RAW &&
            isNestedArchive(entryPath(entry))) {
            nested = makeArchive();
            if (archive_read_open(nested.get(), this, nullptr, &readNested, nullptr) != ARCHIVE_OK ||
                !nextFile(nested.get(), &entry))
                return false;
        }
        if (archive_entry_size_is_set(entry) && archive_entry_size(entry) > 0)
            entryBytes = quint64(archive_entry_size(entry));
        return true;
    }

    qint64 read(char *data, qint64 length)
    {
        if (cancelled.load())
            return -1;
        if (reply && (cursor >= NetworkDecodedBudget || elapsed.elapsed() >= NetworkDeadlineMs)) {
            unavailable = true;
            return -1;
        }
        const qint64 n = compressed ? archive_read_data(imageArchive(), data, length)
                                    : (reply ? readNetwork(data, length) : file.read(data, length));
        if (n > 0)
            cursor += quint64(n);
        return n;
    }
};

PartitionImageReader::PartitionImageReader(const QUrl &source, const std::atomic_bool &cancelled)
    : input(new Input(source, cancelled)) {}
PartitionImageReader::~PartitionImageReader() = default;

bool PartitionImageReader::open(bool compressed, quint64 sizeHint, quint64 capacity)
{
    input->compressed = compressed;
    if (!input->reset())
        return false;
    if (input->file.isOpen() && !compressed) {
        input->imageBytes = quint64(input->file.size());
    } else if (input->entryBytes) {
        input->imageBytes = input->entryBytes;
    } else if (sizeHint) {
        input->imageBytes = sizeHint;
    } else if (input->reply && !compressed) {
        input->imageBytes = input->networkSize > 0 ? quint64(input->networkSize)
            : input->reply->header(QNetworkRequest::ContentLengthHeader).toULongLong();
    } else if (input->file.isOpen()) {
        // Raw compression filters have no entry length. Count in the worker
        // with bounded memory, stopping as soon as the image cannot fit.
        QByteArray chunk(IMAGEWRITER_BLOCKSIZE, Qt::Uninitialized);
        qint64 n;
        do {
            n = input->read(chunk.data(), chunk.size());
        } while (n > 0 && input->cursor <= capacity);
        if (n < 0)
            return false;
        input->imageBytes = input->cursor;
        if (input->imageBytes <= capacity && !input->reset())
            return false;
    }
    if (!input->imageBytes && input->reply)
        input->unavailable = true;
    return input->imageBytes != 0;
}

bool PartitionImageReader::zipContents(const QString &path, quint64 &imageSize, bool &multipleFiles)
{
    const std::atomic_bool cancelled(false);
    Input source(QUrl::fromLocalFile(path), cancelled);
    if (!source.file.open(QIODevice::ReadOnly) || !source.openOuter())
        return false;
    int status;
    int files = 0;
    quint64 bytes = 0;
    bool nestedImage = false;
    struct archive_entry *entry = nullptr;
    while ((status = archive_read_next_header(source.outer.get(), &entry)) == ARCHIVE_OK) {
        if ((archive_format(source.outer.get()) & ARCHIVE_FORMAT_BASE_MASK) != ARCHIVE_FORMAT_ZIP)
            return false;
        if (archive_entry_filetype(entry) == AE_IFDIR)
            continue;
        const qint64 size = archive_entry_size(entry);
        if (size <= 0)
            continue;
        ++files;
        bytes += quint64(size);
        nestedImage = isNestedArchive(entryPath(entry));
    }
    if (status != ARCHIVE_EOF || !files)
        return false;
    multipleFiles = files > 1;
    imageSize = !multipleFiles && nestedImage ? 0 : bytes;
    return true;
}

bool PartitionImageReader::previewUnavailable() const { return input->unavailable; }

FileError PartitionImageReader::close()
{
    input->nested.reset();
    input->outer.reset();
    input->file.close();
    delete input->reply;
    input->reply = nullptr;
    return FileError::Success;
}

bool PartitionImageReader::isOpen() const { return input->file.isOpen() || input->reply; }

FileError PartitionImageReader::readSequential(quint8 *data, std::size_t length, std::size_t &n)
{
    n = 0;
    while (n < length) {
        const qint64 count = input->read(reinterpret_cast<char *>(data + n), qint64(length - n));
        if (count < 0)
            return FileError::IoError;
        if (!count)
            break;
        n += std::size_t(count);
    }
    return FileError::Success;
}

FileError PartitionImageReader::seek(quint64 offset)
{
    if (!input->compressed && input->file.isOpen()) {
        if (!input->file.seek(qint64(offset)))
            return FileError::IoError;
        input->cursor = offset;
        return FileError::Success;
    }
    if (offset < input->cursor && !input->reset())
        return FileError::IoError;
    QByteArray chunk(64 * 1024, Qt::Uninitialized);
    while (input->cursor < offset) {
        const auto count = std::min<quint64>(offset - input->cursor, chunk.size());
        if (input->read(chunk.data(), qint64(count)) <= 0)
            return FileError::IoError;
    }
    return FileError::Success;
}

quint64 PartitionImageReader::position() const { return input->cursor; }
FileError PartitionImageReader::size(quint64 &bytes) const { bytes = input->imageBytes; return FileError::Success; }
