#ifndef ROCKCHIPFIRMWARELAYOUT_H
#define ROCKCHIPFIRMWARELAYOUT_H

#include "rockchipdevice.h"

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>

// Recursively finds a directory containing Rockchip partition metadata and
// images. Supports parameter.txt and Luckfox .env.txt package layouts.
bool findRockchipFirmwareDirectory(const QString &extractionRoot,
                                   QString &firmwareDirectory,
                                   QString *errorMessage = nullptr);

// Parses Luckfox/Buildroot blkdevparts metadata. Sizes and offsets in this
// format are byte values (for example 512K@32K), and are returned as LBAs.
QList<RockchipPartition> parseBlockDeviceParts(const QByteArray &environmentContent);

#endif // ROCKCHIPFIRMWARELAYOUT_H
