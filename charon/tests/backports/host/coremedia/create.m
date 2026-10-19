#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

OSStatus CharonHostCMVideoFormatDescriptionCreateFromH264ParameterSets(CFAllocatorRef, size_t, const uint8_t *const *, const size_t *, int, CMFormatDescriptionRef *);

static int failures, checks;
typedef struct {
    int profile, constraint, level, id;
    int chroma, separate, lumaDepth, chromaDepth, bypass, scaling;
    int frameNum, pocType, pocLsb, pocZero, pocNonRef, pocTopBottom, pocCycle, pocRefFrame;
    int refs, gaps, widthMbs, heightUnits, frameOnly, mbaff, direct8x8;
    int crop, cropLeft, cropRight, cropTop, cropBottom;
    int vui, aspect, aspectIdc, sarWidth, sarHeight, overscan, overscanOk;
    int signal, videoFormat, fullRange, colour, primaries, transfer, matrix;
    int chromaLoc, chromaTop, chromaBottom;
    int timing, unitsInTick, timeScale, fixedRate;
    int restriction, reorder, maxDecFrameBuffering, motionOver, bytesPerPic, bitsPerMb, mvHorizontal, mvVertical;
    int nal;
} SPSFields;

typedef struct { NSMutableData *data; uint8_t byte; int bits; } BitWriter;
static void put(BitWriter *w, uint32_t v, int n) { for (int i = n - 1; i >= 0; i--) { w->byte = (uint8_t)((w->byte << 1) | ((v >> i) & 1)); if (++w->bits == 8) { [w->data appendBytes:&w->byte length:1]; w->byte = 0; w->bits = 0; } } }
static void ue(BitWriter *w, uint32_t v) { uint64_t x = (uint64_t)v + 1; int n = 0; while ((x >> n) > 1) n++; put(w, 0, n); put(w, 1, 1); if (n) put(w, (uint32_t)(x & ((1ull << n) - 1)), n); }
static void se(BitWriter *w, int32_t v) { ue(w, (uint32_t)(v > 0 ? 2 * (int64_t)v - 1 : -2 * (int64_t)v)); }
static BOOL highProfile(int p) { return p == 100 || p == 110 || p == 122 || p == 244 || p == 44 || p == 83 || p == 86 || p == 118 || p == 128 || p == 138 || p == 139 || p == 134 || p == 135 || p == 144; }
static NSData *escaped(NSData *rbsp) {
    NSMutableData *out = [NSMutableData data]; const uint8_t *b = rbsp.bytes; int zeros = 0;
    for (NSUInteger i = 0; i < rbsp.length; i++) { if (zeros >= 2 && b[i] <= 3) { uint8_t e = 3; [out appendBytes:&e length:1]; zeros = 0; } [out appendBytes:b + i length:1]; zeros = b[i] ? 0 : zeros + 1; }
    return out;
}
static NSData *writeSPS(SPSFields f) {
    BitWriter w = {[NSMutableData data], 0, 0};
    put(&w, f.profile, 8); put(&w, f.constraint, 8); put(&w, f.level, 8); ue(&w, f.id);
    if (highProfile(f.profile)) {
        ue(&w, f.chroma); if (f.chroma == 3) put(&w, f.separate, 1);
        ue(&w, f.lumaDepth); ue(&w, f.chromaDepth); put(&w, f.bypass, 1); put(&w, f.scaling ? 1 : 0, 1);
        if (f.scaling) for (int i = 0; i < (f.chroma != 3 ? 8 : 12); i++) { int present = (f.scaling >> i) & 1; put(&w, present, 1); if (present) { int size = i < 6 ? 16 : 64; for (int j = 0; j < size; j++) se(&w, j == 0 ? 8 : (j % 3) - 1); } }
    }
    ue(&w, f.frameNum); ue(&w, f.pocType);
    if (f.pocType == 0) ue(&w, f.pocLsb);
    else if (f.pocType == 1) { put(&w, f.pocZero, 1); se(&w, f.pocNonRef); se(&w, f.pocTopBottom); ue(&w, f.pocCycle); for (int i = 0; i < f.pocCycle; i++) se(&w, f.pocRefFrame + i - 1); }
    ue(&w, f.refs); put(&w, f.gaps, 1); ue(&w, f.widthMbs); ue(&w, f.heightUnits); put(&w, f.frameOnly, 1);
    if (!f.frameOnly) put(&w, f.mbaff, 1);
    put(&w, f.direct8x8, 1); put(&w, f.crop, 1);
    if (f.crop) { ue(&w, f.cropLeft); ue(&w, f.cropRight); ue(&w, f.cropTop); ue(&w, f.cropBottom); }
    put(&w, f.vui, 1);
    if (f.vui) {
        put(&w, f.aspect, 1); if (f.aspect) { put(&w, f.aspectIdc, 8); if (f.aspectIdc == 255) { put(&w, f.sarWidth, 16); put(&w, f.sarHeight, 16); } }
        put(&w, f.overscan, 1); if (f.overscan) put(&w, f.overscanOk, 1);
        put(&w, f.signal, 1); if (f.signal) { put(&w, f.videoFormat, 3); put(&w, f.fullRange, 1); put(&w, f.colour, 1); if (f.colour) { put(&w, f.primaries, 8); put(&w, f.transfer, 8); put(&w, f.matrix, 8); } }
        put(&w, f.chromaLoc, 1); if (f.chromaLoc) { ue(&w, f.chromaTop); ue(&w, f.chromaBottom); }
        put(&w, f.timing, 1); if (f.timing) { put(&w, f.unitsInTick, 32); put(&w, f.timeScale, 32); put(&w, f.fixedRate, 1); }
        put(&w, 0, 1); put(&w, 0, 1);
        put(&w, 0, 1);
        put(&w, f.restriction, 1); if (f.restriction) { put(&w, f.motionOver, 1); ue(&w, f.bytesPerPic); ue(&w, f.bitsPerMb); ue(&w, f.mvHorizontal); ue(&w, f.mvVertical); ue(&w, f.reorder); ue(&w, f.maxDecFrameBuffering); }
    }
    put(&w, 1, 1); while (w.bits) put(&w, 0, 1);
    NSMutableData *nal = [NSMutableData dataWithBytes:&(uint8_t){(uint8_t)(f.nal ? f.nal : 0x67)} length:1];
    [nal appendData:escaped(w.data)];
    return nal;
}
static SPSFields baseSPS(void) {
    SPSFields f = {0};
    f.profile = 100; f.level = 31; f.chroma = 1; f.pocLsb = 2; f.refs = 1; f.widthMbs = 79; f.heightUnits = 44; f.frameOnly = 1; f.direct8x8 = 1;
    return f;
}

