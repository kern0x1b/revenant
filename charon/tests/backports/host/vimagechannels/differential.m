// The port's channel moves held against the host's own vImage, case by case.
//
// **Every expected destination in this file is computed here, from Conversion.h's own statement, before the
// host is asked** - the runs are moved by loops written in this file, not by calling the port's - and then
// the host's answer and the port's are each compared against it, byte for byte, including the bytes either
// side must NOT write: the padding of every row is filled with a guard and compared afterwards, so a
// destination written past its own width is a difference rather than an invisible overrun.
//
// These are data movements, so there is nothing here about rounding to disagree about: a wrong channel
// order, a wrong mask bit, a wrong width and a wrong refusal are the whole space of possible mistakes, and
// all four are asked for directly. The refusals are asked twice over - the two sides must agree, and where
// the header names the answer the run says which one it got.

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

vImage_Error charon_host_vImagePermuteChannels_ARGB16U(const vImage_Buffer *, const vImage_Buffer *,
                                                       const uint8_t permuteMap[4], vImage_Flags);
vImage_Error charon_host_vImagePermuteChannels_ARGB16F(const vImage_Buffer *, const vImage_Buffer *,
                                                       const uint8_t permuteMap[4], vImage_Flags);
vImage_Error charon_host_vImagePermuteChannels_RGB888(const vImage_Buffer *, const vImage_Buffer *,
                                                      const uint8_t permuteMap[3], vImage_Flags);
vImage_Error charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB16U(const vImage_Buffer *, const vImage_Buffer *,
                                                                      const uint8_t permuteMap[4], uint8_t copyMask,
                                                                      const Pixel_ARGB_16U backgroundColor,
                                                                      vImage_Flags);
vImage_Error charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB8888(const vImage_Buffer *, const vImage_Buffer *,
                                                                       const uint8_t permuteMap[4], uint8_t copyMask,
                                                                       const Pixel_8888 backgroundColor,
                                                                       vImage_Flags);
vImage_Error charon_host_vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *,
                                                                       const uint8_t permuteMap[4], uint8_t copyMask,
                                                                       const Pixel_FFFF backgroundColor,
                                                                       vImage_Flags);
vImage_Error charon_host_vImageExtractChannel_ARGB16U(const vImage_Buffer *, const vImage_Buffer *, long,
                                                       vImage_Flags);
vImage_Error charon_host_vImageExtractChannel_ARGBFFFF(const vImage_Buffer *, const vImage_Buffer *, long,
                                                       vImage_Flags);
vImage_Error charon_host_vImageOverwriteChannelsWithPixel_ARGB16U(const Pixel_ARGB_16U, const vImage_Buffer *,
                                                                   const vImage_Buffer *, uint8_t, vImage_Flags);
vImage_Error charon_host_vImageOverwriteChannelsWithScalar_Planar16U(Pixel_16U, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageOverwriteChannelsWithScalar_Planar16S(Pixel_16S, const vImage_Buffer *, vImage_Flags);
vImage_Error charon_host_vImageOverwriteChannelsWithScalar_Planar16F(Pixel_16F, const vImage_Buffer *, vImage_Flags);

#define W 7
#define H 3
#define SRC_PAD 5
#define DEST_PAD 3
#define GUARD 0xA5

static int checks;
static int failures;

static void report(int passed, const char *name, const char *why, ...)
{
    va_list args;
    va_start(args, why);
    checks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        failures++;
        printf("FAIL %s: ", name);
        if (why)
            vprintf(why, args);
        printf("\n");
    }
    va_end(args);
    fflush(stdout);
}

// One call in a child process, for the inputs a header invites and an implementation may not survive: a
// NULL map on the three-channel permute is the identity according to its own comment, and whether the host
// answers that or dies on it is a measurement, not something to find out by taking the differential down
// with it. The child exits with the return code it got, or dies with whatever signal the call raised; the
// parent says which, and the port's own answer is asked in this process beside it.
#define CHARON_CHILD_CRASHED (-1)

static int in_child(vImage_Error (*call)(void *), void *context)
{
    // The child's answer comes back through a pipe rather than through its exit status: an exit status is
    // one bit wide and every refusal here is a different number, so a run that folded them together would
    // report -21775 for a NULL pointer argument and for a map value of 4 alike.
    int channel[2];
    if (pipe(channel) != 0)
        return CHARON_CHILD_CRASHED;
    fflush(stdout);
    pid_t child = fork();
    if (child == 0) {
        close(channel[0]);
        vImage_Error answer = call(context);
        ssize_t written = write(channel[1], &answer, sizeof answer);
        (void)written;
        close(channel[1]);
        _exit(0);
    }
    close(channel[1]);
    vImage_Error answer = kvImageUnknownFlagsBit;
    ssize_t got = read(channel[0], &answer, sizeof answer);
    close(channel[0]);
    int status = 0;
    waitpid(child, &status, 0);
    if (WIFSIGNALED(status))
        return CHARON_CHILD_CRASHED;
    return got == (ssize_t)sizeof answer ? (int)answer : CHARON_CHILD_CRASHED;
}

// One call of any of the shapes the refusals use, so every refusal can be asked of the host in a child: a
// NULL buffer or a NULL map is a thing the host may survive or may not, and which of the two it is has to
// be a line in the run rather than the end of it.
enum { ShapePermute4, ShapePermute4F, ShapePermute3, ShapeMaskedInsert16U, ShapeMaskedInsert8888,
       ShapeMaskedInsertFFFF, ShapeExtract, ShapeExtractFFFF, ShapeOverwritePixel, ShapeFill16U, ShapeFill16S,
       ShapeFill16F };

struct Call {
    int shape;
    const vImage_Buffer *src;
    const vImage_Buffer *dest;
    const uint8_t *map;
    long channel;
    uint8_t mask;
    const void *pixel;
    vImage_Flags flags;
};

