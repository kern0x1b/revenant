#include "MusicKitC.h"
#include "RevenantCKWebAuth.h"

#include <string.h>

#define REVENANT_P256_SCALAR_LENGTH 32
#define REVENANT_ES256_RAW_LENGTH (2 * REVENANT_P256_SCALAR_LENGTH)

static int RevenantDERNext(const unsigned char **cursor, const unsigned char *end,
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
            return 0;
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

static int RevenantMusicKitScalar(const unsigned char *der, size_t derLength, unsigned char scalar[REVENANT_P256_SCALAR_LENGTH])
{
    const unsigned char *at = der;
    const unsigned char *end = der + derLength;
    unsigned char tag = 0;
    const unsigned char *value = NULL;
    size_t length = 0;

    if (!RevenantDERNext(&at, end, &tag, &value, &length) || tag != 0x30) {
        return 0;
    }
    at = value;
    end = value + length;
    if (!RevenantDERNext(&at, end, &tag, &value, &length) || tag != 0x02) {
        return 0;
    }
    if (!RevenantDERNext(&at, end, &tag, &value, &length) || tag != 0x30) {
        return 0;
    }
    if (!RevenantDERNext(&at, end, &tag, &value, &length) || tag != 0x04) {
        return 0;
    }
    const unsigned char *inner = value;
    const unsigned char *innerEnd = value + length;
    if (!RevenantDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x30) {
        return 0;
    }
    inner = value;
    innerEnd = value + length;
    if (!RevenantDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x02) {
        return 0;
    }
    if (!RevenantDERNext(&inner, innerEnd, &tag, &value, &length) || tag != 0x04 ||
        length != REVENANT_P256_SCALAR_LENGTH) {
        return 0;
    }
    memcpy(scalar, value, REVENANT_P256_SCALAR_LENGTH);
    return 1;
}

int RevenantMusicKitSignES256(const unsigned char *keyDer,
                            size_t keyDerLength,
                            const unsigned char *message,
                            size_t messageLength,
                            unsigned char *raw,
                            size_t capacity)
{
    if (keyDer == NULL || message == NULL || raw == NULL || capacity < REVENANT_ES256_RAW_LENGTH) {
        return 0;
    }
    unsigned char scalar[REVENANT_P256_SCALAR_LENGTH];
    if (!RevenantMusicKitScalar(keyDer, keyDerLength, scalar)) {
        return 0;
    }
    unsigned char signature[72];
    int written = RevenantCKSignES256(scalar, message, messageLength, signature, sizeof signature);
    if (written <= 0) {
        return 0;
    }
    unsigned char r[REVENANT_P256_SCALAR_LENGTH];
    unsigned char s[REVENANT_P256_SCALAR_LENGTH];
    if (!RevenantCKDERSignatureValues(signature, (size_t)written, r, s)) {
        return 0;
    }
    memcpy(raw, r, sizeof r);
    memcpy(raw + sizeof r, s, sizeof s);
    return REVENANT_ES256_RAW_LENGTH;
}
