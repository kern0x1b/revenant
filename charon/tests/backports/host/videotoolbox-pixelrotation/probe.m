// probe.m - the oracle for VideoToolbox's pixel rotation family: what this Mac's own
// VTPixelRotationSession does, per source shape, per pixel format, per stride and per angle, COMPARED
// AGAINST AN INDEPENDENT EXPECTATION.
//
// WHY THE EXPECTATION IS COMPUTED HERE AND NOT READ OFF APPLE: a differential that compares the port
// with the host proves the port equals the host, and a harness that compares the host with whatever the
// host did proves nothing. So every cell's expected pixels are derived from the source pattern alone,
// printed, and only then compared with Apple's.
//
// THE FOUR FAULTS THIS FILE EXISTS TO NOT REPEAT, all of which cost a probe earlier in this family:
//   1. THE PROPERTY'S VALUE IS A CFStringRef, NOT A NUMBER. VTPixelRotationProperties.h:32 says
//      "Specifies the amount of rotation in degrees" and then, seven lines later, declares the property as
//      CFStringRef with the valid values kVTRotation_0, kVTRotation_CW90, kVTRotation_180 and
//      kVTRotation_CCW90. A probe that sets an NSNumber has its set REJECTED, the session keeps its
//      default of kVTRotation_0, and every angle then reads as the identity. The status the set returns is
//      printed here, the value is read back, and the three ways of getting this wrong are measured at the
//      end of the run.
//   2. ROWS ARE WRITTEN AND READ AT THE BUFFER'S OWN bytesPerRow. CVPixelBufferCreate hands a 2-pixel-wide
//      BGRA image a bytesPerRow of 64, and writing 16 contiguous bytes puts the second image row at offset
//      16 - outside the image. A stride the caller forced is asserted, not assumed: see make_buffer.
//   3. THE EXPECTATION IS AS BIG AS THE DESTINATION. A 2x4 source rotated by 90 or 270 gives a 4x2
//      destination, which is EIGHT values; sizing the expectation at four compares the top row and calls
//      the rest agreement. Every cell here is sized by the destination's own geometry.
//   4. THE FLIPS WERE MIRRORED IN SOURCE SPACE. VTPixelRotationProperties.h:50 and :61 say the flips apply
//      AFTER the rotation, which has to mean on the DESTINATION axes: transposing and then mirroring the
//      source is not the same as mirroring the destination. It agreed for 0 and 180, where no axis is
//      swapped, and disagreed for every quarter turn with ONE flip. The flips invert the DESTINATION
//      coordinate first.
//
// WHAT IS MEASURED AND NOT ASSUMED ABOUT THE BUFFER ITSELF: a same-format rotation is a pure byte
// permutation. All four channels of every pixel are compared here, not one of them, and the bytes between
// the end of a row and the start of the next are compared with the fill that was written there - a
// rotation that wrote into the padding would be a rotation that does not only permute.
//
// WHAT THIS FILE DELIBERATELY DOES NOT CLAIM: any biplanar YUV. A 420 image's chroma planes are
// subsampled by two on each axis, so rotating one is a second contract with its own arithmetic, and the
// host answers 420 destinations with noErr and a colour CONVERSION (measured at the end of the run), not
// with a rotation. Those formats are not carried and are not claimed.
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <IOSurface/IOSurface.h>

#define MAX_PIXELS 64   /* the largest source below is 4x3 = 12; 64 leaves room without a heap */

static int b_value(int index) { return 10 * index + 1; }   /* unique per pixel, and never 0xAB */

// ---- the shapes, each with the 180 written out longhand -------------------------------------
//
// A source of W x H whose display channel runs 1 2 3 4 ... row-major must come back from a 180 upside
// down, and these are the eight, ten, ... values written out by hand for each shape. They are checked
// against expected() BEFORE the host is asked for that shape, so a wrong expectation shows as DISAGREE
// with no comparison having run - which is exactly how the 2x4 geometry fault was caught.
typedef struct {
    const char *label;
    size_t width, height;
    size_t padding;        /* extra bytes per row beyond width*4; 0 lets CoreVideo choose the stride */
    const int *hand180;    /* the destination's display channel, row-major, for kVTRotation_180 */
    int hand180Count;
} Shape;

