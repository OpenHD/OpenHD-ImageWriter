#ifndef LOCALFILEEXTRACTTHREAD_H
#define LOCALFILEEXTRACTTHREAD_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "downloadextractthread.h"
#include <QFile>
#ifdef _WIN32
// Modern MinGW64 (GCC 15+) already defines ssize_t properly, so we don't need to define it
// This manual typedef was only needed for very old MinGW versions
#if defined(__MINGW32__) && !defined(__MINGW64_VERSION_MAJOR) && (_WIN32_WINNT < 0x0600)
typedef long ssize_t;
#endif
#endif

class LocalFileExtractThread : public DownloadExtractThread
{
    Q_OBJECT
public:
    explicit LocalFileExtractThread(const QByteArray &url, const QByteArray &dst = "", const QByteArray &expectedHash = "", QObject *parent = nullptr);
    virtual ~LocalFileExtractThread();

protected:
    virtual void _cancelExtract();
    virtual void run();
    virtual ssize_t _on_read(struct archive *a, const void **buff);
    virtual int _on_close(struct archive *a);
    QFile _inputfile;
    char *_inputBuf;
};

#endif // LOCALFILEEXTRACTTHREAD_H
