#import <CoreMedia/CoreMedia.h>

#define CharonRatioTimescaleLimit 0x7FFFFFFFu
#define CharonRatioFallbackTimescale 1000000000

typedef struct {
    uint32_t limb[3];
} CharonRatioWide;

static CharonRatioWide charon_ratio_wide(uint64_t magnitude)
{
    CharonRatioWide wide;
    wide.limb[0] = (uint32_t)magnitude;
    wide.limb[1] = (uint32_t)(magnitude >> 32);
    wide.limb[2] = 0;
    return wide;
}

static int charon_ratio_fits(CharonRatioWide wide)
{
    if (wide.limb[2])
        return 0;
    if (wide.limb[1] != 0x7FFFFFFFu)
        return wide.limb[1] < 0x80000000u;
    return wide.limb[0] < 0xFFFFFFFFu;
}

static void charon_ratio_divide_in_place(CharonRatioWide *wide, uint64_t divisor)
{
    uint64_t remainder = 0;
    for (int index = 2; index >= 0; index--) {
        uint64_t current = (remainder << 32) | wide->limb[index];
        wide->limb[index] = (uint32_t)(current / divisor);
        remainder = current % divisor;
    }
}

static uint64_t charon_ratio_low(CharonRatioWide wide)
{
    return ((uint64_t)wide.limb[1] << 32) | wide.limb[0];
}

static int64_t charon_ratio_value(CharonRatioWide wide, int negative)
{
    uint64_t magnitude = charon_ratio_low(wide);
    return negative ? (int64_t)(~magnitude + 1) : (int64_t)magnitude;
}

static void charon_ratio_multiply(CharonRatioWide *wide, uint32_t factor)
{
    uint64_t carry = 0;
    for (int index = 0; index < 3; index++) {
        uint64_t product = (uint64_t)wide->limb[index] * factor + carry;
        wide->limb[index] = (uint32_t)product;
        carry = product >> 32;
    }
}

static void charon_ratio_increment(CharonRatioWide *wide)
{
    for (int index = 0; index < 3; index++) {
        if (wide->limb[index] != 0xFFFFFFFFu) {
            wide->limb[index]++;
            return;
        }
        wide->limb[index] = 0;
    }
}

static void charon_ratio_divide(CharonRatioWide *wide, uint32_t divisor)
{
    uint64_t remainder = 0;
    for (int index = 2; index >= 0; index--) {
        uint64_t current = (remainder << 32) | wide->limb[index];
        wide->limb[index] = (uint32_t)(current / divisor);
        remainder = current % divisor;
    }
}

static uint32_t charon_ratio_remainder(const CharonRatioWide *wide, uint32_t divisor)
{
    uint32_t remainder = 0;
    for (int index = 2; index >= 0; index--) {
        uint64_t current = ((uint64_t)remainder << 32) | wide->limb[index];
        remainder = (uint32_t)(current % divisor);
    }
    return remainder;
}

static int charon_ratio_quotient(CharonRatioWide wide, uint32_t divisor, int negative, int64_t *out)
{
    charon_ratio_divide(&wide, divisor);
    if (2 * (uint64_t)charon_ratio_remainder(&wide, divisor) >= divisor)
        charon_ratio_increment(&wide);
    if (!charon_ratio_fits(wide))
        return 0;
    *out = charon_ratio_value(wide, negative);
    return 1;
}

static void charon_ratio_divide64(CharonRatioWide *wide, uint64_t divisor, uint64_t *quotient, uint64_t *remainder)
{
    uint64_t result = 0, rest = 0;
    for (int index = 95; index >= 0; index--) {
        uint64_t bit = (wide->limb[index / 32] >> (index % 32)) & 1u;
        rest = (rest << 1) | bit;
        result <<= 1;
        if (rest >= divisor) {
            rest -= divisor;
            result |= 1;
        }
    }
    *quotient = result;
    *remainder = rest;
}

static uint64_t charon_ratio_remainder64(CharonRatioWide wide, uint64_t divisor)
{
    uint64_t quotient = 0, remainder = 0;
    charon_ratio_divide64(&wide, divisor, &quotient, &remainder);
    return remainder;
}

