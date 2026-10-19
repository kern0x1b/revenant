#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#include "CharonQRDecode.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { kNumeric, kAlphanumeric, kAsciiByte, kUTF8Byte, kLatin1Byte, kKinds };
static const char *kKindName[kKinds] = {"numeric", "alnum", "byte", "utf8", "latin1"};
static const int kKindMode[kKinds] = {CharonQRModeNumeric, CharonQRModeAlphanumeric, CharonQRModeByte, CharonQRModeByte,
                                      CharonQRModeByte};
static const NSUInteger kLimit[kKinds] = {7100, 4300, 3000, 3000, 3000};
static const int kVersions[6] = {1, 2, 7, 10, 25, 40};
static const char kLevels[4] = {'L', 'M', 'Q', 'H'};
static const int kEC[6][4] = {{7, 10, 13, 17}, {10, 16, 22, 28}, {20, 18, 18, 26},
                              {18, 26, 24, 28}, {26, 28, 30, 30}, {30, 28, 30, 30}};

static CIContext *context;
static int checks = 0;
static int failures = 0;
static uint64_t rng = 0;

static uint32_t next_random(void)
{
    rng = rng * 6364136223846793005ULL + 1442695040888963407ULL;
    return (uint32_t)(rng >> 33);
}

static CIImage *generate(NSData *message, char level)
{
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:message forKey:@"inputMessage"];
    [filter setValue:[NSString stringWithFormat:@"%c", level] forKey:@"inputCorrectionLevel"];
    return filter.outputImage;
}

static uint8_t *grid_of(CIImage *img, int *size)
{
    *size = 0;
    if (!img) return NULL;
    CGRect extent = img.extent;
    int w = (int)extent.size.width, h = (int)extent.size.height;
    uint8_t *rgba = malloc((size_t)w * h * 4);
    [context render:img toBitmap:rgba rowBytes:w * 4 bounds:extent format:kCIFormatRGBA8 colorSpace:nil];
    int x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            const uint8_t *p = rgba + ((size_t)y * w + x) * 4;
            if (p[3] >= 128 && p[0] < 128) {
                if (x < x0) x0 = x;
                if (x > x1) x1 = x;
                if (y < y0) y0 = y;
                if (y > y1) y1 = y;
            }
        }
    }
    int n = x1 - x0 + 1;
    uint8_t *grid = NULL;
    if (n > 0 && n == y1 - y0 + 1) {
        grid = malloc((size_t)n * n);
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++) {
                const uint8_t *p = rgba + ((size_t)(y0 + r) * w + x0 + c) * 4;
                grid[r * n + c] = (p[3] >= 128 && p[0] < 128) ? 1 : 0;
            }
        *size = n;
    }
    free(rgba);
    return grid;
}

static NSUInteger host_detect(CIImage *img, NSString **message)
{
    CIImage *big = [img imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil
                                              options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    NSArray *features = [detector featuresInImage:big];
    *message = features.count ? [(CIQRCodeFeature *)features[0] messageString] : nil;
    return features.count;
}

static NSString *text_of(const uint8_t *bytes, size_t length)
{
    NSString *text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSISOLatin1StringEncoding];
    return text;
}

static BOOL same(NSString *a, NSString *b)
{
    return (a == nil && b == nil) || [a isEqualToString:b];
}

static NSData *message_of(int kind, NSUInteger n)
{
    static const char *numeric = "0123456789";
    static const char *alphanumeric = "HELLO WORLD $%*+-./:";
    static const char *ascii = "abcdefghijklmnopqrstuvwxyz";
    static const uint8_t utf8Prefix[2] = {0xc3, 0xa9};
    static const uint8_t latin1Prefix[2] = {'h', 0xe9};
    NSMutableData *data = [NSMutableData dataWithCapacity:n];
    for (NSUInteger i = 0; i < n; i++) {
        uint8_t b;
        if (kind == kUTF8Byte && i < 2) b = utf8Prefix[i];
        else if (kind == kLatin1Byte && i < 2) b = latin1Prefix[i];
        else if (kind == kUTF8Byte || kind == kLatin1Byte) b = 'x';
        else if (kind == kNumeric) b = (uint8_t)numeric[i % strlen(numeric)];
        else if (kind == kAlphanumeric) b = (uint8_t)alphanumeric[i % strlen(alphanumeric)];
        else b = (uint8_t)ascii[i % strlen(ascii)];
        [data appendBytes:&b length:1];
    }
    return data;
}

static int size_of(int kind, NSUInteger n, char level)
{
    int size = 0;
    uint8_t *grid = grid_of(generate(message_of(kind, n), level), &size);
    free(grid);
    return size == 0 ? INT_MAX : size;
}

