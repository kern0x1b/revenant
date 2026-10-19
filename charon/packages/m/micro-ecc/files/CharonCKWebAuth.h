// The ES256 signature a CloudKit Web Services authentication key makes, over micro-ecc.
//
// The signing and verification are micro-ecc's, unmodified (BSD-2, a charon package of its own), and
// this is only what JOSE needs around it: SHA-256 of the message, the DER encoding a JOSE ES256
// verifier reads, and the low-s half Apple's own Security produces. See facts/CloudKit/WebAuthKey.md.

#ifndef CHARON_CK_WEBAUTH_H
#define CHARON_CK_WEBAUTH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// The order of P-256's generator and half of it, for the test that asserts a low s. The test reads
// them from here rather than transcribing the value a second time.
const uint8_t *CharonCKGroupOrder(void);
const uint8_t *CharonCKGroupOrderHalf(void);

// The r and s of a DER signature as the two 32-byte values, sign pad off, or 0 when the encoding is
// not one this file wrote. **One reader, for the verifier and for the test**: the first version had
// two and they drifted - the verifier stripped the pad and the accessor did not, so every padded s
// began 0x00, compared below any half of the group order, and the low-s count reported high=0 while
// the port emitted high-s in half of its signatures.
int CharonCKDERSignatureValues(const uint8_t *der, size_t derLength, uint8_t r[32], uint8_t s[32]);

// The s alone, through that reader. A test that classifies with it is still testing this file's
// arithmetic against this file's reader, so the low-s assertion in tests/backports/host/cloudkit also
// re-reads the DER in python and applies the order itself.
const uint8_t *CharonCKDERSignatureS(const uint8_t *der, size_t derLength);

// The SHA-256 the signature is over, and the DER SEQUENCE { INTEGER r, INTEGER s } of it, at most
// 72 bytes and 64 for a P-256 key. Answers the length written, or 0.
int CharonCKSignES256(const uint8_t *privateKey, const uint8_t *message, size_t length, uint8_t *der, size_t capacity);
int CharonCKDigestSignES256(const uint8_t *privateKey, const uint8_t *digest, uint8_t *der, size_t capacity);
int CharonCKDigestVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *digest,
                              const uint8_t *der, size_t derLength);
int CharonCKSharedSecretES256(const uint8_t *privateKey, const uint8_t *peerPublic, size_t publicLength,
                              uint8_t *secret);

// Whether that signature is a real signature of the message under the uncompressed public point
// (0x04 followed by the two 32-byte coordinates).
int CharonCKVerifyES256(const uint8_t *publicKey, size_t publicLength, const uint8_t *message, size_t length,
                        const uint8_t *der, size_t derLength);

// The uncompressed public point of a 32-byte big-endian private key, 65 bytes, or 0.
int CharonCKPublicKeyES256(const uint8_t *privateKey, uint8_t *out);

// The SHA-256 of a message with CommonCrypto, so the caller does not have to reach for it separately.
void CharonCKSHA256(const uint8_t *message, size_t length, uint8_t *digest);

#ifdef __cplusplus
}
#endif

#endif