static int charon_ratio_scaled(CharonRatioWide wide, int64_t denominator, int negative, int64_t *out)
{
    uint64_t whole = 0, remainder = 0;
    charon_ratio_divide64(&wide, (uint64_t)denominator, &whole, &remainder);
    if (whole > 0x7FFFFFFFFFFFFFFFull / 1000000000ull)
        return 0;
    uint64_t total = whole * 1000000000ull;
    CharonRatioWide fraction = charon_ratio_wide(remainder);
    charon_ratio_multiply(&fraction, 1000000000u);
    uint64_t part = 0, rest = 0;
    charon_ratio_divide64(&fraction, (uint64_t)denominator, &part, &rest);
    if (2 * rest >= (uint64_t)denominator)
        part++;
    if (total > 0x7FFFFFFFFFFFFFFFull - part)
        return 0;
    total += part;
    *out = negative ? -(int64_t)total : (int64_t)total;
    return 1;
}

static uint32_t charon_ratio_gcd(int32_t left, int32_t right)
{
    uint32_t a = (uint32_t)(left < 0 ? -(int64_t)left : left), b = (uint32_t)(right < 0 ? -(int64_t)right : right);
    while (b) {
        uint32_t next = a % b;
        a = b;
        b = next;
    }
    return a;
}

static uint64_t charon_ratio_gcd64(uint64_t left, uint64_t right)
{
    while (right) {
        uint64_t next = left % right;
        left = right;
        right = next;
    }
    return left;
}

// What the host does when the exact numerator is past an int64: it divides numerator and denominator by
// their greatest common divisor until the value fits, and only when that runs out does it fall back on
// truncating the value against the timescale. 4611686018427387904/1073741824 * 3 / 1 is 12884901888/1
// that way, and 9223372036854775807/3 * 1 / 1 is 3074457345618258602/1.
static int charon_ratio_reduce(CharonRatioWide *numerator, int64_t *denominator)
{
    BOOL divided = NO;
    while (!charon_ratio_fits(*numerator) && *denominator > 1) {
        uint64_t common = charon_ratio_gcd64(charon_ratio_remainder64(*numerator, (uint64_t)*denominator), (uint64_t)*denominator);
        if (common < 2)
            break;
        charon_ratio_divide_in_place(numerator, common);
        *denominator /= (int64_t)common;
        divided = YES;
    }
    return divided;
}

static CMTime charon_ratio_time(int64_t value, int32_t timescale, BOOL rounded, CMTimeEpoch epoch)
{
    CMTime result;
    result.value = value;
    result.timescale = timescale;
    result.epoch = epoch;
    result.flags = kCMTimeFlags_Valid | (rounded ? kCMTimeFlags_HasBeenRounded : 0);
    return result;
}

static CMTime charon_ratio_infinite(int negative)
{
    CMTime result;
    result.value = 0;
    result.timescale = 0;
    result.epoch = 0;
    result.flags = kCMTimeFlags_Valid | kCMTimeFlags_HasBeenRounded | (negative ? kCMTimeFlags_NegativeInfinity : kCMTimeFlags_PositiveInfinity);
    return result;
}

