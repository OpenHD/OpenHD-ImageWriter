#ifndef PARTITIONIMAGEREADER_H
#define PARTITIONIMAGEREADER_H

#include "file_operations.h"
#include <QUrl>
#include <atomic>

class PartitionImageReader final : public FileOperations
{
public:
    PartitionImageReader(const QUrl &source, const std::atomic_bool &cancelled);
    ~PartitionImageReader() override;
    bool open(bool compressed, quint64 sizeHint, quint64 capacity);
    bool previewUnavailable() const;
    static bool zipContents(const QString &path, quint64 &imageSize, bool &multipleFiles);

    FileError openDevice(const QString &, bool) override { return FileError::AccessDenied; }
    FileError adoptNativeHandle(qintptr, bool, bool) override { return FileError::AccessDenied; }
    FileError close() override;
    bool isOpen() const override;
    qintptr nativeHandle() const override { return -1; }
    FileError writeSequential(const quint8 *, std::size_t, std::size_t &n) override { n = 0; return FileError::AccessDenied; }
    FileError readSequential(quint8 *data, std::size_t length, std::size_t &n) override;
    FileError seek(quint64 offset) override;
    quint64 position() const override;
    FileError size(quint64 &bytes) const override;
    FileError flush() override { return FileError::AccessDenied; }
    void cancel() override {}
    void resetCancellation() override {}

private:
    struct Input;
    std::unique_ptr<Input> input;
};

#endif
