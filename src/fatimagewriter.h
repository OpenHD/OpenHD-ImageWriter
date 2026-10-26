#ifndef FATIMAGEWRITER_H
#define FATIMAGEWRITER_H

#include <QString>
#include <functional>

namespace FatImageWriter {
// Modifies an extracted, disposable partition image only; never opens a host disk.
// All staged files are read back and compared before returning success.
bool install(const QString &imagePath, const QString &stagingDirectory,
             QString *error, const std::function<bool()> &cancelled = {});
}

#endif
