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

// NAND UBI images must overwrite their entire partition: old journal blocks
// outside a short image can otherwise resurrect settings from a previous flash.
bool padRockchipNandUbiImage(const QString &imagePath, quint64 partitionBytes,
                             QString *errorMessage = nullptr);

#endif // ROCKCHIPFIRMWARELAYOUT_H
