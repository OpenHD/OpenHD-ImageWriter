#ifndef NXPFIRMWARELAYOUT_H
#define NXPFIRMWARELAYOUT_H

#include <QDirIterator>
#include <QFileInfo>
#include <QStringList>

namespace NxpFirmwareLayout {
// Artifact downloads wrap the vendor firmware ZIP in another ZIP. Accept one
// unambiguous package, and let the existing validated extractor unpack it.
inline bool locate(const QString &root, QString &script, QString &archive, QString &error)
{
    script.clear(); archive.clear(); error.clear();
    QStringList scripts, archives;
    QDirIterator entries(root, QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
    while (entries.hasNext()) {
        const QString path = entries.next();
        const QFileInfo info(path);
        if (info.fileName() == QStringLiteral("uuu.auto")) scripts << path;
        if (info.suffix().compare(QStringLiteral("zip"), Qt::CaseInsensitive) == 0) archives << path;
    }
    if (scripts.size() == 1) { script = scripts.first(); return true; }
    if (scripts.size() > 1) { error = QStringLiteral("The NXP firmware package contains more than one uuu.auto script."); return false; }
    if (archives.size() == 1) { archive = archives.first(); return true; }
    error = archives.isEmpty() ? QStringLiteral("The NXP firmware package does not contain uuu.auto.")
                              : QStringLiteral("The NXP artifact contains multiple firmware ZIPs.");
    return false;
}
}
#endif
