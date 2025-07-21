/*
 * Use OpenSSL for hashing as their code is more optimized than Qt's
 *
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include "acceleratedcryptographichash.h"
#include <stdexcept>

AcceleratedCryptographicHash::AcceleratedCryptographicHash(QCryptographicHash::Algorithm method)
{
    if (method != QCryptographicHash::Sha256)
        throw std::runtime_error("Only sha256 implemented");

#ifdef HAVE_WINCRYPT
    if (!CryptAcquireContext(&_hCryptProv, NULL, NULL, PROV_RSA_AES, CRYPT_VERIFYCONTEXT))
        throw std::runtime_error("CryptAcquireContext failed");
    if (!CryptCreateHash(_hCryptProv, CALG_SHA_256, 0, 0, &_hHash))
        throw std::runtime_error("CryptCreateHash failed");
#else
    SHA256_Init(&_sha256);
#endif
}

AcceleratedCryptographicHash::~AcceleratedCryptographicHash()
{
#ifdef HAVE_WINCRYPT
    if (_hHash)
        CryptDestroyHash(_hHash);
    if (_hCryptProv)
        CryptReleaseContext(_hCryptProv, 0);
#endif
}

void AcceleratedCryptographicHash::addData(const char *data, int length)
{
#ifdef HAVE_WINCRYPT
    if (!CryptHashData(_hHash, (BYTE*)data, length, 0))
        throw std::runtime_error("CryptHashData failed");
#else
    SHA256_Update(&_sha256, data, length);
#endif
}

void AcceleratedCryptographicHash::addData(const QByteArray &data)
{
    addData(data.constData(), data.size());
}

QByteArray AcceleratedCryptographicHash::result()
{
#ifdef HAVE_WINCRYPT
    BYTE binhash[32]; // SHA256 is 32 bytes
    DWORD dwHashLen = sizeof(binhash);
    if (!CryptGetHashParam(_hHash, HP_HASHVAL, binhash, &dwHashLen, 0))
        throw std::runtime_error("CryptGetHashParam failed");
    return QByteArray((char *) binhash, dwHashLen);
#else
    unsigned char binhash[SHA256_DIGEST_LENGTH];
    SHA256_Final(binhash, &_sha256);
    return QByteArray((char *) binhash, sizeof binhash);
#endif
}