static const int hand180_2x4[] = { 71, 61, 51, 41, 31, 21, 11, 1 };
static const int hand180_2x4pad[] = { 71, 61, 51, 41, 31, 21, 11, 1 };
static const int hand180_3x5[] = { 141, 131, 121, 111, 101, 91, 81, 71, 61, 51, 41, 31, 21, 11, 1 };
static const int hand180_1x4[] = { 31, 21, 11, 1 };
static const int hand180_1x4pad[] = { 31, 21, 11, 1 };
static const int hand180_5x1[] = { 41, 31, 21, 11, 1 };
static const int hand180_1x1[] = { 1 };
static const int hand180_2x2[] = { 31, 21, 11, 1 };
static const int hand180_4x3[] = { 111, 101, 91, 81, 71, 61, 51, 41, 31, 21, 11, 1 };

// The formats the oracle HOLDS: the ones whose same-format rotation came back a pure permutation of the
// bytes, all four channels, at every shape and every stride. The display channel is the byte the
// hand-written arrays above are about: 0 for 32BGRA (B,G,R,A), 1 for 32ARGB (A,R,G,B).
static const struct { OSType format; const char *name; int displayChannel; } FORMATS[] = {
    {kCVPixelFormatType_32BGRA, "BGRA", 0},
    {kCVPixelFormatType_32ARGB, "ARGB", 1},
};

// A label is ONE word, with no space in it: run.sh reads the shape out of the SIZE line by field, and a
// space here would shift every field after it. `+padN` is N bytes of padding the caller forces per row.
static const Shape SHAPES[] = {
    {"2x4",       2, 4,  0, hand180_2x4,    8},
    {"2x4+pad16", 2, 4, 16, hand180_2x4pad, 8},
    {"3x5",       3, 5,  0, hand180_3x5,   15},
    {"3x5+pad16", 3, 5, 16, hand180_3x5,   15},
    {"1x4",       1, 4,  0, hand180_1x4,    4},
    {"1x4+pad12", 1, 4, 12, hand180_1x4pad, 4},
    {"5x1+pad16", 5, 1, 16, hand180_5x1,    5},
    {"1x1+pad16", 1, 1, 16, hand180_1x1,    1},
    {"2x2+pad8",  2, 2,  8, hand180_2x2,    4},
    {"4x3+pad12", 4, 3, 12, hand180_4x3,   12},
};
#define SHAPE_COUNT ((int)(sizeof(SHAPES) / sizeof(SHAPES[0])))

// The sixteen cells: four rotations, and the two flips alone and together. The rotation values are extern
// CFStringRef variables, not constants, so this table is a local of main() and OP_COUNT is spelled there.
#define OP_COUNT 16

static void describe(const char *label, CVPixelBufferRef buffer)
{
    if (!buffer) { printf("%-12s (none)\n", label); return; }
    printf("%-12s %zux%zu bytesPerRow=%zu format=%c%c%c%c iosurface=%d\n", label,
           CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer),
           CVPixelBufferGetBytesPerRow(buffer),
           (char)(CVPixelBufferGetPixelFormatType(buffer) >> 24 & 0xFF),
           (char)(CVPixelBufferGetPixelFormatType(buffer) >> 16 & 0xFF),
           (char)(CVPixelBufferGetPixelFormatType(buffer) >> 8 & 0xFF),
           (char)(CVPixelBufferGetPixelFormatType(buffer) & 0xFF),
           CVPixelBufferGetIOSurface(buffer) != NULL);
}

// A pixel's FOUR bytes, so a permutation of the channels or a change to one of them cannot pass. The
// display channel carries b_value(index), which is what the hand-written 180s are written in; the other
// three are distinct per pixel and distinct from it.
static void pixel_bytes(int displayChannel, int index, uint8_t out[4])
{
    for (int c = 0; c < 4; c++)
        out[c] = (uint8_t)(c == displayChannel ? b_value(index)
                                       : 65 + (uint8_t)(((c - displayChannel + 4) % 4 - 1) * 64 + index));
}

// The destination's GEOMETRY, from the rotation alone. Fault 3's sibling: deriving this from a pixel
// COUNT gives 4x2 for 0 and 180 as well as for 90 and 270, because a 2x4 source rotated by nothing still
// has eight pixels. Apple then scale-to-fits instead of rotating, and the result is an interpolated value
// that made this look like a broken rotation in the first place. Only 90 and 270 transpose.
static void geometry(const Shape *shape, CFStringRef rotation, size_t *outWidth, size_t *outHeight)
{
    int quarter = CFEqual(rotation, kVTRotation_CW90) || CFEqual(rotation, kVTRotation_CCW90);
    *outWidth = quarter ? shape->height : shape->width;
    *outHeight = quarter ? shape->width : shape->height;
}

