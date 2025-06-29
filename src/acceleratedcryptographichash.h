#ifndef ACCELERATEDCRYPTOGRAPHICHASH_H
#define ACCELERATEDCRYPTOGRAPHICHASH_H

/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2020 Raspberry Pi Ltd
 */

#include <QCryptographicHash>
#include <QByteArray>

// --- Platform-specific includes and definitions ---

#if defined(Q_OS_DARWIN)

// --- macOS: use CommonCrypto ---
#include <CommonCrypto/CommonDigest.h>
#define SHA256_CTX            CC_SHA256_CTX
#define SHA256_DIGEST_LENGTH  CC_SHA256_DIGEST_LENGTH
#define SHA256_Init           CC_SHA256_Init
#define SHA256_Update         CC_SHA256_Update
#define SHA256_Final          CC_SHA256_Final

#elif defined(HAVE_GNUTLS)

// --- GnuTLS: use GnuTLS crypto API ---
#include <gnutls/crypto.h>

#else

// --- Fallback: simple SHA256 using sha256crypt.h ---
#include "sha256crypt.h"
#include <cstdio>

struct SHA256_CTX {
    QByteArray buffer;
};

static inline void SHA256_Init(SHA256_CTX* ctx) {
    ctx->buffer.clear();
}

static inline void SHA256_Update(SHA256_CTX* ctx, const void* data, size_t len) {
    ctx->buffer.append(reinterpret_cast<const char*>(data), static_cast<int>(len));
}

static inline void SHA256_Final(unsigned char* output, SHA256_CTX* ctx) {
    char hex[65] = {0};
    sha256_buffer(ctx->buffer.constData(), ctx->buffer.size(), hex);
    for (int i = 0; i < 32; ++i)
        std::sscanf(&hex[i * 2], "%2hhx", &output[i]);
}

#define SHA256_DIGEST_LENGTH 32

#endif // Platform fallback

// --- Main class interface ---

class AcceleratedCryptographicHash
{
public:
    explicit AcceleratedCryptographicHash(QCryptographicHash::Algorithm method);
    virtual ~AcceleratedCryptographicHash();

    void addData(const char *data, int length);
    void addData(const QByteArray &data);
    QByteArray result();

protected:
#if defined(HAVE_GNUTLS)
    gnutls_hash_hd_t _sha256;
#else
    SHA256_CTX _sha256;
#endif
};

#endif // ACCELERATEDCRYPTOGRAPHICHASH_H
