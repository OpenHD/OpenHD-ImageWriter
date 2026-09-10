#ifndef DRIVELISTITEM_H
#define DRIVELISTITEM_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include <QObject>
#include <QStringList>

class DriveListItem : public QObject
{
    Q_OBJECT
public:
    explicit DriveListItem(QString device, QString description, quint64 size, bool isUsb = false, bool isScsi = false, bool readOnly = false, QStringList mountpoints = QStringList(), bool isMaskrom = false, quint16 usbVendorId = 0, quint16 usbProductId = 0, bool isLoader = false, QString socName = QString(), QString boardName = QString(), QObject *parent = nullptr);

    Q_PROPERTY(QString device MEMBER _device CONSTANT)
    Q_PROPERTY(QString description MEMBER _description CONSTANT)
    Q_PROPERTY(quint64 size MEMBER _size CONSTANT)
    Q_PROPERTY(QStringList mountpoints MEMBER _mountpoints CONSTANT)
    Q_PROPERTY(bool isUsb MEMBER _isUsb CONSTANT)
    Q_PROPERTY(bool isScsi MEMBER _isScsi CONSTANT)
    Q_PROPERTY(bool isReadOnly MEMBER _isReadOnly CONSTANT)
    Q_PROPERTY(bool isMaskrom MEMBER _isMaskrom CONSTANT)
    Q_PROPERTY(bool isLoader MEMBER _isLoader CONSTANT)
    Q_PROPERTY(quint16 usbVendorId MEMBER _usbVendorId CONSTANT)
    Q_PROPERTY(quint16 usbProductId MEMBER _usbProductId CONSTANT)
    Q_PROPERTY(QString socName MEMBER _socName CONSTANT)
    Q_PROPERTY(QString boardName MEMBER _boardName CONSTANT)
    Q_INVOKABLE int sizeInGb();

signals:

public slots:

protected:
    QString _device;
    QString _description;
    QStringList _mountpoints;
    quint64 _size;
    bool _isUsb;
    bool _isScsi;
    bool _isReadOnly;
    bool _isMaskrom;
    bool _isLoader;
    quint16 _usbVendorId;
    quint16 _usbProductId;
    QString _socName;
    QString _boardName;
};

#endif // DRIVELISTITEM_H
