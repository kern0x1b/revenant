#ifndef CHARON_CK_WEBAUTH_H
#define CHARON_CK_WEBAUTH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const uint8_t *CharonCKGroupOrder(void);
const uint8_t *CharonCKGroupOrderHalf(void);

int CharonCKDERSignatureValues(const uint8_t *der, size_t derLength, uint8_t r[32], uint8_t s[32]);

const uint8_t *CharonCKDERSignatureS(const uint8_t *der, size_t derLength);

int CharonCKSignES256(const uint8_t *privateKey, const uint8_t *message, size_t length, uint8_t *der, size_t capacity);
int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                              const uint8_t *der, size_t derLength);
int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                              uint8_t *secret);

int CharonCKVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *message, size_t length,
                        const uint8_t *der, size_t derLength);

int CharonCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);

void CharonCKSHA256(const uint8_t *message, size_t length, uint8_t *digest);

#ifdef __cplusplus
}
#endif

#endif