static uint32_t seed = 12345;
static uint32_t roll(uint32_t n) { seed = seed * 1103515245 + 12345; return (seed >> 8) % n; }

static NSString *outcome(BOOL port, NSArray<NSData *> *sets, int header, CMFormatDescriptionRef *out)
{
    const uint8_t *pointers[40];
    size_t sizes[40];
    for (NSUInteger i = 0; i < sets.count; i++) {
        pointers[i] = sets[i].bytes;
        sizes[i] = sets[i].length;
    }
    CMFormatDescriptionRef desc = (CMFormatDescriptionRef)0x1;
    OSStatus status = (port ? CharonHostCMVideoFormatDescriptionCreateFromH264ParameterSets : CMVideoFormatDescriptionCreateFromH264ParameterSets)(NULL, sets.count, pointers, sizes, header, &desc);
    *out = desc == (CMFormatDescriptionRef)0x1 ? NULL : desc;
    return [NSString stringWithFormat:@"%d %s", (int)status, desc == (CMFormatDescriptionRef)0x1 ? "untouched" : desc ? "set" : "null"];
}

static void compare(NSString *name, NSArray<NSData *> *sets, int header)
{
    CMFormatDescriptionRef system, port;
    NSString *a = outcome(NO, sets, header, &system), *b = outcome(YES, sets, header, &port);
    checks++;
    BOOL same = [a isEqualToString:b] && (!system || CMFormatDescriptionEqual(system, port));
    if (!same && system && port && [a isEqualToString:b]) {
        NSMutableDictionary *x = [(__bridge NSDictionary *)CMFormatDescriptionGetExtensions(system) mutableCopy], *y = [(__bridge NSDictionary *)CMFormatDescriptionGetExtensions(port) mutableCopy];
        NSString *newer = x[(__bridge NSString *)kCVImageBufferYCbCrMatrixKey], *older = y[(__bridge NSString *)kCVImageBufferYCbCrMatrixKey];
        [x removeObjectForKey:(__bridge NSString *)kCVImageBufferYCbCrMatrixKey];
        [y removeObjectForKey:(__bridge NSString *)kCVImageBufferYCbCrMatrixKey];
        CMVideoDimensions p = CMVideoFormatDescriptionGetDimensions(system), q = CMVideoFormatDescriptionGetDimensions(port);
        same = [@[@"ITU_R_2100_ICtCp", @"IPT_C2", @"IPT"] containsObject:newer] && [older hasPrefix:@"YCbCrMatrix#"] && [x isEqual:y] && p.width == q.width && p.height == q.height;
    }
    if (!same) {
        failures++;
        if (failures <= 20) {
            NSString *x = system ? (__bridge_transfer NSString *)CFCopyDescription(system) : @"", *y = port ? (__bridge_transfer NSString *)CFCopyDescription(port) : @"";
            printf("DIFFERENT %s:\n  system %s %s\n  port   %s %s\n  sets", name.UTF8String, a.UTF8String, x.UTF8String, b.UTF8String, y.UTF8String);
            for (NSData *set in sets)
                printf(" %s", set.description.UTF8String);
            printf("\n");
        }
    }
    if (system)
        CFRelease(system);
    if (port)
        CFRelease(port);
}