static NSUInteger length_for(int kind, char level, int target, int *exact)
{
    NSUInteger lo = 1, hi = kLimit[kind];
    *exact = 0;
    if (size_of(kind, lo, level) > target) return 0;
    while (lo < hi) {
        NSUInteger mid = (lo + hi + 1) / 2;
        if (size_of(kind, mid, level) <= target) lo = mid;
        else hi = mid - 1;
    }
    *exact = size_of(kind, lo, level) == target;
    return lo;
}

static void flip_region(uint8_t *grid, int size, int count)
{
    uint8_t *taken = calloc((size_t)size * size, 1);
    int region = (size - 9) * (size - 9);
    if (count > region) count = region;
    for (int done = 0; done < count;) {
        int r = 9 + (int)(next_random() % (uint32_t)(size - 9));
        int c = 9 + (int)(next_random() % (uint32_t)(size - 9));
        if (taken[r * size + c]) continue;
        taken[r * size + c] = 1;
        grid[r * size + c] ^= 1;
        done++;
    }
    free(taken);
}

static int decode(const uint8_t *grid, int size, NSString **text, int *mode)
{
    uint8_t out[8192];
    size_t length = 0;
    int status = CharonQRDecode(grid, size, out, sizeof out, &length, mode);
    *text = status == CharonQRDecodeOK ? text_of(out, length) : nil;
    return status;
}

static int ec_of(int version, int levelIndex)
{
    for (int v = 0; v < 6; v++)
        if (kVersions[v] == version) return kEC[v][levelIndex];
    return 0;
}

static void run_case(int kind, int version, int levelIndex, int withDamage)
{
    char level = kLevels[levelIndex];
    int target = 17 + 4 * version;
    int exact = 0;
    NSUInteger n = length_for(kind, level, target, &exact);
    checks++;
    if (!exact) {
        failures++;
        printf("FAIL %-7s v%-2d %c: no length gives version %d\n", kKindName[kind], version, level, version);
        return;
    }
    NSData *message = message_of(kind, n);
    NSString *input = text_of(message.bytes, message.length);

    CIImage *image = generate(message, level);
    int size = 0;
    uint8_t *grid = grid_of(image, &size);
    NSString *host = nil;
    NSUInteger hostCount = host_detect(image, &host);

    NSString *decoded = nil;
    int mode = 0;
    int status = grid ? decode(grid, size, &decoded, &mode) : CharonQRDecodeBadArgument;
    int pass = grid && size == target && hostCount == 1 && same(host, input) && status == CharonQRDecodeOK &&
               same(decoded, host) && mode == kKindMode[kind];

    int safeFlips = ec_of(version, levelIndex) / 2, safeOK = 0, safeTrials = 4, overFailed = 0, overTrials = 2;
    if (grid && pass && withDamage) {
        for (int t = 0; t < safeTrials; t++) {
            uint8_t *damaged = malloc((size_t)size * size);
            memcpy(damaged, grid, (size_t)size * size);
            flip_region(damaged, size, safeFlips);
            NSString *text = nil;
            int m = 0;
            if (decode(damaged, size, &text, &m) == CharonQRDecodeOK && same(text, host)) safeOK++;
            free(damaged);
        }
        for (int t = 0; t < overTrials; t++) {
            uint8_t *damaged = malloc((size_t)size * size);
            memcpy(damaged, grid, (size_t)size * size);
            flip_region(damaged, size, size * size / 4);
            NSString *text = nil;
            int m = 0;
            if (decode(damaged, size, &text, &m) != CharonQRDecodeOK) overFailed++;
            free(damaged);
        }
    }
    int damageOK = !withDamage || (safeOK == safeTrials && overFailed == overTrials);
    if (!pass || !damageOK) failures++;
    printf("%s %-7s v%-2d %c n=%-5lu size=%d host=%lu%s decode=%d mode=%d",
           pass && damageOK ? "ok  " : "FAIL", kKindName[kind], version, level, (unsigned long)n, size,
           (unsigned long)hostCount, same(host, input) ? "" : "(differs from input)", status, mode);
    if (withDamage)
        printf(" safe=%d/%d(k=%d) over=%d/%d", safeOK, safeTrials, safeFlips, overFailed, overTrials);
    printf("\n");
    free(grid);
}

int main(void)
{
    @autoreleasepool {
        context = [CIContext contextWithOptions:nil];
        rng = 0x9E3779B97F4A7C15ULL;
        for (int kind = 0; kind < kKinds; kind++)
            for (int v = 0; v < 6; v++)
                for (int l = 0; l < 4; l++) run_case(kind, kVersions[v], l, 1);
        for (int version = 1; version <= 40; version++)
            for (int l = 0; l < 4; l++) run_case(kAsciiByte, version, l, 0);
        printf("CASES %d FAILURES %d\n", checks, failures);
        return failures > 0 ? 1 : 0;
    }
}