// Which source pixel a destination pixel must hold, from the source pattern alone.
//   90  (clockwise):      dest(x,y) = src(y, H-1-x)
//   180:                 dest(x,y) = src(W-1-x, H-1-y)
//   270 (counter-clock): dest(x,y) = src(W-1-y, x)
// The two flips apply AFTER the rotation, on the DESTINATION axes: the destination coordinate is inverted
// first, and the rotation then takes it to the source.
static int source_index(const Shape *shape, CFStringRef rotation, int flipH, int flipV,
                        size_t dw, size_t dh, int x, int y)
{
    int px = flipH ? (int)dw - 1 - x : x;
    int py = flipV ? (int)dh - 1 - y : y;
    int sx, sy;
    if (CFEqual(rotation, kVTRotation_CW90))      { sx = py;               sy = (int)shape->height - 1 - px; }
    else if (CFEqual(rotation, kVTRotation_180))   { sx = (int)shape->width - 1 - px; sy = (int)shape->height - 1 - py; }
    else if (CFEqual(rotation, kVTRotation_CCW90)) { sx = (int)shape->width - 1 - py; sy = px; }
    else                                           { sx = px;               sy = py; }
    return sy * (int)shape->width + sx;
}

static int expected_display(const Shape *shape, CFStringRef rotation, int flipH, int flipV,
                            int displayChannel, int out[MAX_PIXELS])
{
    size_t outWidth, outHeight;
    geometry(shape, rotation, &outWidth, &outHeight);
    for (size_t y = 0; y < outHeight; y++)
        for (size_t x = 0; x < outWidth; x++)
            out[y * outWidth + x] = b_value(source_index(shape, rotation, flipH, flipV, outWidth, outHeight,
                                                         (int)x, (int)y));
    return (int)(outWidth * outHeight);
}

// The buffer. `padding` > 0 forces the stride through the PUBLIC mechanism, because there is no public
// CVPixelBufferAttributeKey for a bytes per row - the MacOSX 27 SDK declares twenty of them and
// "BytesPerRow" is not among them - and CVPixelBufferCreate ignores kIOSurfaceBytesPerRow when it
// allocates the surface itself (measured: requested 28, got 64). So the padded stride comes from an
// IOSurface of the caller's own bytes per row wrapped by CVPixelBufferCreateWithIOSurface, and the result
// is ASSERTED: a stride the caller did not get is reported, because every cell that claims a padded row
// would otherwise be a cell measured at 64.
static CVPixelBufferRef make_buffer(const Shape *shape, OSType format, size_t width, size_t height,
                                    size_t padding, int displayChannel, const uint8_t *pattern)
{
    size_t wanted = width * 4 + padding;
    CVPixelBufferRef buffer = NULL;
    if (padding) {
        int values[5] = { (int)width, (int)height, (int)wanted, (int)format, (int)(wanted * height) };
        const void *keys[] = { kIOSurfaceWidth, kIOSurfaceHeight, kIOSurfaceBytesPerRow,
                               kIOSurfacePixelFormat, kIOSurfaceAllocSize };
        const void *vals[5];
        for (int i = 0; i < 5; i++)
            vals[i] = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &values[i]);
        CFDictionaryRef props = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 5,
                                                   &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        for (int i = 0; i < 5; i++) CFRelease(vals[i]);
        IOSurfaceRef surface = IOSurfaceCreate(props);
        CFRelease(props);
        if (!surface) return NULL;
        CVReturn created = CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, NULL, &buffer);
        CFRelease(surface);
        if (created != kCVReturnSuccess || !buffer) return NULL;
    } else if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, NULL, &buffer) != kCVReturnSuccess)
        return NULL;

    CVPixelBufferLockBaseAddress(buffer, 0);
    uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    for (size_t i = 0; i < stride * height; i++)
        base[i] = 0xAB;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++) {
            uint8_t *pixel = base + y * stride + x * 4;
            if (pattern)
                memcpy(pixel, pattern + (y * width + x) * 4, 4);
            else
                pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0xAB;
        }
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    (void)shape;
    (void)displayChannel;
    return buffer;
}