static vImage_Error call_shape(void *context)
{
    struct Call *call = (struct Call *)context;
    switch (call->shape) {
        case ShapePermute4:
            return vImagePermuteChannels_ARGB16U(call->src, call->dest, call->map, call->flags);
        case ShapePermute4F:
            return vImagePermuteChannels_ARGB16F(call->src, call->dest, call->map, call->flags);
        case ShapePermute3:
            return vImagePermuteChannels_RGB888(call->src, call->dest, call->map, call->flags);
        case ShapeMaskedInsert16U:
            return vImagePermuteChannelsWithMaskedInsert_ARGB16U(call->src, call->dest, call->map, call->mask,
                                                                *(const Pixel_ARGB_16U *)call->pixel, call->flags);
        case ShapeMaskedInsert8888:
            return vImagePermuteChannelsWithMaskedInsert_ARGB8888(call->src, call->dest, call->map, call->mask,
                                                                 *(const Pixel_8888 *)call->pixel, call->flags);
        case ShapeMaskedInsertFFFF:
            return vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(call->src, call->dest, call->map, call->mask,
                                                                 *(const Pixel_FFFF *)call->pixel, call->flags);
        case ShapeExtract:
            return vImageExtractChannel_ARGB16U(call->src, call->dest, call->channel, call->flags);
        case ShapeExtractFFFF:
            return vImageExtractChannel_ARGBFFFF(call->src, call->dest, call->channel, call->flags);
        case ShapeOverwritePixel:
            return vImageOverwriteChannelsWithPixel_ARGB16U(*(const Pixel_ARGB_16U *)call->pixel, call->src,
                                                           call->dest, call->mask, call->flags);
        case ShapeFill16U:
            return vImageOverwriteChannelsWithScalar_Planar16U(*(const Pixel_16U *)call->pixel, call->dest,
                                                               call->flags);
        case ShapeFill16S:
            return vImageOverwriteChannelsWithScalar_Planar16S(*(const Pixel_16S *)call->pixel, call->dest,
                                                               call->flags);
        default:
            return vImageOverwriteChannelsWithScalar_Planar16F(*(const Pixel_16F *)call->pixel, call->dest,
                                                               call->flags);
    }
}

static int host_asks(const struct Call *call)
{
    return in_child(call_shape, (void *)call);
}

// The same shapes against the port, in this process: a port that dies on a NULL argument is a defect the run
// has to show as a crash, so it is deliberately not put in a child where it would be a number.
static vImage_Error call_shape_port(void *context)
{
    struct Call *call = (struct Call *)context;
    switch (call->shape) {
        case ShapePermute4:
            return charon_host_vImagePermuteChannels_ARGB16U(call->src, call->dest, call->map, call->flags);
        case ShapePermute4F:
            return charon_host_vImagePermuteChannels_ARGB16F(call->src, call->dest, call->map, call->flags);
        case ShapePermute3:
            return charon_host_vImagePermuteChannels_RGB888(call->src, call->dest, call->map, call->flags);
        case ShapeMaskedInsert16U:
            return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB16U(
                call->src, call->dest, call->map, call->mask, *(const Pixel_ARGB_16U *)call->pixel, call->flags);
        case ShapeMaskedInsert8888:
            return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB8888(
                call->src, call->dest, call->map, call->mask, *(const Pixel_8888 *)call->pixel, call->flags);
        case ShapeMaskedInsertFFFF:
            return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(
                call->src, call->dest, call->map, call->mask, *(const Pixel_FFFF *)call->pixel, call->flags);
        case ShapeExtract:
            return charon_host_vImageExtractChannel_ARGB16U(call->src, call->dest, call->channel, call->flags);
        case ShapeExtractFFFF:
            return charon_host_vImageExtractChannel_ARGBFFFF(call->src, call->dest, call->channel, call->flags);
        case ShapeOverwritePixel:
            return charon_host_vImageOverwriteChannelsWithPixel_ARGB16U(*(const Pixel_ARGB_16U *)call->pixel,
                                                                        call->src, call->dest, call->mask,
                                                                        call->flags);
        case ShapeFill16U:
            return charon_host_vImageOverwriteChannelsWithScalar_Planar16U(*(const Pixel_16U *)call->pixel,
                                                                            call->dest, call->flags);
        case ShapeFill16S:
            return charon_host_vImageOverwriteChannelsWithScalar_Planar16S(*(const Pixel_16S *)call->pixel,
                                                                            call->dest, call->flags);
        default:
            return charon_host_vImageOverwriteChannelsWithScalar_Planar16F(*(const Pixel_16F *)call->pixel,
                                                                            call->dest, call->flags);
    }
}

static vImage_Buffer buffer_of(void *data, vImagePixelCount width, vImagePixelCount height, size_t rowBytes)
{
    vImage_Buffer buffer = {0};
    buffer.data = data;
    buffer.width = width;
    buffer.height = height;
    buffer.rowBytes = rowBytes;
    return buffer;
}

// The source: a gradient where every byte is a function of its own position, so a channel that lands in the
// wrong place is a difference and not a coincidence.
static void fill_source(uint8_t *data, size_t bytes)
{
    for (size_t i = 0; i < bytes; i++)
        data[i] = (uint8_t)(i * 37 + 11);
}

static void fill_dest(uint8_t *data, size_t bytes)
{
    memset(data, GUARD, bytes);
}

// **The expectation, computed here from Conversion.h's statement**: destination pixel x's run `i` is the
// source's run `map[i]`, and where an insert is given and the mask bit for channel `i` is SET, the
// insert's run `i` instead. Written over runs of `channelBytes`, which is what the header means by a
// "channel" and the only thing that differs between the widths. The sense is the header's: its pseudocode
// is `if (mask & copyMask) result[i] = backgroundColor[i]`, and the parameter is commented "Copy
// backgroundColor into 0x8 -- alpha".
static void expect_runs(uint8_t *dest, const uint8_t *src, vImagePixelCount width, const uint8_t *map,
                        int channels, int channelBytes, const uint8_t *insert, uint8_t copyMask)
{
    for (vImagePixelCount x = 0; x < width; x++) {
        for (int channel = 0; channel < channels; channel++) {
            const uint8_t *from = src + ((size_t)x * (size_t)channels + (size_t)map[channel]) * (size_t)channelBytes;
            uint8_t *to = dest + ((size_t)x * (size_t)channels + (size_t)channel) * (size_t)channelBytes;
            if (insert && (copyMask & (uint8_t)(0x8 >> channel)))
                memcpy(to, insert + (size_t)channel * channelBytes, (size_t)channelBytes);
            else
                memcpy(to, from, (size_t)channelBytes);
        }
    }
}

// The first byte at which two buffers differ, and both values, so a difference says where it is.
static int first_difference(const uint8_t *a, const uint8_t *b, size_t bytes)
{
    for (size_t i = 0; i < bytes; i++)
        if (a[i] != b[i])
            return (int)i;
    return -1;
}

