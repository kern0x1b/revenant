#include <webp/decode.h>
#include <webp/demux.h>
#include <webp/mux.h>

int main(int argc, char **argv) {
    (void)argv;
    return WebPGetDecoderVersion() != 0 && WebPGetDemuxVersion() != 0 && WebPGetMuxVersion() != 0 && argc > 0 ? 0 : 1;
}
