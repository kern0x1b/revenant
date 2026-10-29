#include <stddef.h>
#include <stdint.h>

#define REVENANT_QR_MAX_RESULTS 8

typedef struct {
    char *text;
    size_t length;
    float corners[4][2];
    int version;
    int level;
    int mirrored;
    int undecodable;
} RevenantQRResult;

typedef int (*RevenantQRConverter)(int eci, const uint8_t *bytes, size_t length, char **out, size_t *outLength);

void revenant_qr_set_converter(RevenantQRConverter converter);

void revenant_qr_install_default_converter(void);

int revenant_qr_decode(const uint8_t *luma, int width, int height, int stride, RevenantQRResult *results, int capacity);

int revenant_qr_decode_region(const uint8_t *luma, int width, int height, int stride, float x, float y, float regionWidth, float regionHeight, RevenantQRResult *results, int capacity);

void revenant_qr_result_free(RevenantQRResult *result);
