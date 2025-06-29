#ifndef SHA256CRYPT_H
#define SHA256CRYPT_H

#ifdef __cplusplus
extern "C" {
#endif

// Die originale crypt()-artige Funktion
char *sha256_crypt(const char *key, const char *salt);

// Neue Utility-Funktion für direkten Hash
void sha256_buffer(const void *buffer, size_t len, void *output32bytes);

#ifdef __cplusplus
}
#endif

#endif // SHA256CRYPT_H
