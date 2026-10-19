#include <webp/decode.h>
#include <webp/demux.h>
#include <webp/encode.h>
#include <stdint.h>

int main(void)
{
    uint8_t pixels[4 * 4 * 3];
    for (int i = 0; i < (int)sizeof(pixels); ++i)
        pixels[i] = (uint8_t)(i * 7);
    uint8_t *encoded = NULL;
    size_t size = WebPEncodeLosslessRGB(pixels, 4, 4, 4 * 3, &encoded);
    if (!size)
        return 1;
    int width = 0, height = 0;
    int ok = WebPGetInfo(encoded, size, &width, &height) && width == 4 && height == 4;
    WebPData data = { encoded, size };
    WebPDemuxer *demuxer = WebPDemux(&data);
    ok = ok && demuxer && WebPDemuxGetI(demuxer, WEBP_FF_FRAME_COUNT) == 1;
    WebPDemuxDelete(demuxer);
    WebPFree(encoded);
    return ok ? 0 : 1;
}