static SPSFields randomSPS(void)
{
    static const int profiles[] = {66, 77, 88, 100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135, 144};
    SPSFields f = baseSPS();
    f.profile = profiles[roll(17)];
    f.constraint = (int)roll(256);
    f.level = (int)roll(256);
    f.id = (int)roll(32);
    f.chroma = (int)roll(4);
    f.separate = (int)roll(2);
    f.lumaDepth = (int)roll(7);
    f.chromaDepth = (int)roll(7);
    f.bypass = (int)roll(2);
    f.scaling = roll(4) ? 0 : (int)roll(4096);
    f.frameNum = (int)roll(13);
    f.pocType = (int)roll(3);
    f.pocLsb = (int)roll(13);
    f.pocZero = (int)roll(2);
    f.pocNonRef = (int)roll(20) - 10;
    f.pocTopBottom = (int)roll(20) - 10;
    f.pocCycle = (int)roll(6);
    f.refs = (int)roll(17);
    f.gaps = (int)roll(2);
    f.widthMbs = (int)roll(120);
    f.heightUnits = (int)roll(70);
    f.frameOnly = (int)roll(2);
    f.mbaff = (int)roll(2);
    f.direct8x8 = f.frameOnly ? (int)roll(2) : 1;
    f.crop = (int)roll(2);
    f.cropLeft = (int)roll(4);
    f.cropRight = (int)roll(4);
    f.cropTop = (int)roll(4);
    f.cropBottom = (int)roll(4);
    f.vui = (int)roll(2);
    f.aspect = (int)roll(2);
    f.aspectIdc = roll(3) ? (int)roll(20) : 255;
    f.sarWidth = (int)roll(5);
    f.sarHeight = (int)roll(5);
    f.overscan = (int)roll(2);
    f.overscanOk = (int)roll(2);
    f.signal = (int)roll(2);
    f.videoFormat = (int)roll(8);
    f.fullRange = (int)roll(2);
    f.colour = (int)roll(2);
    f.primaries = (int)roll(24);
    f.transfer = (int)roll(24);
    f.matrix = (int)roll(14);
    f.chromaLoc = (int)roll(2);
    f.chromaTop = (int)roll(8);
    f.chromaBottom = (int)roll(8);
    f.timing = (int)roll(2);
    f.unitsInTick = (int)roll(1000) + 1;
    f.timeScale = (int)roll(100000) + 1;
    f.fixedRate = (int)roll(2);
    f.restriction = (int)roll(2);
    f.reorder = (int)roll(4);
    f.maxDecFrameBuffering = (int)roll(8);
    f.nal = 0x07 | (int)(1 + roll(3)) << 5;
    return f;
}

