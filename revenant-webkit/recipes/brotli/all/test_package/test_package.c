#include <brotli/decode.h>
#include <brotli/encode.h>
#include <string.h>

int main(void)
{
    const char text[] = "brotli round trip";
    uint8_t compressed[128];
    size_t compressed_size = sizeof(compressed);
    if (!BrotliEncoderCompress(BROTLI_DEFAULT_QUALITY, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_TEXT,
                               sizeof(text), (const uint8_t*)text, &compressed_size, compressed))
        return 1;
    uint8_t decoded[sizeof(text)];
    size_t decoded_size = sizeof(decoded);
    if (BrotliDecoderDecompress(compressed_size, compressed, &decoded_size, decoded) != BROTLI_DECODER_RESULT_SUCCESS)
        return 1;
    return decoded_size == sizeof(text) && !memcmp(decoded, text, sizeof(text)) ? 0 : 1;
}