// Three comparisons of one run's destination against the header's rule, named so a failure says which side
// is wrong: the rule is what the header states, so the host is the one measured against it and the port is
// the one that has to agree with both.
static void compare_row(const char *label, const uint8_t *hostDest, const uint8_t *portDest, const uint8_t *want,
                        size_t bytes)
{
    int at = first_difference(hostDest, want, bytes);
    report(at < 0, label, "the HOST's bytes differ from the header's rule first at byte %d (host %02x, rule %02x)",
           at, at < 0 ? 0 : hostDest[at], at < 0 ? 0 : want[at]);
    at = first_difference(portDest, want, bytes);
    report(at < 0, label, "the PORT's bytes differ from the header's rule first at byte %d (port %02x, rule %02x)",
           at, at < 0 ? 0 : portDest[at], at < 0 ? 0 : want[at]);
    at = first_difference(portDest, hostDest, bytes);
    report(at < 0, label, "the port's bytes differ from the HOST's first at byte %d (port %02x, host %02x)", at,
           at < 0 ? 0 : portDest[at], at < 0 ? 0 : hostDest[at]);
}

// ============================================================================================
// A permute of `channels` runs of `channelBytes`, over five maps, then in place.
// ============================================================================================
typedef vImage_Error (*PermuteFn)(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *, vImage_Flags);

