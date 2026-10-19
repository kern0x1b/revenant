#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#include <math.h>

CMTime CharonHostCMTimeMultiplyByRatio(CMTime time, int32_t multiplier, int32_t divisor);

static int identical, cornerSame, cornerWithinTolerance, cornerLost, different;

static NSString *shown(CMTime time)
{
    if (!CMTIME_IS_VALID(time))
        return @"invalid";
    if (CMTIME_IS_POSITIVE_INFINITY(time))
        return CMTIME_HAS_BEEN_ROUNDED(time) ? @"+infinity rounded" : @"+infinity";
    if (CMTIME_IS_NEGATIVE_INFINITY(time))
        return CMTIME_HAS_BEEN_ROUNDED(time) ? @"-infinity rounded" : @"-infinity";
    if (CMTIME_IS_INDEFINITE(time))
        return @"indefinite";
    return [NSString stringWithFormat:@"%lld/%d e%d%s", time.value, time.timescale, time.epoch, CMTIME_HAS_BEEN_ROUNDED(time) ? " rounded" : ""];
}

// The port's claim (registry/CoreMedia/ios7.json, facts/CoreMedia/CMTimeMultiplyByRatio.md): where a
// CMTime holds the exact rational, the answer is that rational. Outside that region Apple's own
// implementation truncates the value against the timescale before it multiplies, so the two are
// compared there only against the exact value, and how far apart they are is measured and printed.
static int representable(int64_t value, int32_t timescale, int32_t multiplier, int32_t divisor)
{
    if (divisor == 0)
        return 1;
    if (value == 0)
        return 1;
    if (timescale <= 0)
        return 0;
    uint32_t left = (uint32_t)(multiplier < 0 ? -(int64_t)multiplier : multiplier);
    uint32_t right = (uint32_t)(divisor < 0 ? -(int64_t)divisor : divisor);
    uint32_t walk = left, common = right;
    while (common) {
        uint32_t next = walk % common;
        walk = common;
        common = next;
    }
    left /= walk;
    right /= walk;
    // The product is formed in 128 bits, the width the claim is about: the implementation builds it in
    // 96 and this must not ask a question in 64.
    __int128 product = (__int128)(value < 0 ? -(__int128)value : (__int128)value) * (__int128)left;
    int64_t denominator = (int64_t)timescale * (int64_t)right;
    return product <= (__int128)0x7FFFFFFFFFFFFFFELL && denominator > 0 && denominator <= 0x7FFFFFFFu;
}

static double exact_seconds(int64_t value, int32_t timescale, int32_t multiplier, int32_t divisor)
{
    return (double)value * (double)multiplier / ((double)timescale * (double)divisor);
}

static void compare(CMTime time, int32_t multiplier, int32_t divisor)
{
    CMTime system = CMTimeMultiplyByRatio(time, multiplier, divisor);
    CMTime port = CharonHostCMTimeMultiplyByRatio(time, multiplier, divisor);
    if ([shown(system) isEqualToString:shown(port)]) {
        identical++;
        return;
    }
    if (representable(time.value, time.timescale, multiplier, divisor)) {
        different++;
        if (different < 30)
            printf("DIFFERENT inside the claim, %s * %d / %d:\n  system %s\n  port   %s\n",
                   shown(time).UTF8String, multiplier, divisor, shown(system).UTF8String, shown(port).UTF8String);
        return;
    }
    cornerSame++;
    double want = exact_seconds(time.value, time.timescale, multiplier, divisor);
    if (CMTIME_IS_NUMERIC(system) && CMTIME_IS_NUMERIC(port) &&
        fabs(CMTimeGetSeconds(system) - want) <= 1e-6 * (1 + fabs(want)) &&
        fabs(CMTimeGetSeconds(port) - want) <= 1e-6 * (1 + fabs(want)))
        cornerWithinTolerance++;
    else
        cornerLost++;
}

int main(void)
{
    @autoreleasepool {
        static const int64_t values[] = {0, 1, -1, 2, -2, 3, -3, 5, 7, -7, 10, 100, 1000, 48000, -48000, 1000000007LL,
                                         -1000000007LL, 2147483647LL, -2147483648LL, 4294967296LL, 600000000000LL, 123456789012345LL,
                                         1000000000000000000LL, -1000000000000000000LL, 1152921504606846976LL, 2305843009213693952LL,
                                         4611686018427387904LL, -4611686018427387904LL, 9223372036854775806LL, -9223372036854775806LL,
                                         9223372036854775807LL, -9223372036854775807LL - 1};
        static const int32_t scales[] = {0, 1, -1, 2, -2, 3, 4, 5, 6, 7, 10, 24, 25, 30, 48, 60, 100, 300, 441, 480, 600,
                                         1000, -1000, 30000, 44100, 48000, 90000, 100000000, -48000, 1000000000, 1073741824, 2147483647};
        static const int32_t factors[] = {0, 1, -1, 2, -2, 3, -3, 4, 5, 6, 7, -7, 8, -8, 10, -10, 16, -16, 20, -20, 100, 1000, 65536,
                                         30000, 44100, -44100, 1000000000, 2147483647, -2147483647 - 1};
        for (size_t v = 0; v < sizeof values / sizeof *values; v++)
            for (size_t s = 0; s < sizeof scales / sizeof *scales; s++)
                for (size_t m = 0; m < sizeof factors / sizeof *factors; m++)
                    for (size_t d = 0; d < sizeof factors / sizeof *factors; d++) {
                        CMTime time = {values[v], scales[s], kCMTimeFlags_Valid, 0};
                        compare(time, factors[m], factors[d]);
                    }
        for (size_t v = 0; v < sizeof values / sizeof *values; v++)
            for (size_t s = 0; s < sizeof scales / sizeof *scales; s++) {
                CMTime rounded = {values[v], scales[s], kCMTimeFlags_Valid | kCMTimeFlags_HasBeenRounded, 0};
                CMTime epoch = {values[v], scales[s], kCMTimeFlags_Valid, 3};
                for (size_t m = 0; m < sizeof factors / sizeof *factors; m++)
                    for (size_t d = 0; d < sizeof factors / sizeof *factors; d++) {
                        compare(rounded, factors[m], factors[d]);
                        compare(epoch, factors[m], factors[d]);
                    }
            }
        for (size_t m = 0; m < sizeof factors / sizeof *factors; m++)
            for (size_t d = 0; d < sizeof factors / sizeof *factors; d++) {
                compare(kCMTimeInvalid, factors[m], factors[d]);
                compare(kCMTimePositiveInfinity, factors[m], factors[d]);
                compare(kCMTimeNegativeInfinity, factors[m], factors[d]);
                compare(kCMTimeIndefinite, factors[m], factors[d]);
                compare(kCMTimeZero, factors[m], factors[d]);
            }
        printf("%d the same, %d different inside the claim, %d outside it of which %d agree with the exact value and %d do not\n",
               identical, different, cornerSame, cornerWithinTolerance, cornerLost);
    }
    return different != 0;
}
