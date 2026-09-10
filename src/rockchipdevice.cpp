#include "rockchipdevice.h"

#include <QDebug>
#include <QFile>

namespace {

constexpr quint16 RockchipVendorId = 0x2207;

} // namespace

QString rockchipSocName(quint16 vendorId, quint16 productId)
{
    if (vendorId != RockchipVendorId)
        return QString();
    switch (productId) {
    case 0x110f:
        return QStringLiteral("RV1126B");
    case 0x110b:
        return QStringLiteral("RV1126 / RV1109");
    case 0x350a:
        return QStringLiteral("RK3566 / RK3568");
    case 0x350b:
    case 0x3588:
        return QStringLiteral("RK3588");
    case 0x330c:
        return QStringLiteral("RK3399");
    case 0x320c:
        return QStringLiteral("RK3328");
    case 0x310c:
        return QStringLiteral("RK3288");
    default:
        return QStringLiteral("Rockchip");
    }
}

QString rockchipBoardName(quint16 vendorId, quint16 productId)
{
    if (vendorId == RockchipVendorId && productId == 0x110f)
        return QStringLiteral("OpenHD X21 (RV1126B)");
    return rockchipSocName(vendorId, productId);
}

QByteArray loadDefaultBootloader()
{
    QFile f(QStringLiteral(":/rockchip/MiniLoaderAll.bin"));
    if (f.open(QIODevice::ReadOnly))
    {
        return f.readAll();
    }
    return QByteArray();
}

namespace {

RockchipDeviceDescriptor makeDescriptor(quint16 productId, quint16 bcdUsb,
                                        const QString &location)
{
    RockchipDeviceDescriptor result;
    result.vendorId = RockchipVendorId;
    result.productId = productId;
    result.bcdUsb = bcdUsb;
    result.location = location;
    // This is the same discriminator used by Rockchip's rkdeveloptool.
    result.isMaskrom = (bcdUsb & 1u) == 0;
    result.isLoader = !result.isMaskrom;
    result.socName = rockchipSocName(RockchipVendorId, productId);
    result.displayName = rockchipBoardName(RockchipVendorId, productId);
    result.id = QStringLiteral("rockusb://%1:%2/%3")
            .arg(result.vendorId, 4, 16, QLatin1Char('0'))
            .arg(result.productId, 4, 16, QLatin1Char('0'))
            .arg(location);
    return result;
}

} // namespace

#ifdef Q_OS_WIN

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winioctl.h>
#include <setupapi.h>
#include <usbioctl.h>
#include <usbiodef.h>
#include <vector>

