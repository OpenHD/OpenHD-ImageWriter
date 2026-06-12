#include "certificatevalidator.h"

#include <QByteArray>
#include <QDateTime>
#include <QFile>
#include <QIODevice>
#include <QMap>
#include <QObject>
#include <QStringList>
#include <QTextStream>
#include <QtGlobal>

#ifndef Q_OS_DARWIN
#include <openssl/evp.h>
#endif

namespace {

constexpr quint64 kMinTrustedUnixSeconds = 1704067200ULL; // 2024-01-01
constexpr quint64 kClockSkewGraceSeconds = 60ULL * 60ULL;

const QByteArray kIssuerPublicKey = QByteArray::fromHex(
    "F0187ED0714FB21AE0E96CEFAD616A798BE57682965FC8167D44EA0A46688D6D");

const QStringList kCanonicalFields = {
    "version",    "license_id", "sold_to",       "use_case",
    "device_id",  "plan",       "features",      "issued_at",
    "not_before", "not_after",  "key_id",        "video_key_b64",
    "wb_keypair_b64"};

QString trim(const QString &value)
{
    return value.trimmed();
}

bool parseU64(const QString &value, quint64 &out)
{
    bool ok = false;
    const quint64 parsed = value.toULongLong(&ok, 10);
    if (!ok)
        return false;
    out = parsed;
    return true;
}

QByteArray canonicalPayload(const QMap<QString, QString> &values)
{
    QByteArray payload;
    for (const QString &key : kCanonicalFields) {
        payload += key.toUtf8();
        payload += '=';
        payload += values.value(key).toUtf8();
        payload += '\n';
    }
    return payload;
}

bool hasFeature(const QString &features, const QString &expected)
{
    for (const QString &feature : features.split(',', QString::SkipEmptyParts)) {
        if (trim(feature) == expected)
            return true;
    }
    return false;
}

bool hasRequiredClaims(const QMap<QString, QString> &values)
{
    if (trim(values.value("sold_to")).isEmpty())
        return false;

    const QString useCase = trim(values.value("use_case"));
    return useCase == "military" || useCase == "enterprise" ||
           useCase == "research" || useCase == "testing";
}

bool verifySignature(const QMap<QString, QString> &values)
{
#ifdef Q_OS_DARWIN
    Q_UNUSED(values)
    return false;
#else
    const QByteArray signature = QByteArray::fromBase64(values.value("signature_b64").toUtf8());
    if (signature.size() != 64)
        return false;

    EVP_PKEY *publicKey = EVP_PKEY_new_raw_public_key(
        EVP_PKEY_ED25519, nullptr,
        reinterpret_cast<const unsigned char *>(kIssuerPublicKey.constData()),
        static_cast<size_t>(kIssuerPublicKey.size()));
    if (!publicKey)
        return false;

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) {
        EVP_PKEY_free(publicKey);
        return false;
    }

    const QByteArray payload = canonicalPayload(values);
    const int initOk = EVP_DigestVerifyInit(ctx, nullptr, nullptr, nullptr, publicKey);
    const int verifyOk = initOk == 1
                             ? EVP_DigestVerify(
                                   ctx,
                                   reinterpret_cast<const unsigned char *>(signature.constData()),
                                   static_cast<size_t>(signature.size()),
                                   reinterpret_cast<const unsigned char *>(payload.constData()),
                                   static_cast<size_t>(payload.size()))
                             : 0;

    EVP_MD_CTX_free(ctx);
    EVP_PKEY_free(publicKey);
    return verifyOk == 1;
#endif
}

QString readCertificate(const QString &filePath, QMap<QString, QString> &values)
{
    QFile file(filePath);
    if (!file.exists())
        return QObject::tr("Certificate file does not exist.");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QObject::tr("Certificate file could not be opened.");

    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QString line = trim(stream.readLine());
        if (line.isEmpty() || line.startsWith('#'))
            continue;
        const int pos = line.indexOf('=');
        if (pos <= 0)
            return QObject::tr("Certificate contains an invalid line.");
        values.insert(trim(line.left(pos)), trim(line.mid(pos + 1)));
    }

    return QString();
}

} // namespace

QString CertificateValidator::validatePremiumCertificateFile(const QString &filePath)
{
    QMap<QString, QString> values;
    QString error = readCertificate(filePath, values);
    if (!error.isEmpty())
        return error;

    if (values.value("version") != "1")
        return QObject::tr("Unsupported certificate version.");
    if (!hasRequiredClaims(values))
        return QObject::tr("Certificate is missing customer or use-case claims.");
    if (!hasFeature(values.value("features"), "video_encryption"))
        return QObject::tr("Certificate does not enable video encryption.");
    if (!verifySignature(values))
        return QObject::tr("Certificate signature is invalid.");

    quint64 notBefore = 0;
    quint64 notAfter = 0;
    quint64 keyId = 0;
    if (!parseU64(values.value("not_before"), notBefore) ||
        !parseU64(values.value("not_after"), notAfter) ||
        !parseU64(values.value("key_id"), keyId)) {
        return QObject::tr("Certificate contains invalid timestamps or key id.");
    }

    const QByteArray videoKey = QByteArray::fromBase64(values.value("video_key_b64").toUtf8());
    if (videoKey.size() != 32)
        return QObject::tr("Certificate contains an invalid video key.");

    const quint64 now = static_cast<quint64>(QDateTime::currentSecsSinceEpoch());
    if (now < kMinTrustedUnixSeconds)
        return QObject::tr("System time is not valid enough to verify the certificate.");
    if (now + kClockSkewGraceSeconds < notBefore)
        return QObject::tr("Certificate is not valid yet.");
    if (now > notAfter + kClockSkewGraceSeconds)
        return QObject::tr("Certificate has expired.");

    return QString();
}
