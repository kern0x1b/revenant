#ifndef REVENANT_CK_WEBAUTH_H
#define REVENANT_CK_WEBAUTH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const uint8_t *RevenantCKGroupOrder(void);
const uint8_t *RevenantCKGroupOrderHalf(void);

int RevenantCKDERSignatureValues(const uint8_t *der, size_t derLength, uint8_t r[32], uint8_t s[32]);

const uint8_t *RevenantCKDERSignatureS(const uint8_t *der, size_t derLength);

int RevenantCKSignES256(const uint8_t *privateKey, const uint8_t *message, size_t length, uint8_t *der, size_t capacity);
int RevenantCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
int RevenantCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                              const uint8_t *der, size_t derLength);
int RevenantCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                              uint8_t *secret);

int RevenantCKVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *message, size_t length,
                        const uint8_t *der, size_t derLength);

int RevenantCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);

void RevenantCKSHA256(const uint8_t *message, size_t length, uint8_t *digest);

#ifdef __cplusplus
}
#endif

#endif