static int measure_refusals(void)
{
    printf("REFUSALS\n");
    uint8_t pattern[4 * 16];
    uint8_t opaque[4 * 16];
    for (int i = 0; i < 16; i++) { pixel_bytes(0, i, pattern + i * 4);
                                 pixel_bytes(0, i, opaque + i * 4); opaque[i * 4 + 3] = 255; }
    Shape threeByFive = { "3x5", 3, 5, 0, NULL, 0 };
    CVPixelBufferRef bgra = make_buffer(&threeByFive, kCVPixelFormatType_32BGRA, 3, 5, 0, 0, pattern);
    CVPixelBufferRef opaqueBGRA = make_buffer(&threeByFive, kCVPixelFormatType_32BGRA, 3, 5, 0, 0, opaque);
    int unexpected = 0;

    // The property is a CFStringRef and the host says so three ways, all with the same code. This is the
    // kVTParameterErr the port answers for a parameter it cannot carry, so the run ASSERTS it: a host that
    // ever answers something else here invalidates the number the port would use.
    {
        VTPixelRotationSessionRef session = NULL;
        VTPixelRotationSessionCreate(kCFAllocatorDefault, &session);
        OSStatus number = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                               (__bridge CFNumberRef)@(90));
        OSStatus flipNumber = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_FlipHorizontalOrientation,
                                                   (__bridge CFNumberRef)@(1));
        OSStatus unknownString = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                                      CFSTR("__kVTRotation_270deg"));
        printf("  rotation=NSNumber(90) %d  flipH=NSNumber(1) %d  rotation=CFSTR(\"__kVTRotation_270deg\") %d"
               "  [kVTParameterErr is %d]\n", (int)number, (int)flipNumber, (int)unknownString,
               (int)kVTParameterErr);
        if (number != kVTParameterErr || flipNumber != kVTParameterErr || unknownString != kVTParameterErr)
            unexpected++;
        CFRelease(session);
    }

    // A destination the session does not take.
    struct { const char *name; OSType format; OSStatus expected; } refusals[] = {
        {"OneComponent8", kCVPixelFormatType_OneComponent8, kVTPixelRotationNotSupportedErr},
        {"444YpCbCr8", kCVPixelFormatType_444YpCbCr8, kVTPixelRotationNotSupportedErr},
        {"420YpCbCr8 biplanar", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, noErr},
    };
    for (unsigned r = 0; r < sizeof(refusals) / sizeof(refusals[0]); r++) {
        VTPixelRotationSessionRef session = NULL;
        VTPixelRotationSessionCreate(kCFAllocatorDefault, &session);
        VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation, kVTRotation_180);
        CVPixelBufferRef destination = make_buffer(&threeByFive, refusals[r].format, 3, 5, 0, 0, NULL);
        OSStatus rotated = destination ? VTPixelRotationSessionRotateImage(session, bgra, destination)
                                       : (OSStatus)-999;
        printf("  destination %-20s rotate=%-7d [kVTPixelRotationNotSupportedErr is %d]", refusals[r].name,
               (int)rotated, (int)kVTPixelRotationNotSupportedErr);
        if (rotated != refusals[r].expected) unexpected++;
        if (rotated == noErr && destination) {
            CVPixelBufferLockBaseAddress(destination, 0);
            const uint8_t *base = (const uint8_t *)CVPixelBufferGetBaseAddress(destination);
            printf("  first row");
            for (size_t x = 0; x < 3; x++) printf(" %3d", base[x * 4]);
            CVPixelBufferUnlockBaseAddress(destination, 0);
        }
        printf("\n");
        if (destination) CVPixelBufferRelease(destination);
        CFRelease(session);
    }

    // A cross-format destination. The host CONVERTS rather than rotates, and what it does for the one
    // pair measured here is an exact swap of red and blue - source B G R A in, destination A R G B out,
    // same numbers, both for an opaque source and for one whose alpha varies. That is a CONVERSION the
    // header does not describe and one pair does not make a rule: the port carries no colour converter,
    // so it answers kVTParameterErr for a pair whose two formats differ, and this line is the measurement
    // that says what the port is not doing.
    {
        CVPixelBufferRef sources[2] = { opaqueBGRA, bgra };
        const char *labels[2] = { "opaque alpha", "varying alpha" };
        for (int v = 0; v < 2; v++) {
            VTPixelRotationSessionRef session = NULL;
            VTPixelRotationSessionCreate(kCFAllocatorDefault, &session);
            VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation, kVTRotation_CW90);
            CVPixelBufferRef destination = make_buffer(&threeByFive, kCVPixelFormatType_32ARGB, 5, 3, 0, 0, NULL);
            OSStatus rotated = destination ? VTPixelRotationSessionRotateImage(session, sources[v], destination)
                                           : (OSStatus)-999;
            printf("  source BGRA %s -> ARGB rotate=%-7d", labels[v], (int)rotated);
            if (rotated == noErr && destination) {
                CVPixelBufferLockBaseAddress(sources[v], 0);
                const uint8_t *sbase = (const uint8_t *)CVPixelBufferGetBaseAddress(sources[v]);
                size_t sstride = CVPixelBufferGetBytesPerRow(sources[v]);
                printf("  source pixel 12 B G R A");
                for (int c = 0; c < 4; c++) printf(" %3d", sbase[4 * sstride + c]);
                CVPixelBufferUnlockBaseAddress(sources[v], 0);
                CVPixelBufferLockBaseAddress(destination, 0);
                const uint8_t *dbase = (const uint8_t *)CVPixelBufferGetBaseAddress(destination);
                printf("  -> destination pixel 0 A R G B");
                for (int c = 0; c < 4; c++) printf(" %3d", dbase[c]);
                CVPixelBufferUnlockBaseAddress(destination, 0);
            } else unexpected++;
            printf("\n");
            if (destination) CVPixelBufferRelease(destination);
            CFRelease(session);
        }
    }

    // A destination geometry VTPixelRotationSession.h:79 forbids: for a quarter turn the destination's
    // width and height must be the inverse of the source's. The host does not refuse - it scale-to-fits
    // and interpolates, which is what put 9 12 18 21 into an earlier probe's output and made a correct
    // rotation look broken.
    {
        VTPixelRotationSessionRef session = NULL;
        VTPixelRotationSessionCreate(kCFAllocatorDefault, &session);
        VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation, kVTRotation_CW90);
        CVPixelBufferRef destination = make_buffer(&threeByFive, kCVPixelFormatType_32BGRA, 3, 5, 0, 0, NULL);
        OSStatus rotated = destination ? VTPixelRotationSessionRotateImage(session, bgra, destination)
                                       : (OSStatus)-999;
        printf("  CW90 into 3x5, not 5x3          rotate=%d", (int)rotated);
        if (rotated == noErr && destination) {
            CVPixelBufferLockBaseAddress(destination, 0);
            const uint8_t *base = (const uint8_t *)CVPixelBufferGetBaseAddress(destination);
            printf("  first row");
            for (size_t x = 0; x < 3; x++) printf(" %3d", base[x * 4]);
            CVPixelBufferUnlockBaseAddress(destination, 0);
        }
        printf("\n");
        if (destination) CVPixelBufferRelease(destination);
        CFRelease(session);
    }

    if (bgra) CVPixelBufferRelease(bgra);
    if (opaqueBGRA) CVPixelBufferRelease(opaqueBGRA);
    return unexpected;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);   /* a run that aborts must still have printed the cell that did it */

    const struct { CFStringRef rotation; const char *name; int flipH, flipV; } OPS[OP_COUNT] = {
        {kVTRotation_0, "0", 0, 0}, {kVTRotation_CW90, "CW90", 0, 0},
        {kVTRotation_180, "180", 0, 0}, {kVTRotation_CCW90, "CCW90", 0, 0},
        {kVTRotation_0, "0", 1, 0}, {kVTRotation_0, "0", 0, 1}, {kVTRotation_0, "0", 1, 1},
        {kVTRotation_CW90, "CW90", 1, 0}, {kVTRotation_CW90, "CW90", 0, 1}, {kVTRotation_CW90, "CW90", 1, 1},
        {kVTRotation_180, "180", 1, 0}, {kVTRotation_180, "180", 0, 1}, {kVTRotation_180, "180", 1, 1},
        {kVTRotation_CCW90, "CCW90", 1, 0}, {kVTRotation_CCW90, "CCW90", 0, 1},
        {kVTRotation_CCW90, "CCW90", 1, 1},
    };

    int cells = 0, differing = 0, rejected = 0, stridesRefused = 0, handChecks = 0, handFailed = 0;

    for (int s = 0; s < SHAPE_COUNT; s++) {
        const Shape *shape = &SHAPES[s];

        // THE HAND-WRITTEN CHECK, for THIS shape, before the host is asked for anything about it.
        int computed180[MAX_PIXELS];
        int computed = expected_display(shape, kVTRotation_180, 0, 0, 0, computed180);
        int agrees = computed == shape->hand180Count;
        for (int i = 0; agrees && i < computed; i++)
            if (computed180[i] != shape->hand180[i]) agrees = 0;
        handChecks++;
        if (!agrees) handFailed++;
        printf("HANDCHECK %-10s %2d values | hand-written", shape->label, shape->hand180Count);
        for (int i = 0; i < shape->hand180Count; i++) printf(" %3d", shape->hand180[i]);
        printf(" | computed");
        for (int i = 0; i < computed; i++) printf(" %3d", computed180[i]);
        printf(" | %s\n", agrees ? "AGREE"
                                 : "DISAGREE - the expectation is wrong before Apple is asked");

        for (unsigned f = 0; f < sizeof(FORMATS) / sizeof(FORMATS[0]); f++) {
            OSType format = FORMATS[f].format;
            int display = FORMATS[f].displayChannel;
            uint8_t pattern[4 * MAX_PIXELS];
            for (int i = 0; i < (int)(shape->width * shape->height); i++)
                pixel_bytes(display, i, pattern + i * 4);

            CVPixelBufferRef source = make_buffer(shape, format, shape->width, shape->height,
                                                  shape->padding, display, pattern);
            if (!source) { printf("no source for %s %s\n", shape->label, FORMATS[f].name); return 1; }
            size_t wanted = shape->width * 4 + shape->padding;
            size_t actual = CVPixelBufferGetBytesPerRow(source);
            int strideForced = shape->padding ? (actual == wanted) : 1;
            if (!strideForced) { stridesRefused++; printf("PADDING NOT FORCED %s %s wanted %zu got %zu\n",
                                                         shape->label, FORMATS[f].name, wanted, actual); }
            if (s == 0 && f == 0) describe("source", source);

            int shapeCells = 0, shapeDiffering = 0, shapeRejected = 0;
            for (int o = 0; o < OP_COUNT; o++) {
                VTPixelRotationSessionRef session = NULL;
                if (VTPixelRotationSessionCreate(kCFAllocatorDefault, &session) != noErr || !session)
                    return 1;

                OSStatus setRotation = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                                             OPS[o].rotation);
                // Read it BACK, so a rejected set is visible as the session's own value rather than
                // inferred from the pixels. This is the check that would have caught fault 1 at once.
                CFTypeRef readBack = NULL;
                OSStatus got = VTSessionCopyProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                                     NULL, &readBack);
                int accepted = (setRotation == noErr && got == noErr && readBack
                                && CFEqual((CFStringRef)readBack, OPS[o].rotation));
                if (!accepted) shapeRejected++;

                if (OPS[o].flipH)
                    VTSessionSetProperty(session, kVTPixelRotationPropertyKey_FlipHorizontalOrientation,
                                         (__bridge CFBooleanRef)@YES);
                if (OPS[o].flipV)
                    VTSessionSetProperty(session, kVTPixelRotationPropertyKey_FlipVerticalOrientation,
                                         (__bridge CFBooleanRef)@YES);

                int want[MAX_PIXELS], gotPixels[MAX_PIXELS];
                int pixels = expected_display(shape, OPS[o].rotation, OPS[o].flipH, OPS[o].flipV,
                                              display, want);
                size_t outWidth, outHeight;
                geometry(shape, OPS[o].rotation, &outWidth, &outHeight);
                if ((int)(outWidth * outHeight) != pixels) {
                    printf("GEOMETRY disagrees with the expectation for %s %s: %zux%zu vs %d pixels\n",
                           shape->label, FORMATS[f].name, outWidth, outHeight, pixels);
                    return 1;
                }
                CVPixelBufferRef destination = make_buffer(shape, format, outWidth, outHeight,
                                                            shape->padding ? shape->padding : 0, display, NULL);
                if (!destination) { printf("no destination for %s %s\n", shape->label, FORMATS[f].name); return 1; }

                OSStatus rotated = VTPixelRotationSessionRotateImage(session, source, destination);
                for (int i = 0; i < MAX_PIXELS; i++) gotPixels[i] = -1;
                size_t destStride = CVPixelBufferGetBytesPerRow(destination);
                size_t destWanted = outWidth * 4 + (shape->padding ? shape->padding : 0);
                int destStrideForced = shape->padding ? (destStride == destWanted) : 1;
                if (!destStrideForced) stridesRefused++;
                int badPixels = 0, badChannels = 0, badPadding = 0;
                if (rotated == noErr) {
                    CVPixelBufferLockBaseAddress(destination, 0);
                    const uint8_t *base = (const uint8_t *)CVPixelBufferGetBaseAddress(destination);
                    for (int i = 0; i < pixels; i++) {
                        int x = i % (int)outWidth, y = i / (int)outWidth;
                        const uint8_t *pixel = base + y * destStride + x * 4;
                        gotPixels[i] = pixel[display];
                        if (gotPixels[i] != want[i]) badPixels++;
                        uint8_t wb[4];
                        pixel_bytes(display, source_index(shape, OPS[o].rotation, OPS[o].flipH, OPS[o].flipV,
                                                          outWidth, outHeight, x, y), wb);
                        for (int c = 0; c < 4; c++) if (pixel[c] != wb[c]) badChannels++;
                    }
                    // The bytes between the end of a row and the start of the next. Indexing them through
                    // the pixel pointer reads past the buffer on the LAST row, so the row is the unit.
                    for (size_t y = 0; y < outHeight; y++)
                        for (size_t k = y * destStride + outWidth * 4; k < (y + 1) * destStride; k++)
                            if (base[k] != 0xAB) { badPadding++; break; }
                    CVPixelBufferUnlockBaseAddress(destination, 0);
                }
                shapeCells++;
                int agree = (rotated == noErr && badPixels == 0 && badChannels == 0
                             && badPadding == 0 && destStrideForced);
                if (!agree) shapeDiffering++;
                if (!agree)
                    printf("DIFF %-10s %-4s %-5s flipH=%d flipV=%d set=%-7d readBack=%d status=%-7d "
                           "%zux%zu stride=%zu/%zu badPixels=%d badChannels=%d badPaddingRows=%d | got",
                           shape->label, FORMATS[f].name, OPS[o].name, OPS[o].flipH, OPS[o].flipV,
                           (int)setRotation, accepted, (int)rotated, outWidth, outHeight,
                           destStride, destWanted, badPixels, badChannels, badPadding);
                if (!agree) {
                    for (int i = 0; i < pixels; i++) printf(" %4d", gotPixels[i]);
                    printf("  | want");
                    for (int i = 0; i < pixels; i++) printf(" %4d", want[i]);
                    printf("\n");
                }
                if (readBack) CFRelease(readBack);
                CVPixelBufferRelease(destination);
                CFRelease(session);
            }
            cells += shapeCells;
            differing += shapeDiffering;
            rejected += shapeRejected;
            // `pixels` is the shape's own pixel count, which is also the length of its hand-written 180.
            // run.sh uses it to say which shapes a quarter-turn plant can reach at all: a shape of one
            // pixel maps onto itself, so swapping CW90 with CCW90 is invisible there by arithmetic, not
            // because the harness missed it.
            // Every field is one space-separated word, so run.sh can read a per-shape tally out of the
            // mutant's own line rather than out of a number typed into the script.
            printf("SIZE %-10s %-4s stride=%zu/%zu pixels=%d cells=%d differing=%d set-rejected=%d\n",
                   shape->label, FORMATS[f].name, actual, wanted, shape->hand180Count,
                   shapeCells, shapeDiffering, shapeRejected);
            CVPixelBufferRelease(source);
        }
    }

    int unexpected = measure_refusals();
    printf("CELLS %d  DIFFERING %d  SET-REJECTED %d  PADDING-REFUSED %d  HANDCHECKS %d  HAND-DISAGREE %d"
           "  REFUSALS-UNEXPECTED %d\n",
           cells, differing, rejected, stridesRefused, handChecks, handFailed, unexpected);
    return (differing == 0 && rejected == 0 && stridesRefused == 0 && handFailed == 0 && unexpected == 0)
           ? 0 : 1;
}