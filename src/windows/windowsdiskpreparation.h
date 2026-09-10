#ifndef WINDOWSDISKPREPARATION_H
#define WINDOWSDISKPREPARATION_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 OpenHD
 */

#include <QString>

#include <string>
#include <vector>

namespace WindowsDiskPreparation {

class LockedVolumes final
{
public:
    LockedVolumes() = default;
    ~LockedVolumes();
    LockedVolumes(const LockedVolumes &) = delete;
    LockedVolumes &operator=(const LockedVolumes &) = delete;

    bool lockAndDismount(const std::vector<std::string> &mountpoints, QString *error);
    void release();
    bool empty() const { return _handles.empty(); }

private:
    std::vector<void *> _handles;
};

bool clearPartitionTable(const QString &physicalDrive, QString *error);
bool rescanDisk(const QString &physicalDrive, QString *error = nullptr);
QString ensureDriveLetter(const QString &physicalDrive, int timeoutMs,
                          QString *error = nullptr);

} // namespace WindowsDiskPreparation

#endif // WINDOWSDISKPREPARATION_H