CMTime CMTimeMultiplyByRatio(CMTime time, int32_t multiplier, int32_t divisor)
{
    if (!CMTIME_IS_VALID(time))
        return kCMTimeInvalid;
    if (CMTIME_IS_INDEFINITE(time))
        return kCMTimeIndefinite;
    if (CMTIME_IS_POSITIVE_INFINITY(time) || CMTIME_IS_NEGATIVE_INFINITY(time)) {
        if (!multiplier)
            return kCMTimeInvalid;
        BOOL negative = ((multiplier < 0) != (divisor < 0)) != (CMTIME_IS_NEGATIVE_INFINITY(time) != NO);
        return charon_ratio_infinite(negative);
    }
    BOOL rounded = CMTIME_HAS_BEEN_ROUNDED(time);
    if (divisor == 0) {
        if (!multiplier || (!time.value && !time.epoch))
            return kCMTimeInvalid;
        return ((multiplier < 0) != (time.value < 0 && !time.epoch)) ? kCMTimeNegativeInfinity : kCMTimePositiveInfinity;
    }
    if (!time.value || !multiplier)
        return charon_ratio_time(0, time.timescale < 0 ? -time.timescale : time.timescale, rounded, time.epoch);
    int32_t common = (int32_t)charon_ratio_gcd(multiplier, divisor);
    // The pair is reduced and the sign is normalised in 64 bits: a multiplier or a divisor of INT32_MIN
    // cannot be negated in 32, and the host answers 1/1 * -2147483648 / -1 as 2147483648/1.
    int64_t reducedMultiplier = (int64_t)multiplier / common, reducedDivisor = (int64_t)divisor / common;
    if (reducedDivisor < 0) {
        reducedMultiplier = -reducedMultiplier;
        reducedDivisor = -reducedDivisor;
    }
    int negative = (time.value < 0) != (reducedMultiplier < 0);
    uint32_t factor = (uint32_t)(reducedMultiplier < 0 ? -reducedMultiplier : reducedMultiplier);
    CharonRatioWide numerator = charon_ratio_wide(time.value < 0 ? ~(uint64_t)time.value + 1 : (uint64_t)time.value);
    charon_ratio_multiply(&numerator, factor);
    int64_t denominator = (int64_t)time.timescale * reducedDivisor;
    if (denominator < 0) {
        denominator = -denominator;
        negative = !negative;
    }
    if (denominator == 0) {
        // A valid CMTime with a zero timescale: the host multiplies the value through and leaves the
        // timescale at 0, never dividing, so 5/0 * 1 / 3 is 5/0 and 5/0 * -1 / 1 is -5/0.
        if (charon_ratio_fits(numerator))
            return charon_ratio_time(charon_ratio_value(numerator, negative), 0, rounded, time.epoch);
        return charon_ratio_infinite(negative);
    }
    if (charon_ratio_fits(numerator)) {
        int64_t value = charon_ratio_value(numerator, negative);
        if (denominator > 0 && denominator <= CharonRatioTimescaleLimit)
            return charon_ratio_time(value, (int32_t)denominator, rounded, time.epoch);
        int halvings = 0;
        while (denominator > CharonRatioTimescaleLimit && !(denominator & 1)) {
            denominator /= 2;
            halvings++;
        }
        if (denominator > 0 && denominator <= CharonRatioTimescaleLimit) {
            int64_t halved = halvings ? charon_ratio_value(numerator, negative) : value;
            int64_t divisor = halvings ? ((int64_t)1 << halvings) : 1;
            if (halved % divisor == 0)
                return charon_ratio_time(halved / divisor, (int32_t)denominator, rounded, time.epoch);
        }
        int64_t scaled = 0;
        if (charon_ratio_scaled(numerator, denominator, negative, &scaled))
            return charon_ratio_time(scaled, CharonRatioFallbackTimescale, YES, time.epoch);
        return charon_ratio_infinite(negative);
    }
    if (charon_ratio_reduce(&numerator, &denominator) && charon_ratio_fits(numerator) && denominator > 0 && denominator <= CharonRatioTimescaleLimit)
        return charon_ratio_time(charon_ratio_value(numerator, negative), (int32_t)denominator, rounded, time.epoch);
    // Nothing left to reduce: the host truncates the value against the input timescale, multiplies, and
    // answers at timescale 1. 4611686018427387903/1 * 3 / 2 is 6917529027641081855/1 that way.
    int64_t whole = time.value / time.timescale;
    CharonRatioWide product = charon_ratio_wide(whole < 0 ? ~(uint64_t)whole + 1 : (uint64_t)whole);
    charon_ratio_multiply(&product, factor);
    BOOL exact = time.value % time.timescale == 0 && charon_ratio_remainder(&product, (uint32_t)reducedDivisor) == 0 && !product.limb[2];
    int64_t quotient = 0;
    if (charon_ratio_quotient(product, (uint32_t)reducedDivisor, negative, &quotient))
        return charon_ratio_time(quotient, 1, rounded || !exact, time.epoch);
    return charon_ratio_infinite(negative);
}
