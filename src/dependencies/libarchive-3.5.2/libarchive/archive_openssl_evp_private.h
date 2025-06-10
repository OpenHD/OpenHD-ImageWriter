#ifndef ARCHIVE_OPENSSL_EVP_PRIVATE_H_INCLUDED
#define ARCHIVE_OPENSSL_EVP_PRIVATE_H_INCLUDED

#ifndef __LIBARCHIVE_BUILD
#error This header is only to be used internally to libarchive.
#endif

// Stubbed out for builds without OpenSSL
typedef void EVP_MD_CTX;

static inline EVP_MD_CTX *EVP_MD_CTX_new(void) { return nullptr; }
static inline void EVP_MD_CTX_free(EVP_MD_CTX *ctx) { (void)ctx; }

#endif
