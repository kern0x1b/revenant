// The shim between this module's Swift and the P-256 implementation the port links.
//
// Nothing is computed here: the DER encoding of the raw (r, s) micro-ecc returns, the low-s half and
// the SHA-256 are all the same work the CloudKit family already does, and doing it twice is how the
// two drift apart. So the C below calls exactly what CharonCKWebAuth.c calls, from the same
// charon@micro-ecc.
//
// What is read here is the key material, because the module is handed what Apple hands an
// application: a .p8, which is a PEM. Getting from that to the 32 bytes micro-ecc signs with is a
// fixed structure - PKCS#8 PrivateKeyInfo, whose privateKey field holds the SEC1 ECPrivateKey, whose
// own second field is the fixed-length private scalar - and the reader below walks exactly that and
// refuses anything else. tests/backports/host/musickit/run.sh is what showed the module needed it at
// all: it passed the PEM's own bytes where the scalar belongs, and OpenSSL answered "Error Verifying
// Data" over a signature that was a signature of nothing.

#include "MusicKitC.h"
#include "CharonCKWebAuth.h"

#include <string.h>

#define CHARON_P256_SCALAR_LENGTH 32
#define CHARON_ES256_RAW_LENGTH (2 * CHARON_P256_SCALAR_LENGTH)

/* One DER element: its tag and the bytes and length of its content, with the cursor left after it.
   The length is the definite form only, which is the only form a PKCS#8 from Apple's own tooling
   uses, and a length this reader cannot account for is a refusal rather than a guess. */
static int CharonDERNext(const unsigned char **cursor, const unsigned char *end,
                         unsigned char *tag, const unsigned char **value, size_t *length)
{
    if (cursor == NULL || *cursor == NULL || end == NULL || *cursor + 2 > end) {
        return 0;
    }
    const unsigned char *at = *cursor;
    unsigned char found = at[0];
    size_t size = at[1];
    at += 2;
    if (size & 0x80) {
        size_t count = size & 0x7F;
        if (count == 0 || count > 4 || (size_t)(end - at) < count) {
            return 0;   /* the indefinite form, or more length bytes than a key can hold */
        }
        size = 0;
        for (size_t index = 0; index < count; index++) {
            size = (size << 8) | at[index];
        }
        at += count;
    }
    if ((size_t)(end - at) < size) {
        return 0;
    }
    *cursor = at + size;
    *tag = found;
    *value = at;
    *length = size;
    return 1;
}

/* The 32 bytes of the private scalar out of the DER of a .p8, or 0. */
static int CharonMusicKitScalar(const unsigned char *der, size_t derLength, unsigned char scalar[CHARON_P256_SCALAR_LENGTH])
{
    const unsigned char *at = der;
    const unsigned char *end = der + derLength;
    unsigned char tag = 0;
    const unsigned char *value = NULL;
    size_t length = 0;

    /* PrivateKeyInfo ::= SEQUENCE { version INTEGER, algorithm SEQUENCE, privateKey OCTET STRING } */
    if (!CharonDERNext(&at, end, &tag, &value, &length) || tag != 0x30) {
        return 0;
    }
    /* The three members are inside the sequence just read, so the walk starts at its content and not
       where the element ended: the first version of this left the cursor after the sequence and read
       the sequence itself as the version. */
    at = value;
    end = value + length;
    if (!CharonDERNext(&at, end, &tag, &value, &length) || tag != 0x02) {   /* version */
        return 0;
    }
    if (!CharonDERNext(&at, end, &tag, &value, &length) || tag != 0x30) {   /* algorithm */
        return 0;
    }
    if (!CharonDERNext(&at, end, &tag, &value, &length) || tag != 0x04) {   /* privateKey */
        return 0;
    }
    /* ECPrivateKey ::= SEQUENCE { version INTEGER, privateKey OCTET STRING, ... } */
    const unsigned char *inner = value;
    const unsigned char *innerEnd = value + length;
    if (!CharonDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x30) {
        return 0;
    }
    inner = value;                       /* the two members are inside the sequence just read */
    innerEnd = value + length;
    if (!CharonDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x02) {
        return 0;
    }
    if (!CharonDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x04 ||
        length != CHARON_P256_SCALAR_LENGTH) {
        return 0;
    }
    memcpy(scalar, value, CHARON_P256_SCALAR_LENGTH);
    return 1;
}

int CharonMusicKitSignES256(const unsigned char *keyDer,
                            size_t keyDerLength,
                            const unsigned char *message,
                            size_t messageLength,
                            unsigned char *raw,
                            size_t capacity)
{
    if (keyDer == NULL || message == NULL || raw == NULL || capacity < CHARON_ES256_RAW_LENGTH) {
        return 0;
    }
    unsigned char scalar[CHARON_P256_SCALAR_LENGTH];
    if (!CharonMusicKitScalar(keyDer, keyDerLength, scalar)) {
        return 0;
    }
    /* micro-ecc's own answer is a DER SEQUENCE of two INTEGERs, which is what Security and Apple's
       key read; a JOSE ES256 signature is the raw pair r || s, 64 bytes, and that is what this
       returns. The two are not the same thing and a verifier will not read one as the other:
       tests/backports/host/musickit/run.sh decoded the DER and reported "signature bytes: 71 (JOSE
       ES256 is the raw r || s, 64)" before this was the conversion.
       The DER is read back with charon@micro-ecc's own reader, CharonCKDERSignatureValues, which is
       the one its header exists to have: "One reader, for the verifier and for the test", because a
       second one here is exactly the drift the shim's own comment is about. */
    unsigned char signature[72];
    int written = CharonCKSignES256(scalar, message, messageLength, signature, sizeof signature);
    if (written <= 0) {
        return 0;
    }
    unsigned char r[CHARON_P256_SCALAR_LENGTH];
    unsigned char s[CHARON_P256_SCALAR_LENGTH];
    if (!CharonCKDERSignatureValues(signature, (size_t)written, r, s)) {
        return 0;
    }
    memcpy(raw, r, sizeof r);
    memcpy(raw + sizeof r, s, sizeof s);
    return CHARON_ES256_RAW_LENGTH;
}
