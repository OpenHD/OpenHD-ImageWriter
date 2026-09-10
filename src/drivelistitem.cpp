/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "drivelistitem.h"

DriveListItem::DriveListItem(QString device, QString description, quint64 size, bool isUsb, bool isScsi, bool readOnly, QStringList mountpoints, bool isMaskrom, quint16 usbVendorId, quint16 usbProductId, bool isLoader, QString socName, QString boardName, QObject *parent)
    : QObject(parent), _device(device), _description(description), _mountpoints(mountpoints), _size(size), _isUsb(isUsb), _isScsi(isScsi), _isReadOnly(readOnly), _isMaskrom(isMaskrom), _isLoader(isLoader), _usbVendorId(usbVendorId), _usbProductId(usbProductId), _socName(socName), _boardName(boardName)
{

}

int DriveListItem::sizeInGb()
{
    return _size / 1000000000;
}
