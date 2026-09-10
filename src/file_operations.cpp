#include "file_operations.h"

QString fileErrorMessage(FileError error)
{
    switch (error)
    {
    case FileError::Success: return QString();
    case FileError::NotOpen: return QStringLiteral("File or device is not open");
    case FileError::NotFound: return QStringLiteral("File or device was not found");
    case FileError::AccessDenied: return QStringLiteral("Access to the device was denied");
    case FileError::Busy: return QStringLiteral("Device is busy or already in use");
    case FileError::InvalidArgument: return QStringLiteral("Invalid file operation argument");
    case FileError::Cancelled: return QStringLiteral("File operation was cancelled");
    case FileError::IoError: return QStringLiteral("Device input/output error");
    }
    return QStringLiteral("Unknown file operation error");
}
