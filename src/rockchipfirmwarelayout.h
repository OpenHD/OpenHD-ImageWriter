#ifndef ROCKCHIPFIRMWARELAYOUT_H
#define ROCKCHIPFIRMWARELAYOUT_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>

// Finds the directory containing parameter.txt and the Rockchip partition
// images. Supports both flat packages and ImageBuilder's output/firmware tree.
bool findRockchipFirmwareDirectory(const QString &extractionRoot,
                                   QString &firmwareDirectory,
                                   QString *errorMessage = nullptr);

#endif // ROCKCHIPFIRMWARELAYOUT_H