std::vector<RockchipDeviceDescriptor> listRockchipUsbDevices()
{
    std::vector<RockchipDeviceDescriptor> result;
    HDEVINFO deviceInfo = SetupDiGetClassDevsW(&GUID_DEVINTERFACE_USB_HUB, nullptr, nullptr,
                                               DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (deviceInfo == INVALID_HANDLE_VALUE)
        return result;

    for (DWORD index = 0; ; ++index)
    {
        SP_DEVICE_INTERFACE_DATA interfaceData = {};
        interfaceData.cbSize = sizeof(interfaceData);
        if (!SetupDiEnumDeviceInterfaces(deviceInfo, nullptr, &GUID_DEVINTERFACE_USB_HUB,
                                         index, &interfaceData))
            break;

        DWORD requiredSize = 0;
        SetupDiGetDeviceInterfaceDetailW(deviceInfo, &interfaceData, nullptr, 0,
                                         &requiredSize, nullptr);
        if (!requiredSize)
            continue;

        std::vector<unsigned char> detailBuffer(requiredSize);
        auto detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W *>(detailBuffer.data());
        detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        if (!SetupDiGetDeviceInterfaceDetailW(deviceInfo, &interfaceData, detail, requiredSize,
                                              nullptr, nullptr))
            continue;

        HANDLE hub = CreateFileW(detail->DevicePath, GENERIC_WRITE, FILE_SHARE_WRITE,
                                 nullptr, OPEN_EXISTING, 0, nullptr);
        if (hub == INVALID_HANDLE_VALUE)
            continue;

        USB_NODE_INFORMATION node = {};
        node.NodeType = UsbHub;
        DWORD bytesReturned = 0;
        if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_INFORMATION, &node, sizeof(node),
                             &node, sizeof(node), &bytesReturned, nullptr))
        {
            CloseHandle(hub);
            continue;
        }

        const ULONG portCount = node.u.HubInformation.HubDescriptor.bNumberOfPorts;
        for (ULONG port = 1; port <= portCount; ++port)
        {
            // Leave room for the variable length pipe list returned by the ioctl.
            std::vector<unsigned char> connectionBuffer(4096);
            auto connection = reinterpret_cast<PUSB_NODE_CONNECTION_INFORMATION_EX>(connectionBuffer.data());
            connection->ConnectionIndex = port;
            if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX,
                                 connection, connectionBuffer.size(), connection,
                                 connectionBuffer.size(), &bytesReturned, nullptr))
                continue;

            const USB_DEVICE_DESCRIPTOR &descriptor = connection->DeviceDescriptor;
            if (connection->ConnectionStatus != DeviceConnected ||
                    descriptor.idVendor != RockchipVendorId || (descriptor.idProduct >> 8) == 0)
                continue;

            const QString hubPath = QString::fromWCharArray(detail->DevicePath);
            const QString location = QStringLiteral("%1#%2").arg(hubPath).arg(port);
            result.push_back(makeDescriptor(descriptor.idProduct, descriptor.bcdUSB, location));
        }
        CloseHandle(hub);
    }

    SetupDiDestroyDeviceInfoList(deviceInfo);
    return result;
}

#elif defined(Q_OS_LINUX)

#include <QDir>
#include <QFile>

namespace {

bool readUsbHexValue(const QString &path, quint16 &value)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    bool ok = false;
    value = QString::fromLatin1(file.readAll()).trimmed().toUShort(&ok, 16);
    return ok;
}

} // namespace

std::vector<RockchipDeviceDescriptor> listRockchipUsbDevices()
{
    std::vector<RockchipDeviceDescriptor> result;
    QDir usbDevices(QStringLiteral("/sys/bus/usb/devices"));
    const QFileInfoList entries = usbDevices.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &entry : entries)
    {
        quint16 vendorId = 0;
        quint16 productId = 0;
        quint16 bcdUsb = 0;
        if (!readUsbHexValue(entry.filePath() + QStringLiteral("/idVendor"), vendorId) ||
                !readUsbHexValue(entry.filePath() + QStringLiteral("/idProduct"), productId) ||
                !readUsbHexValue(entry.filePath() + QStringLiteral("/bcdUSB"), bcdUsb) ||
                vendorId != RockchipVendorId || (productId >> 8) == 0)
            continue;

        result.push_back(makeDescriptor(productId, bcdUsb, entry.fileName()));
    }
    return result;
}

#else

std::vector<RockchipDeviceDescriptor> listRockchipUsbDevices()
{
    // macOS support will use IOUSBHost in the flashing backend. Keep storage
    // polling functional on platforms where native USB enumeration is absent.
    return {};
}

#endif

#include <QElapsedTimer>
#include <QThread>
#include <QtEndian>

