#ifndef ARCHIVEPATHVALIDATOR_H
#define ARCHIVEPATHVALIDATOR_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>

class ArchivePathValidator final
{
public:
    static bool normalizeRelativePath(const QString &path, QString &normalized,
                                      QString *error = nullptr);
};

#endif // ARCHIVEPATHVALIDATOR_H