static NSData *hex(const char *text)
{
    NSMutableData *data = [NSMutableData data];
    for (const char *c = text; c[0] && c[1]; c += 2) {
        unsigned value;
        sscanf(c, "%2x", &value);
        uint8_t byte = (uint8_t)value;
        [data appendBytes:&byte length:1];
    }
    return data;
}

static NSData *randomPPS(void)
{
    NSMutableData *data = [NSMutableData dataWithBytes:&(uint8_t){(uint8_t)(0x08 | (1 + roll(3)) << 5)} length:1];
    NSUInteger length = 1 + roll(8);
    for (NSUInteger i = 0; i < length; i++) {
        uint8_t byte = (uint8_t)roll(256);
        [data appendBytes:&byte length:1];
    }
    return data;
}

static void encoded(void *context, void *frame, OSStatus status, VTEncodeInfoFlags flags, CMSampleBufferRef sample)
{
    CMFormatDescriptionRef *out = context;
    if (sample && !*out)
        *out = (CMFormatDescriptionRef)CFRetain(CMSampleBufferGetFormatDescription(sample));
}

static NSArray<NSData *> *encoderSets(int width, int height, CFStringRef profile, BOOL fullRange)
{
    VTCompressionSessionRef session = NULL;
    CMFormatDescriptionRef format = NULL;
    if (VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, encoded, &format, &session) != noErr)
        return nil;
    VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, profile);
    VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    CVPixelBufferRef pixels = NULL;
    CVPixelBufferCreate(NULL, width, height, fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}}, &pixels);
    VTCompressionSessionEncodeFrame(session, pixels, CMTimeMake(0, 30), kCMTimeInvalid, NULL, NULL, NULL);
    VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
    VTCompressionSessionInvalidate(session);
    CFRelease(session);
    CVPixelBufferRelease(pixels);
    if (!format)
        return nil;
    NSMutableArray<NSData *> *sets = [NSMutableArray array];
    size_t count = 0;
    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, NULL, NULL, &count, NULL);
    for (size_t i = 0; i < count; i++) {
        const uint8_t *bytes;
        size_t size;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, i, &bytes, &size, NULL, NULL);
        [sets addObject:[NSData dataWithBytes:bytes length:size]];
    }
    CFRelease(format);
    return sets;
}

