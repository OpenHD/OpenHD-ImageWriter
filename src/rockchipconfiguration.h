// SPDX-License-Identifier: Apache-2.0
#ifndef ROCKCHIPCONFIGURATION_H
#define ROCKCHIPCONFIGURATION_H
#include <QString>
#include <functional>
namespace RockchipConfiguration {
enum class UbiProfile { X21Ohd, PicoRootfs };
bool installDisk(const QString &image, const QString &staging, QString *error,
                 const std::function<bool()> &cancelled = {});
bool installUbi(const QString &image, const QString &staging, QString *error,
                const std::function<bool()> &cancelled = {}, UbiProfile profile = UbiProfile::X21Ohd);
}
#endif
