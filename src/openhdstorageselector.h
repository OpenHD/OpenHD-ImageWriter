#ifndef OPENHDSTORAGESELECTOR_H
#define OPENHDSTORAGESELECTOR_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>
#include <QStringList>

class OpenHDStorageSelector final
{
public:
    static int scoreMountPoint(const QString &mountPoint);
    static QString selectBestMountPoint(const QStringList &mountPoints);

private:
    OpenHDStorageSelector() = delete;
};

#endif // OPENHDSTORAGESELECTOR_H