int main(void)
{
    @autoreleasepool {
        NSData *pps = hex("68ebecb22c"), *extension = hex("6d4000");
        int encoderChecks = 0;
        CFStringRef profiles[] = {kVTProfileLevel_H264_Baseline_AutoLevel, kVTProfileLevel_H264_Main_AutoLevel, kVTProfileLevel_H264_High_AutoLevel};
        int sizes[][2] = {{1280, 720}, {1920, 1080}, {640, 480}, {642, 362}, {320, 240}, {176, 144}, {1080, 1920}, {854, 480}};
        for (int p = 0; p < 3; p++)
            for (int z = 0; z < 8; z++)
                for (int range = 0; range < 2; range++) {
                    NSArray<NSData *> *sets = encoderSets(sizes[z][0], sizes[z][1], profiles[p], range);
                    if (!sets)
                        continue;
                    encoderChecks++;
                    compare([NSString stringWithFormat:@"encoder %dx%d profile %d range %d", sizes[z][0], sizes[z][1], p, range], sets, 4);
                    compare([NSString stringWithFormat:@"encoder %dx%d profile %d range %d reversed", sizes[z][0], sizes[z][1], p, range], sets.reverseObjectEnumerator.allObjects, 2);
                }
        printf("create: %d encoder parameter sets\n", encoderChecks);
        if (encoderChecks == 0) {
            failures++;
            printf("the host encoder produced no parameter sets to compare\n");
        }
        SPSFields plain = baseSPS();
        NSData *sps = writeSPS(plain);
        for (int header = 0; header <= 5; header++)
            compare([NSString stringWithFormat:@"header %d", header], @[sps, pps], header);
        compare(@"sps only", @[sps], 4);
        compare(@"pps only", @[pps, pps], 4);
        compare(@"extension", @[sps, pps, extension], 4);
        compare(@"extension first", @[extension, pps, sps], 4);
        SPSFields baseline = baseSPS();
        baseline.profile = 66;
        compare(@"extension with a baseline record", @[writeSPS(baseline), pps, extension], 4);
        const char *units[] = {"65888400", "06050102", "41e000", "09f0", "0c", "6c", "70", "78", "00", "80", "e7", "07", "08", "0d", "2d4000", "68", "6800", "680f", "6810", "6d08", "6d0880", "67", "6764001f", "6764001fac", "68000003ff"};
        for (size_t i = 0; i < sizeof units / sizeof *units; i++) {
            compare([NSString stringWithFormat:@"unit %s after", units[i]], @[sps, pps, hex(units[i])], 4);
            compare([NSString stringWithFormat:@"unit %s before", units[i]], @[hex(units[i]), sps, pps], 4);
        }
        for (int field = 0; field < 3; field++)
            for (int code = 0; code < 256; code++) {
                SPSFields f = baseSPS();
                f.vui = f.signal = f.colour = 1;
                f.primaries = f.transfer = f.matrix = 2;
                if (field == 0)
                    f.primaries = code;
                else if (field == 1)
                    f.transfer = code;
                else
                    f.matrix = code;
                if (field == 2 && (code == 14 || code == 15 || code == 248))
                    continue;
                compare([NSString stringWithFormat:@"colour field %d code %d", field, code], @[writeSPS(f), pps], 4);
            }
        // The three offsets of pic_order_cnt_type 1 over the range the standard gives them, -2^31+1 to 2^31-1:
        // the host takes -4095 to 4095 and refuses 4096 on (-12710), and the port must answer the same.
        int offsets[] = {4095, 4096, -4095, -4096, 8190, 8191, -8191, 100000, -100000, 2147483646, 2147483647, -2147483647};
        for (int field = 0; field < 3; field++)
            for (size_t i = 0; i < sizeof offsets / sizeof *offsets; i++) {
                SPSFields f = baseSPS();
                f.pocType = 1;
                f.pocCycle = 2;
                if (field == 0)
                    f.pocNonRef = offsets[i];
                else if (field == 1)
                    f.pocTopBottom = offsets[i];
                else
                    f.pocRefFrame = offsets[i] > 0 ? offsets[i] : offsets[i] + 1;   // the cycle holds the offset itself
                NSArray<NSData *> *sets = @[writeSPS(f), pps];
                compare([NSString stringWithFormat:@"picture order count type 1 field %d offset %d", field, offsets[i]], sets, 4);
                // The boundary itself, held to what the host measured on 2026-09-23: this fails, and the port's
                // limit is to be read again, if CoreMedia ever takes an offset past 4095 or refuses one inside.
                CMFormatDescriptionRef made;
                NSString *system = outcome(NO, sets, 4, &made);
                if (made)
                    CFRelease(made);
                BOOL inside = offsets[i] >= -4095 && offsets[i] <= 4095;
                NSString *expected = inside ? @"0 set" : @"-12710 untouched";
                checks++;
                if (![system isEqualToString:expected]) {
                    failures++;
                    printf("BOUNDARY field %d offset %d: the host answers %s, measured %s\n", field, offsets[i], system.UTF8String, expected.UTF8String);
                }
            }
        for (int idc = 0; idc < 256; idc++) {
            SPSFields f = baseSPS();
            f.vui = f.aspect = 1;
            f.aspectIdc = idc;
            f.sarWidth = idc % 7;
            f.sarHeight = idc % 5;
            compare([NSString stringWithFormat:@"aspect %d", idc], @[writeSPS(f), pps], 4);
        }
        for (int top = 0; top < 8; top++)
            for (int bottom = 0; bottom < 8; bottom++) {
                SPSFields f = baseSPS();
                f.vui = f.chromaLoc = 1;
                f.chromaTop = top;
                f.chromaBottom = bottom;
                compare([NSString stringWithFormat:@"chroma location %d %d", top, bottom], @[writeSPS(f), pps], 4);
            }
        for (int i = 0; i < 4000; i++) {
            NSData *one = writeSPS(randomSPS());
            compare([NSString stringWithFormat:@"random %d", i], @[one, randomPPS()], roll(2) ? 4 : 1 + (int)roll(2));
            NSMutableData *cut = [one mutableCopy];
            cut.length = 1 + roll((uint32_t)one.length);
            compare([NSString stringWithFormat:@"random %d cut to %lu", i, (unsigned long)cut.length], @[cut, pps], 4);
            NSMutableData *flipped = [one mutableCopy];
            ((uint8_t *)flipped.mutableBytes)[1 + roll((uint32_t)one.length - 1)] ^= (uint8_t)(1 << roll(8));
            compare([NSString stringWithFormat:@"random %d flipped", i], @[flipped, pps], 4);
        }
        for (int i = 0; i < 3000; i++) {
            SPSFields f = randomSPS();
            NSMutableArray<NSData *> *sets = [NSMutableArray array];
            int sequences = 1 + (int)roll(3), pictures = 1 + (int)roll(3), extensions = (int)roll(2);
            for (int s = 0; s < sequences; s++) {
                SPSFields g = f;
                if (roll(2)) {
                    g.id = (int)roll(32);
                    g.vui = (int)roll(2);
                    g.fullRange = (int)roll(2);
                    g.primaries = (int)roll(24);
                    g.level = (int)roll(256);
                    g.constraint = (int)roll(256);
                    g.refs = (int)roll(17);
                }
                if (!roll(6))
                    g.profile = (int[]){66, 77, 100, 110, 122, 244}[roll(6)];
                if (!roll(6))
                    g.lumaDepth = (int)roll(7);
                if (!roll(8))
                    g.heightUnits = (int)roll(70);
                [sets addObject:writeSPS(g)];
            }
            for (int p = 0; p < pictures; p++)
                [sets addObject:randomPPS()];
            for (int e = 0; e < extensions; e++)
                [sets addObject:extension];
            for (NSUInteger k = sets.count - 1; k > 0; k--)
                [sets exchangeObjectAtIndex:k withObjectAtIndex:roll((uint32_t)k + 1)];
            compare([NSString stringWithFormat:@"set %d", i], sets, 4);
        }
        SPSFields f = baseSPS();
        f.vui = f.signal = f.colour = 1;
        f.primaries = f.transfer = 2;
        for (int i = 0; i < 3; i++) {
            int code = (int[]){14, 15, 248}[i];
            f.matrix = code;
            CMFormatDescriptionRef system, port;
            NSData *one = writeSPS(f);
            outcome(NO, @[one, pps], 4, &system);
            outcome(YES, @[one, pps], 4, &port);
            NSString *a = CMFormatDescriptionGetExtension(system, kCVImageBufferYCbCrMatrixKey), *b = CMFormatDescriptionGetExtension(port, kCVImageBufferYCbCrMatrixKey);
            checks++;
            if ([a isEqual:b] || ![b isEqual:[NSString stringWithFormat:@"YCbCrMatrix#%d", code]]) {
                failures++;
                printf("DIVERGENCE GONE matrix %d: system %s port %s\n", code, a.UTF8String, b.UTF8String);
            }
            CFRelease(system);
            CFRelease(port);
        }
        printf("create: %d checks, %d different\n", checks, failures);
    }
    return failures != 0;
}
