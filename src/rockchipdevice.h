#ifndef ROCKCHIPDEVICE_H
#define ROCKCHIPDEVICE_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QByteArray>
#include <QList>
#include <QMetaType>
#include <QString>
#include <QtGlobal>
#include <vector>

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

struct RockchipDeviceDescriptor
{
    QString id;
    QString location;
    QString displayName;
    QString socName;
    quint16 vendorId = 0;
    quint16 productId = 0;
    quint16 bcdUsb = 0;
    bool isMaskrom = false;
    bool isLoader = false;
};

struct RockchipPartition
{
    QString name;
    quint32 offset = 0; // in 512-byte sectors (LBA)
    quint32 size = 0;   // in 512-byte sectors (0 = until next partition / remaining)
    QString fileName;    // filename in package or on disk
};

std::vector<RockchipDeviceDescriptor> listRockchipUsbDevices();
QString rockchipSocName(quint16 vendorId, quint16 productId);
QString rockchipBoardName(quint16 vendorId, quint16 productId);
QByteArray loadDefaultBootloader();

QList<RockchipPartition> parseParameterTxt(const QByteArray &paramContent);
QByteArray makeParameterBuffer(const QByteArray &paramContent);

bool downloadRockchipBootloader(const QByteArray &bootloaderData, QString *errorMsg = nullptr);
bool waitForRockchipLoaderMode(int timeoutMs = 15000, RockchipDeviceDescriptor *outDescriptor = nullptr);

class RockchipTransport
{
public:
    RockchipTransport();
    ~RockchipTransport();

    bool open(QString *errorMsg = nullptr);
    void close();
    bool isOpen() const;

    bool writeLBA(quint32 lba, quint16 sectorCount, const quint8 *data, QString *errorMsg = nullptr);
    bool resetDevice(QString *errorMsg = nullptr);

private:
#ifdef Q_OS_WIN
    HANDLE _hReadPipe = INVALID_HANDLE_VALUE;
    HANDLE _hWritePipe = INVALID_HANDLE_VALUE;
    HANDLE _hDevice = INVALID_HANDLE_VALUE;
#endif
    quint32 _tag = 0;
};

Q_DECLARE_METATYPE(std::vector<RockchipDeviceDescriptor>)

#endif // ROCKCHIPDEVICE_H
