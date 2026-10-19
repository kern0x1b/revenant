#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define PORTED(name) revenantHost_##name

#define EXPECTED_OPENGLES_KEY "OpenGLESTextureCacheCompatibility"

#define ROW(api) { #api, "revenantHost_" #api }
static const struct { const char *api; const char *portSymbol; } kRows[] = {
    ROW(kCVPixelBufferOpenGLESTextureCacheCompatibilityKey),
    ROW(kCVImageBufferAlphaChannelModeKey),
    ROW(kCVImageBufferAlphaChannelMode_PremultipliedAlpha),
    ROW(kCVImageBufferAlphaChannelMode_StraightAlpha),
    ROW(kCVImageBufferAmbientViewingEnvironmentKey),
    ROW(kCVImageBufferRegionOfInterestKey),
    ROW(kCVMetalTextureStorageMode),
    ROW(kCVMetalTextureUsage),
    ROW(kCVPixelBufferProResRAWKey_BlackLevel),
    ROW(kCVPixelBufferProResRAWKey_ColorMatrix),
    ROW(kCVPixelBufferProResRAWKey_GainFactor),
    ROW(kCVPixelBufferProResRAWKey_MetadataExtension),
    ROW(kCVPixelBufferProResRAWKey_RecommendedCrop),
    ROW(kCVPixelBufferProResRAWKey_SenselSitingOffsets),
    ROW(kCVPixelBufferProResRAWKey_WhiteBalanceBlueFactor),
    ROW(kCVPixelBufferProResRAWKey_WhiteBalanceCCT),
    ROW(kCVPixelBufferProResRAWKey_WhiteBalanceRedFactor),
    ROW(kCVPixelBufferProResRAWKey_WhiteLevel),
    ROW(kCVPixelBufferVersatileBayerKey_BayerPattern),
    ROW(kCVPixelFormatContainsSenselArray),
};
enum { kRowCount = sizeof(kRows) / sizeof(kRows[0]) };

static CFStringRef value_of(const char *symbol)
{
    void *address = dlsym(RTLD_DEFAULT, symbol);
    return address ? *(CFStringRef *)address : NULL;
}

static void text_of(CFStringRef s, char *out, size_t n)
{
    if (!s) { snprintf(out, n, "(null)"); return; }
    if (!CFStringGetCString(s, out, (CFIndex)n, kCFStringEncodingUTF8)) snprintf(out, n, "(unprintable)");
}

int main(void)
{
    static char host[512], port[512];
    int same = 0, different = 0, host_absent = 0, port_null = 0;

    for (int i = 0; i < kRowCount; i++) {
        const char *api = kRows[i].api;
        CFStringRef hostValue = value_of(api);
        CFStringRef portValue = value_of(kRows[i].portSymbol);
        text_of(hostValue, host, sizeof(host));
        text_of(portValue, port, sizeof(port));
        if (!portValue) port_null++;
        if (!hostValue) host_absent++;

        const char *against = host;
        const char *source = "the host";
        int agrees;
        if (hostValue) {
            agrees = strcmp(host, port) == 0;
        } else {
            against = EXPECTED_OPENGLES_KEY;
            source = "the iOS 9.0 cache";
            agrees = strcmp(EXPECTED_OPENGLES_KEY, port) == 0;
        }
        if (agrees) same++; else different++;
        printf("%-4s %-52s compared_against=%-17s %-33s port=%s\n",
               agrees ? "ok" : "BAD", api, source, against, port);
    }
    printf("constants: asked=%d same=%d different=%d host_does_not_export=%d port_null=%d\n",
           kRowCount, same, different, host_absent, port_null);
    return different == 0 && port_null == 0 ? 0 : 1;
}
