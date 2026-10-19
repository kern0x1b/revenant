// values.m - the twenty CoreVideo constant strings this port carries, read from the host's own
// CoreVideo, and compared against the port's own copy of each.
//
// The host is the oracle for the value a CFStringRef constant holds: the symbol's address comes from
// CoreVideo's export trie, and the __cfstring stored there names the text. The port's copies are
// linked into this same binary under their own names, so both answers are in one process and the
// comparison is between the port and the system, never against a recorded expectation.
//
// One name, kCVPixelBufferOpenGLESTextureCacheCompatibilityKey, the header of iOS 16.4 marks
// API_UNAVAILABLE(macosx), so it could not be assumed that the host has it. It does: the run of
// 2026-09-30 reports host_does_not_export=0, and the host's own 20 bytes are the ones the iOS 9.0
// armv7 cache carries, which is the second, independent source for that value. So the host is the
// comparison for all twenty and EXPECTED_OPENGLES_KEY below is the fallback for a host that does
// not export it, holding the iOS 9.0 text either way. The line prints which of the two it compared
// against, so a run that fell back says so instead of looking identical to one that did not.
//
// Every name is printed whatever the answer, so a name the host does not export is a visible line
// and not a missing one: `asked` counts the names asked about, never the ones that matched.
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define PORTED(name) charonHost_##name

// Read from the iOS 9.0 armv7 cache, tools/corpus/cache-value.lua:
//   _kCVPixelBufferOpenGLESTextureCacheCompatibilityKey  0x34232848  OpenGLESTextureCacheCompatibility
//   (33 bytes, flags 0x7c8, cfstring 0x34233800)
#define EXPECTED_OPENGLES_KEY "OpenGLESTextureCacheCompatibility"

#define ROW(api) { #api, "charonHost_" #api }
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

// Both symbols are read the same way, the host's own name and the port's renamed one, so neither
// side is favoured by how it was reached.
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
            // No host symbol: the row is held to the value the iOS 9.0 armv7 cache carries, which is
            // the other of the two independent sources for it, and the line says which one it used.
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