namespace {

quint16 calculateCrcCcitt(const quint8 *data, quint32 length)
{
    quint16 crc = 0xFFFF;
    for (quint32 i = 0; i < length; ++i)
    {
        quint8 ch = data[i];
        for (quint32 bit = 0x80; bit != 0; bit >>= 1)
        {
            if ((crc & 0x8000) != 0)
                crc = ((crc << 1) ^ 0x1021);
            else
                crc <<= 1;
            if ((ch & bit) != 0)
                crc ^= 0x1021;
        }
    }
    return crc;
}

quint32 calculateCrc32(const quint8 *data, quint32 length)
{
    quint32 crc = 0xFFFFFFFF;
    for (quint32 i = 0; i < length; ++i)
    {
        crc ^= data[i];
        for (int j = 0; j < 8; ++j)
            crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
    return ~crc;
}

#pragma pack(push, 1)
struct RkBootHeader
{
    quint32 tag; // 'LDR ' = 0x2052444C
    quint16 size;
    quint32 version;
    quint32 mergeVersion;
    quint8 releaseTime[7];
    quint32 chipType;
    quint8 count471;
    quint32 offset471;
    quint8 size471;
    quint8 count472;
    quint32 offset472;
    quint8 size472;
    quint8 countLoader;
    quint32 offsetLoader;
    quint8 sizeLoader;
    quint8 signFlag;
    quint8 rc4Flag;
    quint8 reserved[57];
};

struct RkBootEntry
{
    quint8 size;
    quint32 type;
    wchar_t name[20];
    quint32 dataOffset;
    quint32 dataSize;
    quint32 dataDelay;
};

struct RockchipCBW
{
    quint32 signature = 0x43425355; // 'USBC'
    quint32 tag = 0;
    quint32 transferLength = 0;
    quint8 flags = 0; // 0x00 = host-to-device
    quint8 lun = 0;
    quint8 length = 0x0A;
    // CBWCB (16 bytes)
    quint8 opcode = 0x15; // 0x15 = WRITE_LBA
    quint8 subcode = 0;
    quint32 address = 0; // Big-Endian
    quint8 reserved = 0;
    quint16 sectorCount = 0; // Big-Endian
    quint8 pad[7] = {0};
};

struct RockchipCSW
{
    quint32 signature = 0; // 'USBS' = 0x53425355
    quint32 tag = 0;
    quint32 dataResidue = 0;
    quint8 status = 0; // 0 = success
};
#pragma pack(pop)

#ifdef Q_OS_WIN
static const GUID GUID_DEVINTERFACE_USB_DEVICE_VAL =
    { 0xA5DCBF10L, 0x6530, 0x11D2, { 0x90, 0x1F, 0x00, 0xC0, 0x4F, 0xB9, 0x51, 0xED } };

static QString findRockchipDevicePath()
{
    HDEVINFO devInfo = SetupDiGetClassDevsW(&GUID_DEVINTERFACE_USB_DEVICE_VAL, nullptr, nullptr,
                                            DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (devInfo == INVALID_HANDLE_VALUE)
        return QString();

    QString foundPath;
    SP_DEVICE_INTERFACE_DATA ifData = {};
    ifData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(devInfo, nullptr, &GUID_DEVINTERFACE_USB_DEVICE_VAL, i, &ifData); ++i)
    {
        DWORD reqSize = 0;
        SetupDiGetDeviceInterfaceDetailW(devInfo, &ifData, nullptr, 0, &reqSize, nullptr);
        if (!reqSize)
            continue;

        std::vector<unsigned char> buf(reqSize);
        auto detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W *>(buf.data());
        detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        if (SetupDiGetDeviceInterfaceDetailW(devInfo, &ifData, detail, reqSize, nullptr, nullptr))
        {
            QString path = QString::fromWCharArray(detail->DevicePath);
            if (path.contains(QStringLiteral("vid_2207"), Qt::CaseInsensitive))
            {
                foundPath = path;
                break;
            }
        }
    }

    SetupDiDestroyDeviceInfoList(devInfo);
    return foundPath;
}
#endif

} // namespace

QList<RockchipPartition> parseParameterTxt(const QByteArray &paramContent)
{
    QList<RockchipPartition> partitions;
    const QString text = QString::fromUtf8(paramContent);
    const QStringList lines = text.split(QLatin1Char('\n'));

    for (const QString &rawLine : lines)
    {
        QString line = rawLine.trimmed();
        if (line.startsWith(QLatin1Char('#')) || !line.contains(QStringLiteral("mtdparts")))
            continue;

        int colonIdx = line.indexOf(QLatin1Char(':'));
        if (colonIdx == -1)
            continue;

        QString partsStr = line.mid(colonIdx + 1);
        const QStringList partTokens = partsStr.split(QLatin1Char(','));
        for (const QString &token : partTokens)
        {
            QString trimmedToken = token.trimmed();
            int atIdx = trimmedToken.indexOf(QLatin1Char('@'));
            int openParen = trimmedToken.indexOf(QLatin1Char('('));
            int closeParen = trimmedToken.indexOf(QLatin1Char(')'));
            if (atIdx == -1 || openParen == -1 || closeParen == -1 || openParen <= atIdx)
                continue;

            QString sizeStr = trimmedToken.left(atIdx).trimmed();
            QString offsetStr = trimmedToken.mid(atIdx + 1, openParen - atIdx - 1).trimmed();
            QString nameStr = trimmedToken.mid(openParen + 1, closeParen - openParen - 1).trimmed();

            bool ok = false;
            quint32 offset = offsetStr.startsWith(QStringLiteral("0x"), Qt::CaseInsensitive)
                    ? offsetStr.toUInt(&ok, 16)
                    : offsetStr.toUInt(&ok, 10);
            if (!ok)
                continue;

            quint32 size = 0;
            if (sizeStr != QStringLiteral("-"))
            {
                size = sizeStr.startsWith(QStringLiteral("0x"), Qt::CaseInsensitive)
                        ? sizeStr.toUInt(&ok, 16)
                        : sizeStr.toUInt(&ok, 10);
            }

            RockchipPartition part;
            part.name = nameStr;
            part.offset = offset;
            part.size = size;
            partitions.append(part);
        }
    }
    return partitions;
}

QByteArray makeParameterBuffer(const QByteArray &paramContent)
{
    QByteArray buf;
    buf.reserve(paramContent.size() + 12);

    const quint32 magic = 0x4D524150; // "PARM"
    const quint32 len = paramContent.size();
    buf.append(reinterpret_cast<const char *>(&magic), 4);
    buf.append(reinterpret_cast<const char *>(&len), 4);
    buf.append(paramContent);

    const quint32 crc = calculateCrc32(reinterpret_cast<const quint8 *>(paramContent.constData()), len);
    buf.append(reinterpret_cast<const char *>(&crc), 4);
    return buf;
}

bool downloadRockchipBootloader(const QByteArray &bootloaderData, QString *errorMsg)
{
    if (bootloaderData.size() < (int)sizeof(RkBootHeader))
    {
        if (errorMsg) *errorMsg = QStringLiteral("Invalid bootloader binary size.");
        return false;
    }

    const auto *header = reinterpret_cast<const RkBootHeader *>(bootloaderData.constData());
    if (header->tag != 0x2052444C)
    {
        if (errorMsg) *errorMsg = QStringLiteral("Invalid bootloader header tag (expected 'LDR ').");
        return false;
    }

#ifdef Q_OS_WIN
    QString devPath = findRockchipDevicePath();
    if (devPath.isEmpty())
    {
        if (errorMsg) *errorMsg = QStringLiteral("Rockchip device not found on USB.");
        return false;
    }

    HANDLE hDev = CreateFileW(reinterpret_cast<LPCWSTR>(devPath.utf16()),
                              GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE,
                              nullptr, OPEN_EXISTING, 0, nullptr);
    if (hDev == INVALID_HANDLE_VALUE)
    {
        if (errorMsg) *errorMsg = QStringLiteral("Failed to open Rockchip USB device (error %1).").arg(GetLastError());
        return false;
    }

    auto sendEntries = [&](quint8 count, quint32 offset, quint8 entrySize, quint32 ioctlCode) -> bool {
        for (quint8 i = 0; i < count; ++i)
        {
            quint32 entryOffset = offset + i * entrySize;
            if (entryOffset + sizeof(RkBootEntry) > (quint32)bootloaderData.size())
                return false;

            const auto *entry = reinterpret_cast<const RkBootEntry *>(bootloaderData.constData() + entryOffset);
            if (entry->dataOffset + entry->dataSize > (quint32)bootloaderData.size())
                return false;

            QByteArray chunk = bootloaderData.mid(entry->dataOffset, entry->dataSize);
            quint32 origSize = chunk.size();
            bool sendPendPacket = false;
            switch (origSize % 4096)
            {
            case 4095:
                chunk.append('\0');
                break;
            case 4094:
                sendPendPacket = true;
                break;
            default:
                break;
            }

            quint16 crc = calculateCrcCcitt(reinterpret_cast<const quint8 *>(chunk.constData()), chunk.size());
            chunk.append(static_cast<char>((crc >> 8) & 0xFF));
            chunk.append(static_cast<char>(crc & 0xFF));

            quint32 totalSent = 0;
            quint32 dataSize = chunk.size();
            while (totalSent < dataSize)
            {
                quint32 sendBytes = qMin<quint32>(dataSize - totalSent, 4096);
                DWORD returned = 0;
                if (!DeviceIoControl(hDev, ioctlCode,
                                     chunk.data() + totalSent, sendBytes,
                                     nullptr, 0, &returned, nullptr))
                {
                    return false;
                }
                totalSent += sendBytes;
            }

            if (sendPendPacket)
            {
                char zero = 0;
                DWORD returned = 0;
                DeviceIoControl(hDev, ioctlCode, &zero, 1, nullptr, 0, &returned, nullptr);
            }

            DWORD delay = qMax<DWORD>(entry->dataDelay, 20);
            Sleep(delay);
        }
        return true;
    };

    if (!sendEntries(header->count471, header->offset471, header->size471, 0x8000a000))
    {
        CloseHandle(hDev);
        if (errorMsg) *errorMsg = QStringLiteral("Failed downloading 471 DDR entry to device.");
        return false;
    }

    if (!sendEntries(header->count472, header->offset472, header->size472, 0x8000a004))
    {
        CloseHandle(hDev);
        if (errorMsg) *errorMsg = QStringLiteral("Failed downloading 472 SPL entry to device.");
        return false;
    }

    CloseHandle(hDev);
    return true;
#else
    Q_UNUSED(bootloaderData);
    if (errorMsg) *errorMsg = QStringLiteral("Bootloader download is only supported on Windows.");
    return false;
#endif
}

bool waitForRockchipLoaderMode(int timeoutMs, RockchipDeviceDescriptor *outDescriptor)
{
    QElapsedTimer timer;
    timer.start();

    while (timer.elapsed() < timeoutMs)
    {
        QThread::msleep(200);
        auto devices = listRockchipUsbDevices();
        for (const auto &dev : devices)
        {
            if (dev.isLoader && dev.vendorId == 0x2207)
            {
                if (outDescriptor)
                    *outDescriptor = dev;
                return true;
            }
        }
    }
    return false;
}

RockchipTransport::RockchipTransport()
{
}

RockchipTransport::~RockchipTransport()
{
    close();
}

bool RockchipTransport::isOpen() const
{
#ifdef Q_OS_WIN
    return _hWritePipe != INVALID_HANDLE_VALUE && _hReadPipe != INVALID_HANDLE_VALUE;
#else
    return false;
#endif
}

void RockchipTransport::close()
{
#ifdef Q_OS_WIN
    if (_hReadPipe != INVALID_HANDLE_VALUE)
    {
        CloseHandle(_hReadPipe);
        _hReadPipe = INVALID_HANDLE_VALUE;
    }
    if (_hWritePipe != INVALID_HANDLE_VALUE)
    {
        CloseHandle(_hWritePipe);
        _hWritePipe = INVALID_HANDLE_VALUE;
    }
    if (_hDevice != INVALID_HANDLE_VALUE)
    {
        CloseHandle(_hDevice);
        _hDevice = INVALID_HANDLE_VALUE;
    }
#endif
}

bool RockchipTransport::open(QString *errorMsg)
{
    close();
#ifdef Q_OS_WIN
    QString devPath = findRockchipDevicePath();
    if (devPath.isEmpty())
    {
        if (errorMsg) *errorMsg = QStringLiteral("Rockchip Loader device not found.");
        return false;
    }

    _hDevice = CreateFileW(reinterpret_cast<LPCWSTR>(devPath.utf16()),
                           GENERIC_READ | GENERIC_WRITE,
                           FILE_SHARE_READ | FILE_SHARE_WRITE,
                           nullptr, OPEN_EXISTING, 0, nullptr);

    QString outPipePath = devPath + QStringLiteral("\\PIPE01");
    _hWritePipe = CreateFileW(reinterpret_cast<LPCWSTR>(outPipePath.utf16()),
                              GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE,
                              nullptr, OPEN_EXISTING, 0, nullptr);

    QString inPipePath = devPath + QStringLiteral("\\PIPE00");
    _hReadPipe = CreateFileW(reinterpret_cast<LPCWSTR>(inPipePath.utf16()),
                             GENERIC_READ,
                             FILE_SHARE_READ | FILE_SHARE_WRITE,
                             nullptr, OPEN_EXISTING, 0, nullptr);

    if (_hWritePipe == INVALID_HANDLE_VALUE || _hReadPipe == INVALID_HANDLE_VALUE)
    {
        if (errorMsg) *errorMsg = QStringLiteral("Failed opening Rockchip USB pipes.");
        close();
        return false;
    }

    return true;
#else
    if (errorMsg) *errorMsg = QStringLiteral("Rockchip transport is only supported on Windows.");
    return false;
#endif
}

bool RockchipTransport::writeLBA(quint32 lba, quint16 sectorCount, const quint8 *data, QString *errorMsg)
{
#ifdef Q_OS_WIN
    if (!isOpen())
    {
        if (errorMsg) *errorMsg = QStringLiteral("Rockchip transport is not open.");
        return false;
    }

    RockchipCBW cbw;
    cbw.signature = 0x43425355;
    cbw.tag = ++_tag;
    cbw.transferLength = static_cast<quint32>(sectorCount) * 512;
    cbw.flags = 0x00;
    cbw.lun = 0;
    cbw.length = 0x0A;
    cbw.opcode = 0x15; // WRITE_LBA
    cbw.subcode = 0;
    cbw.address = qToBigEndian(lba);
    cbw.sectorCount = qToBigEndian(sectorCount);

    DWORD written = 0;
    if (!WriteFile(_hWritePipe, &cbw, sizeof(cbw), &written, nullptr) || written != sizeof(cbw))
    {
        if (errorMsg) *errorMsg = QStringLiteral("Failed writing CBW to device (error %1).").arg(GetLastError());
        return false;
    }

    DWORD toWrite = static_cast<DWORD>(sectorCount) * 512;
    DWORD totalWritten = 0;
    while (totalWritten < toWrite)
    {
        DWORD bytesWritten = 0;
        DWORD writeChunk = toWrite - totalWritten;
        if (!WriteFile(_hWritePipe, data + totalWritten, writeChunk, &bytesWritten, nullptr) || bytesWritten == 0)
        {
            if (errorMsg) *errorMsg = QStringLiteral("Failed writing data buffer (error %1).").arg(GetLastError());
            return false;
        }
        totalWritten += bytesWritten;
    }

    RockchipCSW csw = {};
    DWORD readBytes = 0;
    if (!ReadFile(_hReadPipe, &csw, sizeof(csw), &readBytes, nullptr) || readBytes != sizeof(csw))
    {
        if (errorMsg) *errorMsg = QStringLiteral("Failed reading CSW status (error %1).").arg(GetLastError());
        return false;
    }

    if (csw.signature != 0x53425355 || csw.tag != _tag || csw.status != 0)
    {
        if (errorMsg) *errorMsg = QStringLiteral("Device write error (CSW status %1).").arg(csw.status);
        return false;
    }

    return true;
#else
    Q_UNUSED(lba);
    Q_UNUSED(sectorCount);
    Q_UNUSED(data);
    if (errorMsg) *errorMsg = QStringLiteral("Unsupported.");
    return false;
#endif
}

bool RockchipTransport::resetDevice(QString *errorMsg)
{
#ifdef Q_OS_WIN
    if (_hDevice != INVALID_HANDLE_VALUE)
    {
        DWORD returned = 0;
        DeviceIoControl(_hDevice, 0x220000, nullptr, 0, nullptr, 0, &returned, nullptr);
    }
    close();
    return true;
#else
    if (errorMsg) *errorMsg = QStringLiteral("Unsupported.");
    return false;
#endif
}