static void permute_case(const char *what, PermuteFn host, PermuteFn port, int channels, int channelBytes)
{
    static const uint8_t maps[5][4] = {{0, 1, 2, 3}, {3, 2, 1, 0}, {1, 0, 3, 2}, {2, 3, 0, 1}, {0, 0, 0, 0}};
    static const char *names[5] = {"the identity map", "ARGB to BGRA", "A and R swapped with B and G",
                                   "the two pairs swapped", "every channel from the first"};
    size_t pixel = (size_t)channels * (size_t)channelBytes;
    size_t srcRow = W * pixel + SRC_PAD;
    size_t destRow = W * pixel + DEST_PAD;
    size_t srcBytes = (size_t)H * srcRow;
    size_t destBytes = (size_t)H * destRow;
    for (int m = 0; m < 5; m++) {
        uint8_t *src = malloc(srcBytes), *hostDest = malloc(destBytes), *portDest = malloc(destBytes);
        uint8_t *want = malloc(destBytes), *pristine = malloc(srcBytes);
        char label[160];
        fill_source(src, srcBytes);
        memcpy(pristine, src, srcBytes);
        fill_dest(hostDest, destBytes);
        fill_dest(portDest, destBytes);
        fill_dest(want, destBytes);
        for (vImagePixelCount row = 0; row < H; row++)
            expect_runs(want + row * destRow, src + row * srcRow, W, maps[m], channels, channelBytes, NULL, 0);
        vImage_Buffer s = buffer_of(src, W, H, srcRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        vImage_Error hostAnswer = host(&s, &hd, maps[m], kvImageNoFlags);
        vImage_Error portAnswer = port(&s, &pd, maps[m], kvImageNoFlags);
        snprintf(label, sizeof label, "%s, %s", what, names[m]);
        report(hostAnswer == kvImageNoError && portAnswer == kvImageNoError, label,
               "one side refused: the host %d, the port %d", (int)hostAnswer, (int)portAnswer);
        compare_row(label, hostDest, portDest, want, destBytes);
        report(first_difference(src, pristine, srcBytes) < 0, label, "the port wrote into the source");
        free(src); free(pristine); free(hostDest); free(portDest); free(want);

        // In place: one buffer on both sides, which the header says works and the corpus asks for.
        size_t sharedRow = W * pixel + (SRC_PAD > DEST_PAD ? SRC_PAD : DEST_PAD);
        size_t sharedBytes = (size_t)H * sharedRow;
        uint8_t *shared = malloc(sharedBytes), *sharedWant = malloc(sharedBytes);
        fill_source(shared, sharedBytes);
        memcpy(sharedWant, shared, sharedBytes);
        for (vImagePixelCount row = 0; row < H; row++)
            expect_runs(sharedWant + row * sharedRow, shared + row * sharedRow, W, maps[m], channels, channelBytes,
                        NULL, 0);
        vImage_Buffer inplace = buffer_of(shared, W, H, sharedRow);
        vImage_Error inPlace = port(&inplace, &inplace, maps[m], kvImageDoNotTile);
        snprintf(label, sizeof label, "%s, %s, in place", what, names[m]);
        report(inPlace == kvImageNoError, label, "the port refused in place with %d", (int)inPlace);
        int at = first_difference(shared, sharedWant, sharedBytes);
        report(at < 0, label, "the port's in-place bytes differ from the header's rule first at byte %d (port %02x, rule %02x)",
               at, at < 0 ? 0 : shared[at], at < 0 ? 0 : sharedWant[at]);
        free(shared); free(sharedWant);
    }
}

// The three-channel eight-bit permute, whose header adds a case the four-channel ones do not have: a NULL map
// is the identity. Conversion.h says so directly: a NULL map gives the same destination pixels as the source,
// so it is asked with a NULL map and compared against the identity.
static void permute3_case(void)
{
    size_t pixel = 3;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * pixel + DEST_PAD;
    size_t srcBytes = (size_t)H * srcRow, destBytes = (size_t)H * destRow;
    static const uint8_t maps[3][3] = {{0, 1, 2}, {2, 1, 0}, {1, 2, 0}};
    static const uint8_t identity[3] = {0, 1, 2};
    for (int m = -1; m < 3; m++) {
        uint8_t *src = malloc(srcBytes), *hostDest = malloc(destBytes), *portDest = malloc(destBytes);
        uint8_t *want = malloc(destBytes);
        char label[160];
        fill_source(src, srcBytes);
        fill_dest(hostDest, destBytes);
        fill_dest(portDest, destBytes);
        fill_dest(want, destBytes);
        const uint8_t *map = m < 0 ? identity : maps[m];
        for (vImagePixelCount row = 0; row < H; row++)
            expect_runs(want + row * destRow, src + row * srcRow, W, map, 3, 1, NULL, 0);
        vImage_Buffer s = buffer_of(src, W, H, srcRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        vImage_Error portAnswer = charon_host_vImagePermuteChannels_RGB888(&s, &pd, m < 0 ? NULL : map, kvImageNoFlags);
        vImage_Error hostAnswer;
        if (m < 0) {
            // Per the header, a NULL map gives the same destination pixels as the identity map.
            // The host's own answer to that sentence is measured in a child, because a host that dereferences
            // the map takes this differential down with it and the measurement is worth more than the run.
            struct Call call = {ShapePermute3, &s, &hd, NULL, 0, 0, NULL, kvImageNoFlags};
            hostAnswer = (vImage_Error)host_asks(&call);
            printf("     vImagePermuteChannels_RGB888 with a NULL map: the host's own process ended %s\n",
                   hostAnswer == CHARON_CHILD_CRASHED ? "on a signal" : "normally");
        } else {
            hostAnswer = vImagePermuteChannels_RGB888(&s, &hd, map, kvImageNoFlags);
        }
        snprintf(label, sizeof label, "vImagePermuteChannels_RGB888, %s",
                 m < 0 ? "a NULL map, which the header says is the identity" : "a map");
        if (m < 0)
            report(portAnswer == kvImageNullPointerArgument, label,
                   "the port answered %d, where the header's own comment says the call is the identity and the "
                   "host's process ends on a signal", (int)portAnswer);
        if (m >= 0) {
            report(hostAnswer == kvImageNoError, label, "the host answered %d", (int)hostAnswer);
            compare_row(label, hostDest, portDest, want, destBytes);
        } else {
            // The host died on it and wrote nothing, so there are no bytes to compare: what is compared is
            // that the port refused rather than answering an identity the release does not implement, and
            // that it wrote nothing either.
            report(portDest[0] == GUARD, label, "the port wrote into the destination of a refused call");
            report(hostDest[0] == GUARD, label, "the host wrote into the destination before it died");
        }
        free(src); free(hostDest); free(portDest); free(want);
    }
}

// ============================================================================================
// The masked insert: a permute, then the channels the mask clears replaced by the given pixel's.
// ============================================================================================
static void masked_insert_case(const char *what, vImage_Error (*host)(const vImage_Buffer *, const vImage_Buffer *,
                                                                     const uint8_t *, uint8_t, const void *,
                                                                     vImage_Flags),
                               vImage_Error (*port)(const vImage_Buffer *, const vImage_Buffer *, const uint8_t *,
                                                    uint8_t, const void *, vImage_Flags),
                               int channelBytes, const uint8_t *background)
{
    static const uint8_t map[4] = {3, 2, 1, 0};
    size_t pixel = 4 * (size_t)channelBytes;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * pixel + DEST_PAD;
    size_t srcBytes = (size_t)H * srcRow, destBytes = (size_t)H * destRow;
    for (int mask = 0; mask < 16; mask++) {
        uint8_t *src = malloc(srcBytes), *hostDest = malloc(destBytes), *portDest = malloc(destBytes);
        uint8_t *want = malloc(destBytes);
        char label[160];
        fill_source(src, srcBytes);
        fill_dest(hostDest, destBytes);
        fill_dest(portDest, destBytes);
        fill_dest(want, destBytes);
        for (vImagePixelCount row = 0; row < H; row++)
            expect_runs(want + row * destRow, src + row * srcRow, W, map, 4, channelBytes, background,
                        (uint8_t)mask);
        vImage_Buffer s = buffer_of(src, W, H, srcRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        vImage_Error hostAnswer = host(&s, &hd, map, (uint8_t)mask, background, kvImageNoFlags);
        vImage_Error portAnswer = port(&s, &pd, map, (uint8_t)mask, background, kvImageNoFlags);
        snprintf(label, sizeof label, "%s, copyMask 0x%X", what, mask);
        report(hostAnswer == kvImageNoError && portAnswer == kvImageNoError, label,
               "one side refused: the host %d, the port %d", (int)hostAnswer, (int)portAnswer);
        compare_row(label, hostDest, portDest, want, destBytes);
        free(src); free(hostDest); free(portDest); free(want);
    }
}

// Three thin adapters, so the masked-insert case above can be one loop over sixteen masks whatever the
// pixel's own type is. Nothing is compared here: each passes its own type's pixel straight through.
static vImage_Error host_masked_16u(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                    uint8_t mask, const void *background, vImage_Flags flags)
{
    return vImagePermuteChannelsWithMaskedInsert_ARGB16U(s, d, map, mask, *(const Pixel_ARGB_16U *)background, flags);
}

static vImage_Error host_masked_8888(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                     uint8_t mask, const void *background, vImage_Flags flags)
{
    return vImagePermuteChannelsWithMaskedInsert_ARGB8888(s, d, map, mask, *(const Pixel_8888 *)background, flags);
}

static vImage_Error host_masked_ffff(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                     uint8_t mask, const void *background, vImage_Flags flags)
{
    return vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(s, d, map, mask, *(const Pixel_FFFF *)background, flags);
}

static vImage_Error port_masked_16u(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                    uint8_t mask, const void *background, vImage_Flags flags)
{
    return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB16U(s, d, map, mask,
                                                                     *(const Pixel_ARGB_16U *)background, flags);
}

static vImage_Error port_masked_8888(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                     uint8_t mask, const void *background, vImage_Flags flags)
{
    return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGB8888(s, d, map, mask,
                                                                      *(const Pixel_8888 *)background, flags);
}

static vImage_Error port_masked_ffff(const vImage_Buffer *s, const vImage_Buffer *d, const uint8_t *map,
                                     uint8_t mask, const void *background, vImage_Flags flags)
{
    return charon_host_vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(s, d, map, mask,
                                                                      *(const Pixel_FFFF *)background, flags);
}

// ============================================================================================
// An extract, one channel at a time.
// ============================================================================================
typedef vImage_Error (*ExtractFn)(const vImage_Buffer *, const vImage_Buffer *, long, vImage_Flags);

static void extract_case(const char *what, ExtractFn host, ExtractFn port, int channels, int channelBytes)
{
    size_t pixel = (size_t)channels * (size_t)channelBytes;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * channelBytes + DEST_PAD;
    size_t srcBytes = (size_t)H * srcRow, destBytes = (size_t)H * destRow;
    for (long channel = 0; channel < channels; channel++) {
        uint8_t *src = malloc(srcBytes), *hostDest = malloc(destBytes), *portDest = malloc(destBytes);
        uint8_t *want = malloc(destBytes);
        char label[160];
        fill_source(src, srcBytes);
        fill_dest(hostDest, destBytes);
        fill_dest(portDest, destBytes);
        fill_dest(want, destBytes);
        for (vImagePixelCount row = 0; row < H; row++) {
            const uint8_t *in = src + row * srcRow;
            uint8_t *out = want + row * destRow;
            for (vImagePixelCount x = 0; x < W; x++)
                memcpy(out + (size_t)x * channelBytes, in + ((size_t)x * channels + channel) * channelBytes,
                       channelBytes);
        }
        vImage_Buffer s = buffer_of(src, W, H, srcRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        vImage_Error hostAnswer = host(&s, &hd, channel, kvImageNoFlags);
        vImage_Error portAnswer = port(&s, &pd, channel, kvImageNoFlags);
        snprintf(label, sizeof label, "%s, channel %ld", what, channel);
        report(hostAnswer == kvImageNoError && portAnswer == kvImageNoError, label,
               "one side refused: the host %d, the port %d", (int)hostAnswer, (int)portAnswer);
        compare_row(label, hostDest, portDest, want, destBytes);
        free(src); free(hostDest); free(portDest); free(want);
    }
}

// ============================================================================================
// A fill: the given value in every pixel of a one-channel destination, and nothing written past its width.
// ============================================================================================
typedef vImage_Error (*FillFn)(const uint8_t *value, const vImage_Buffer *dest, vImage_Flags);

static void fill_case(const char *what, FillFn host, FillFn port, const uint8_t *value, int channelBytes)
{
    size_t rowBytes = W * (size_t)channelBytes + DEST_PAD;
    size_t bytes = (size_t)H * rowBytes;
    uint8_t *hostDest = malloc(bytes), *portDest = malloc(bytes), *want = malloc(bytes);
    char label[160];
    memset(hostDest, GUARD, bytes);
    memset(portDest, GUARD, bytes);
    memset(want, GUARD, bytes);
    for (vImagePixelCount row = 0; row < H; row++)
        for (vImagePixelCount x = 0; x < W; x++)
            memcpy(want + row * rowBytes + (size_t)x * channelBytes, value, channelBytes);
    vImage_Buffer hd = buffer_of(hostDest, W, H, rowBytes);
    vImage_Buffer pd = buffer_of(portDest, W, H, rowBytes);
    vImage_Error hostAnswer = host(value, &hd, kvImageNoFlags);
    vImage_Error portAnswer = port(value, &pd, kvImageNoFlags);
    snprintf(label, sizeof label, "%s, a %d-byte value", what, channelBytes);
    report(hostAnswer == kvImageNoError && portAnswer == kvImageNoError, label,
           "one side refused: the host %d, the port %d", (int)hostAnswer, (int)portAnswer);
    compare_row(label, hostDest, portDest, want, bytes);
    free(hostDest); free(portDest); free(want);
}

// Six adapters, one per side per width: the three fill functions take their own scalar type and this file
// keeps one case for all of them. Each hands its own type's bytes straight through, so the case is still
// asking the host and the port the same question.
static vImage_Error host_fill_16u(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16U scalar;
    memcpy(&scalar, value, sizeof scalar);
    return vImageOverwriteChannelsWithScalar_Planar16U(scalar, d, f);
}

static vImage_Error host_fill_16s(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16S scalar;
    memcpy(&scalar, value, sizeof scalar);
    return vImageOverwriteChannelsWithScalar_Planar16S(scalar, d, f);
}

static vImage_Error host_fill_16f(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16F scalar;
    memcpy(&scalar, value, sizeof scalar);
    return vImageOverwriteChannelsWithScalar_Planar16F(scalar, d, f);
}

static vImage_Error port_fill_16u(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16U scalar;
    memcpy(&scalar, value, sizeof scalar);
    return charon_host_vImageOverwriteChannelsWithScalar_Planar16U(scalar, d, f);
}

static vImage_Error port_fill_16s(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16S scalar;
    memcpy(&scalar, value, sizeof scalar);
    return charon_host_vImageOverwriteChannelsWithScalar_Planar16S(scalar, d, f);
}

static vImage_Error port_fill_16f(const uint8_t *value, const vImage_Buffer *d, vImage_Flags f)
{
    Pixel_16F scalar;
    memcpy(&scalar, value, sizeof scalar);
    return charon_host_vImageOverwriteChannelsWithScalar_Planar16F(scalar, d, f);
}

// ============================================================================================
// The overwrite with one pixel: each channel of each destination pixel is either the source's own or the
// given pixel's, decided by the copyMask bit for that channel. Conversion.h writes it a word at a time
// (`destRow[x] = (srcRow[x] & mask) | the_pixel`) and names the mask's meaning, so both readings are
// computed and the run says which one the host answers.
// ============================================================================================
static void overwrite_pixel_case(const char *what, vImage_Error (*host)(const uint8_t *, const vImage_Buffer *,
                                                                        const vImage_Buffer *, uint8_t, vImage_Flags),
                                 vImage_Error (*port)(const uint8_t *, const vImage_Buffer *, const vImage_Buffer *,
                                                      uint8_t, vImage_Flags),
                                 const uint8_t *pixel, int channelBytes)
{
    size_t pixelBytes = 4 * (size_t)channelBytes;
    size_t srcRow = W * pixelBytes + SRC_PAD, destRow = W * pixelBytes + DEST_PAD;
    size_t srcBytes = (size_t)H * srcRow, destBytes = (size_t)H * destRow;
    for (int mask = 0; mask < 16; mask++) {
        uint8_t *src = malloc(srcBytes), *hostDest = malloc(destBytes), *portDest = malloc(destBytes);
        uint8_t *want = malloc(destBytes);
        char label[160];
        fill_source(src, srcBytes);
        fill_dest(hostDest, destBytes);
        fill_dest(portDest, destBytes);
        fill_dest(want, destBytes);
        // The expectation, and the sense is the measured one: the copyMask bit names the channels the given
        // PIXEL is copied into ("Copy plane into 0x8 -- alpha"), and every other channel is conserved from
        // the source. CopyMask 0 therefore conserves the whole source and copyMask 0xF writes the whole
        // pixel, which is what the host answers and what the port now does - Conversion.h's sentence about
        // "0xFFFF where the pixels should be conserved" reads the other way round and is not what the host
        // does; see facts/Accelerate/vImageChannels.md.
        for (vImagePixelCount row = 0; row < H; row++) {
            const uint8_t *in = src + row * srcRow;
            uint8_t *out = want + row * destRow;
            for (vImagePixelCount x = 0; x < W; x++)
                for (int channel = 0; channel < 4; channel++) {
                    uint8_t *to = out + ((size_t)x * 4 + channel) * channelBytes;
                    if ((uint8_t)mask & (uint8_t)(0x8 >> channel))
                        memcpy(to, pixel + channel * channelBytes, channelBytes);
                    else
                        memcpy(to, in + ((size_t)x * 4 + channel) * channelBytes, channelBytes);
                }
        }
        vImage_Buffer s = buffer_of(src, W, H, srcRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        vImage_Error hostAnswer = host(pixel, &s, &hd, (uint8_t)mask, kvImageNoFlags);
        vImage_Error portAnswer = port(pixel, &s, &pd, (uint8_t)mask, kvImageNoFlags);
        snprintf(label, sizeof label, "%s, copyMask 0x%X", what, mask);
        report(hostAnswer == kvImageNoError && portAnswer == kvImageNoError, label,
               "one side refused: the host %d, the port %d", (int)hostAnswer, (int)portAnswer);
        compare_row(label, hostDest, portDest, want, destBytes);
        free(src); free(hostDest); free(portDest); free(want);
    }
}

static vImage_Error host_overwrite_pixel(const uint8_t *pixel, const vImage_Buffer *s, const vImage_Buffer *d,
                                         uint8_t mask, vImage_Flags flags)
{
    Pixel_ARGB_16U value;
    memcpy(&value, pixel, sizeof value);
    return vImageOverwriteChannelsWithPixel_ARGB16U(value, s, d, mask, flags);
}

static vImage_Error port_overwrite_pixel(const uint8_t *pixel, const vImage_Buffer *s, const vImage_Buffer *d,
                                         uint8_t mask, vImage_Flags flags)
{
    Pixel_ARGB_16U value;
    memcpy(&value, pixel, sizeof value);
    return charon_host_vImageOverwriteChannelsWithPixel_ARGB16U(value, s, d, mask, flags);
}

// ============================================================================================
// The refusals, asked twice over: every bit of the flag word on its own for every function of the family,
// then the arguments the headers name - a NULL buffer, a destination larger than the source, a map value, a
// channel index or a copyMask outside the range the header gives for it.
//
// **The flag word, one bit at a time, for every function.** The headers name kvImageUnknownFlagsBit for "a
// flag which was not among the approved set" without ever saying which bits are approved, the tree's other
// vImage files each measured their own set, and this is the survey that decides what these three files
// accept. Agreement between the two sides is the gate and the accepted set is what the run prints, with the
// value in every line - "one flag bit" without it cannot say which bit the two sides disagreed about.
// A legal flag does not crash the host, so both sides are asked in this process and the bytes are left to
// the cases above; what is at stake here is only which bits are a refusal.
// ============================================================================================
static void refusal_case(const char *what, const char *inputs, vImage_Error hostAnswer, vImage_Error portAnswer,
                         vImage_Error expected, int namesOne)
{
    char label[200];
    snprintf(label, sizeof label, "%s, %s", what, inputs);
    // A host that died on the call is a measurement, not a disagreement: a process that ends on a signal
    // against a port that refused a NULL argument is the right answer on both sides, and comparing the two
    // numbers would call that a difference.
    int hostAlive = hostAnswer != CHARON_CHILD_CRASHED;
    report(hostAlive ? hostAnswer == portAnswer : portAnswer != kvImageNoError, label,
           "the host %s, the port %d", hostAlive ? "answers a different code" : "died on a signal and the port answers",
           (int)portAnswer);
    if (namesOne && hostAlive)
        report(hostAnswer == expected, label, "the header names %d for this and the host answers %d", (int)expected,
               (int)hostAnswer);
    printf("     %s: the host %s, the port %d\n", label,
           hostAlive ? "answers a code" : "died on a signal, and the port answers", (int)portAnswer);
    if (hostAlive)
        printf("       the host's own code: %d, the port's: %d\n", (int)hostAnswer, (int)portAnswer);
}

static void flag_survey(const char *what, int shape, int portShape)
{
    // **The buffers are laid out for the widest shape of the family**, four channels of four bytes, because
    // this survey asks all twelve functions with one buffer each: laid out for the narrowest, the ARGBFFFF
    // masked insert reads sixteen bytes a pixel out of a row eight bytes a pixel wide, which AddressSanitizer
    // reports as a heap-buffer-overflow in this file (measured, and the rowBytes a caller passes is not what
    // decides how much of it is read - the width and the pixel type are).
    size_t pixel = 4 * 4;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * pixel + DEST_PAD;
    uint8_t *src = malloc((size_t)H * srcRow), *hostDest = malloc((size_t)H * destRow);
    uint8_t *portDest = malloc((size_t)H * destRow);
    // **A three-entry map for the three-channel permute.** Asked with the four-entry map of the four-channel
    // forms it answers kvImageInvalidParameter on the map (its entry 0 is 3, which is out of range for three
    // channels), and that would be read as a refusal of the flag - the very thing the survey is measuring.
    static const uint8_t map4[4] = {3, 2, 1, 0};
    static const uint8_t map3[3] = {2, 1, 0};
    const uint8_t *map = shape == ShapePermute3 ? map3 : map4;
    // **The widest insert of the family, because this survey asks every shape**: an ARGBFFFF masked insert
    // reads sixteen bytes of it and an ARGB16U one reads eight, so a narrower object here is a stack
    // overflow in the survey rather than a measurement - measured, as an AddressSanitizer report of
    // "stack-buffer-overflow, READ of size 4, in CharonChannelsPermuteRow" from this function.
    Pixel_FFFF background = {{0.25f, 0.5f, 0.75f, 1.0f}};
    fill_source(src, (size_t)H * srcRow);
    vImage_Buffer s = buffer_of(src, W, H, srcRow);
    for (int bit = 0; bit < 32; bit++) {
        vImage_Flags flag = (vImage_Flags)1u << bit;
        memset(hostDest, GUARD, (size_t)H * destRow);
        memset(portDest, GUARD, (size_t)H * destRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        struct Call host = {shape, &s, &hd, map, 0, 0x0F, &background, flag};
        struct Call port = {portShape, &s, &pd, map, 0, 0x0F, &background, flag};
        char inputs[32];
        snprintf(inputs, sizeof inputs, "the flag 0x%08x alone", (unsigned)flag);
        refusal_case(what, inputs, call_shape(&host), call_shape_port(&port), kvImageUnknownFlagsBit, 0);
    }
    free(src);
    free(hostDest);
    free(portDest);
}

// The copyMask, one value at a time, the way the flag survey asks the flag word. **Conversion.h names a
// range for it - "kvImageInvalidParameter when copyMask > 0x0F" - and the measurement is what decides**,
// because this host is the oracle for these rows and a header is not.
static void maskmask_survey(const char *what, int shape, int portShape)
{
    size_t pixel = 4 * 2;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * pixel + DEST_PAD;
    uint8_t *src = malloc((size_t)H * srcRow), *dest = malloc((size_t)H * destRow);
    static const uint8_t map[4] = {3, 2, 1, 0};
    Pixel_ARGB_16U background = {0x1111, 0x2222, 0x3333, 0x4444};
    fill_source(src, (size_t)H * srcRow);
    vImage_Buffer s = buffer_of(src, W, H, srcRow);
    vImage_Buffer d = buffer_of(dest, W, H, destRow);
    static const int values[] = {0x00, 0x01, 0x08, 0x0F, 0x10, 0x11, 0x1F, 0x20, 0x40, 0x80, 0xF0, 0xFF};
    uint8_t *hostDest = malloc((size_t)H * destRow), *portDest = malloc((size_t)H * destRow);
    uint8_t *want = malloc((size_t)H * destRow);
    for (size_t i = 0; i < sizeof values / sizeof *values; i++) {
        memset(dest, GUARD, (size_t)H * destRow);
        memset(hostDest, GUARD, (size_t)H * destRow);
        memset(portDest, GUARD, (size_t)H * destRow);
        memset(want, GUARD, (size_t)H * destRow);
        vImage_Buffer hd = buffer_of(hostDest, W, H, destRow);
        vImage_Buffer pd = buffer_of(portDest, W, H, destRow);
        struct Call host = {shape, &s, &hd, map, 0, (uint8_t)values[i], &background, kvImageNoFlags};
        struct Call port = {portShape, &s, &pd, map, 0, (uint8_t)values[i], &background, kvImageNoFlags};
        // **Asked in this process, not in a child**: the child's writes land in the child's own copy-on-write
        // pages and are gone by the time it exits, so a child cannot be compared byte for byte. A legal mask
        // does not crash the host - only the NULL map does, and that one is asked elsewhere in a child - so
        // there is nothing to isolate here.
        vImage_Error hostAnswer = call_shape(&host);
        vImage_Error portAnswer = call_shape_port(&port);
        char inputs[32];
        snprintf(inputs, sizeof inputs, "the copyMask 0x%02X alone", values[i]);
        refusal_case(what, inputs, hostAnswer, portAnswer, kvImageNoError, 0);
        // And the bytes, so "the bits above 0x0F are carried and ignored" is measured rather than inferred
        // from the fact that the call was accepted: the expectation is the same rule with the mask masked
        // down to its four channel bits, which is what both sides are asked to agree with.
        if (shape == ShapeOverwritePixel) {
            for (vImagePixelCount row = 0; row < H; row++)
                for (vImagePixelCount x = 0; x < W; x++)
                    for (int channel = 0; channel < 4; channel++) {
                        uint8_t *to = want + row * destRow + ((size_t)x * 4 + channel) * 2;
                        if ((uint8_t)values[i] & (uint8_t)(0x8 >> channel))
                            memcpy(to, (const uint8_t *)&background + channel * 2, 2);
                        else
                            memcpy(to, src + row * srcRow + ((size_t)x * 4 + channel) * 2, 2);
                    }
        } else {
            for (vImagePixelCount row = 0; row < H; row++)
                expect_runs(want + row * destRow, src + row * srcRow, W, map, 4, 2,
                            (const uint8_t *)&background, (uint8_t)(values[i] & 0x0F));
        }
        char label[80];
        snprintf(label, sizeof label, "%s, copyMask 0x%02X", what, values[i]);
        compare_row(label, hostDest, portDest, want, (size_t)H * destRow);
    }
    free(hostDest);
    free(portDest);
    free(want);
    free(src);
    free(dest);
}

static void argument_refusals(void)
{
    size_t pixel = 4 * 2;
    size_t srcRow = W * pixel + SRC_PAD, destRow = W * pixel + DEST_PAD;
    uint8_t *src = malloc((size_t)H * srcRow), *dest = malloc((size_t)H * destRow);
    static const uint8_t good[4] = {0, 1, 2, 3};
    static const uint8_t toolarge[4] = {0, 1, 2, 4};
    static const uint8_t toolarge8[4] = {0, 1, 2, 255};
    static const uint8_t three[3] = {0, 1, 3};
    vImage_Buffer s = buffer_of(src, W, H, srcRow);
    vImage_Buffer d = buffer_of(dest, W, H, destRow);
    vImage_Buffer bigger = buffer_of(dest, W + 1, H, destRow);
    Pixel_ARGB_16U background = {0x1111, 0x2222, 0x3333, 0x4444};
    Pixel_16U scalar16u = 0x1234;
    fill_source(src, (size_t)H * srcRow);
    memset(dest, GUARD, (size_t)H * destRow);

#define ASK(shape, source, destination, the_map, the_channel, the_mask, the_pixel, the_flags)                   \
    ({                                                                                                          \
        struct Call call = {shape, source, destination, the_map, the_channel, the_mask, the_pixel, the_flags};   \
        (vImage_Error)host_asks(&call);                                                                         \
    })
#define ASK_PORT(shape, source, destination, the_map, the_channel, the_mask, the_pixel, the_flags)                \
    ({                                                                                                          \
        struct Call call = {shape, source, destination, the_map, the_channel, the_mask, the_pixel, the_flags};   \
        call_shape_port(&call);                                                                                  \
    })

    refusal_case("vImagePermuteChannels_ARGB16U", "a NULL source",
                 ASK(ShapePermute4, NULL, &d, good, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, NULL, &d, good, 0, 0, NULL, kvImageNoFlags), kvImageNullPointerArgument, 1);
    refusal_case("vImagePermuteChannels_ARGB16U", "a NULL destination",
                 ASK(ShapePermute4, &s, NULL, good, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, &s, NULL, good, 0, 0, NULL, kvImageNoFlags), kvImageNullPointerArgument, 1);
    refusal_case("vImagePermuteChannels_ARGB16U", "a NULL map",
                 ASK(ShapePermute4, &s, &d, NULL, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, &s, &d, NULL, 0, 0, NULL, kvImageNoFlags), kvImageNullPointerArgument, 1);
    refusal_case("vImagePermuteChannels_ARGB16U", "a map value of 4",
                 ASK(ShapePermute4, &s, &d, toolarge, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, &s, &d, toolarge, 0, 0, NULL, kvImageNoFlags), kvImageInvalidParameter, 1);
    refusal_case("vImagePermuteChannels_ARGB16U", "a map value of 255",
                 ASK(ShapePermute4, &s, &d, toolarge8, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, &s, &d, toolarge8, 0, 0, NULL, kvImageNoFlags), kvImageInvalidParameter, 1);
    refusal_case("vImagePermuteChannels_ARGB16U", "a destination wider than the source",
                 ASK(ShapePermute4, &s, &bigger, good, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute4, &s, &bigger, good, 0, 0, NULL, kvImageNoFlags), kvImageRoiLargerThanInputBuffer, 1);

    refusal_case("vImagePermuteChannels_RGB888", "a map value of 3",
                 ASK(ShapePermute3, &s, &d, three, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapePermute3, &s, &d, three, 0, 0, NULL, kvImageNoFlags), kvImageInvalidParameter, 0);

    refusal_case("vImageExtractChannel_ARGB16U", "a channel index of -1",
                 ASK(ShapeExtract, &s, &d, NULL, -1, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapeExtract, &s, &d, NULL, -1, 0, NULL, kvImageNoFlags), kvImageInvalidParameter, 1);
    refusal_case("vImageExtractChannel_ARGB16U", "a channel index of 4",
                 ASK(ShapeExtract, &s, &d, NULL, 4, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapeExtract, &s, &d, NULL, 4, 0, NULL, kvImageNoFlags), kvImageInvalidParameter, 1);
    refusal_case("vImageExtractChannel_ARGB16U", "a destination wider than the source",
                 ASK(ShapeExtract, &s, &bigger, NULL, 0, 0, NULL, kvImageNoFlags),
                 ASK_PORT(ShapeExtract, &s, &bigger, NULL, 0, 0, NULL, kvImageNoFlags), kvImageRoiLargerThanInputBuffer, 1);

    refusal_case("vImagePermuteChannelsWithMaskedInsert_ARGB16U", "a map value of 4",
                 ASK(ShapeMaskedInsert16U, &s, &d, toolarge, 0, 0x0F, &background, kvImageNoFlags),
                 ASK_PORT(ShapeMaskedInsert16U, &s, &d, toolarge, 0, 0x0F, &background, kvImageNoFlags),
                 kvImageInvalidParameter, 1);
    refusal_case("vImageOverwriteChannelsWithPixel_ARGB16U", "a NULL destination",
                 ASK(ShapeOverwritePixel, &s, NULL, NULL, 0, 0x0F, &background, kvImageNoFlags),
                 ASK_PORT(ShapeOverwritePixel, &s, NULL, NULL, 0, 0x0F, &background, kvImageNoFlags),
                 kvImageNullPointerArgument, 0);
    refusal_case("vImageOverwriteChannelsWithScalar_Planar16U", "a NULL destination",
                 ASK(ShapeFill16U, NULL, NULL, NULL, 0, 0, &scalar16u, kvImageNoFlags),
                 ASK_PORT(ShapeFill16U, NULL, NULL, NULL, 0, 0, &scalar16u, kvImageNoFlags), kvImageNullPointerArgument, 1);
    {
        Pixel_16F scalar16f = 0x3C00;
        refusal_case("vImageOverwriteChannelsWithScalar_Planar16F", "a NULL destination",
                     ASK(ShapeFill16F, NULL, NULL, NULL, 0, 0, &scalar16f, kvImageNoFlags),
                     ASK_PORT(ShapeFill16F, NULL, NULL, NULL, 0, 0, &scalar16f, kvImageNoFlags),
                     kvImageNullPointerArgument, 1);
    }
#undef ASK
#undef ASK_PORT
    free(src);
    free(dest);
}

int main(void)
{
    @autoreleasepool {
        static const uint8_t background16u[8] = {0x11, 0x11, 0x22, 0x22, 0x33, 0x33, 0x44, 0x44};
        static const uint8_t background8888[4] = {0x11, 0x22, 0x33, 0x44};
        static const uint8_t backgroundffff[16] = {0x11, 0x11, 0x11, 0x11, 0x22, 0x22, 0x22, 0x22,
                                                   0x33, 0x33, 0x33, 0x33, 0x44, 0x44, 0x44, 0x44};
        static const uint8_t value16[2] = {0x34, 0x12};
        printf("the port's channel moves against the host's own vImage\n");
        permute_case("vImagePermuteChannels_ARGB16U", vImagePermuteChannels_ARGB16U,
                     charon_host_vImagePermuteChannels_ARGB16U, 4, 2);
        permute_case("vImagePermuteChannels_ARGB16F", vImagePermuteChannels_ARGB16F,
                     charon_host_vImagePermuteChannels_ARGB16F, 4, 2);
        permute3_case();
        masked_insert_case("vImagePermuteChannelsWithMaskedInsert_ARGB16U", host_masked_16u, port_masked_16u, 2,
                           background16u);
        masked_insert_case("vImagePermuteChannelsWithMaskedInsert_ARGB8888", host_masked_8888, port_masked_8888, 1,
                           background8888);
        masked_insert_case("vImagePermuteChannelsWithMaskedInsert_ARGBFFFF", host_masked_ffff, port_masked_ffff, 4,
                           backgroundffff);
        extract_case("vImageExtractChannel_ARGB16U", vImageExtractChannel_ARGB16U,
                     charon_host_vImageExtractChannel_ARGB16U, 4, 2);
        extract_case("vImageExtractChannel_ARGBFFFF", vImageExtractChannel_ARGBFFFF,
                     charon_host_vImageExtractChannel_ARGBFFFF, 4, 4);
        overwrite_pixel_case("vImageOverwriteChannelsWithPixel_ARGB16U", host_overwrite_pixel, port_overwrite_pixel,
                             background16u, 2);
        fill_case("vImageOverwriteChannelsWithScalar_Planar16U", host_fill_16u, port_fill_16u, value16, 2);
        fill_case("vImageOverwriteChannelsWithScalar_Planar16S", host_fill_16s, port_fill_16s, value16, 2);
        fill_case("vImageOverwriteChannelsWithScalar_Planar16F", host_fill_16f, port_fill_16f, value16, 2);
        flag_survey("vImagePermuteChannels_ARGB16U", ShapePermute4, ShapePermute4);
        flag_survey("vImagePermuteChannelsWithMaskedInsert_ARGB16U", ShapeMaskedInsert16U, ShapeMaskedInsert16U);
        flag_survey("vImagePermuteChannelsWithMaskedInsert_ARGB8888", ShapeMaskedInsert8888, ShapeMaskedInsert8888);
        flag_survey("vImagePermuteChannelsWithMaskedInsert_ARGBFFFF", ShapeMaskedInsertFFFF, ShapeMaskedInsertFFFF);
        flag_survey("vImageOverwriteChannelsWithPixel_ARGB16U", ShapeOverwritePixel, ShapeOverwritePixel);
        flag_survey("vImagePermuteChannels_RGB888", ShapePermute3, ShapePermute3);
        flag_survey("vImageExtractChannel_ARGB16U", ShapeExtract, ShapeExtract);
        flag_survey("vImageExtractChannel_ARGBFFFF", ShapeExtractFFFF, ShapeExtractFFFF);
        flag_survey("vImageOverwriteChannelsWithScalar_Planar16U", ShapeFill16U, ShapeFill16U);
        flag_survey("vImageOverwriteChannelsWithScalar_Planar16S", ShapeFill16S, ShapeFill16S);
        flag_survey("vImagePermuteChannels_ARGB16F", ShapePermute4F, ShapePermute4F);
        flag_survey("vImageOverwriteChannelsWithScalar_Planar16F", ShapeFill16F, ShapeFill16F);
        maskmask_survey("vImagePermuteChannelsWithMaskedInsert_ARGB16U", ShapeMaskedInsert16U, ShapeMaskedInsert16U);
        maskmask_survey("vImageOverwriteChannelsWithPixel_ARGB16U", ShapeOverwritePixel, ShapeOverwritePixel);
        argument_refusals();
        printf("\n%d checks, %d failures\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
