#pragma once

#include <QString>

inline bool isOpenHDUpdateFile(const QString &path)
{
    return path.endsWith(QStringLiteral(".ohd"), Qt::CaseInsensitive) ||
           path.endsWith(QStringLiteral(".ohd_base"), Qt::CaseInsensitive);
}
