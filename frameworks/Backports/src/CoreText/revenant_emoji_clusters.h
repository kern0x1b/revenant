#import <CoreFoundation/CoreFoundation.h>
#import <objc/objc.h>

#define REVENANT_ZWJ 0x200D
#define REVENANT_VS15 0xFE0E
#define REVENANT_VS16 0xFE0F
#define REVENANT_KEYCAP 0x20E3

typedef BOOL (*RevenantPictographicFunction)(UTF32Char character, void *context);
typedef void (*RevenantClusterFunction)(CFRange cluster, void *context);

static inline UTF32Char revenant_code_point_at(const UniChar *chars, CFIndex length, CFIndex at, CFIndex *width)
{
    UniChar high = chars[at];
    if (high >= 0xD800 && high < 0xDC00 && at + 1 < length && chars[at + 1] >= 0xDC00 && chars[at + 1] < 0xE000) {
        *width = 2;
        return 0x10000 + (((UTF32Char)high - 0xD800) << 10) + (UTF32Char)(chars[at + 1] - 0xDC00);
    }
    *width = 1;
    return high;
}

static inline BOOL revenant_is_emoji_modifier(UTF32Char c) { return c >= 0x1F3FB && c <= 0x1F3FF; }
static inline BOOL revenant_is_tag(UTF32Char c) { return c >= 0xE0020 && c <= 0xE007F; }
static inline BOOL revenant_is_regional(UTF32Char c) { return c >= 0x1F1E6 && c <= 0x1F1FF; }
static inline BOOL revenant_is_keycap_base(UTF32Char c) { return (c >= '0' && c <= '9') || c == '#' || c == '*'; }

static inline BOOL revenant_is_emoji_mark(UTF32Char c)
{
    return c == REVENANT_VS16 || c == REVENANT_KEYCAP || revenant_is_emoji_modifier(c) || revenant_is_tag(c);
}

static inline BOOL revenant_is_cluster_extend(UTF32Char c)
{
    return c == REVENANT_VS15 || revenant_is_emoji_mark(c);
}

static inline BOOL revenant_can_be_pictographic(UTF32Char c)
{
    return c > 0x7F && c != REVENANT_ZWJ && !revenant_is_cluster_extend(c) && !revenant_is_regional(c);
}

static inline BOOL revenant_text_may_hold_cluster(const UniChar *chars, CFIndex length)
{
    for (CFIndex at = 0; at < length; at++) {
        UniChar unit = chars[at];
        if (unit < REVENANT_ZWJ)
            continue;
        if (unit == REVENANT_ZWJ || unit == REVENANT_VS16 || unit == REVENANT_KEYCAP || unit == 0xD83C || unit == 0xDB40)
            return YES;
    }
    return NO;
}

static inline CFIndex revenant_emoji_clusters(const UniChar *chars, CFIndex length, RevenantPictographicFunction pictographic, void *lookup,
                                              RevenantClusterFunction found, void *target)
{
    if (!revenant_text_may_hold_cluster(chars, length))
        return 0;
    CFIndex count = 0;
    CFIndex at = 0;
    while (at < length) {
        CFIndex width = 1;
        UTF32Char c = revenant_code_point_at(chars, length, at, &width);
        CFIndex next = at + width;

        if (revenant_is_regional(c)) {
            CFIndex second_width = 1;
            if (next < length && revenant_is_regional(revenant_code_point_at(chars, length, next, &second_width))) {
                found(CFRangeMake(at, width + second_width), target);
                count++;
                at = next + second_width;
            } else {
                at = next;
            }
            continue;
        }

        if (revenant_is_keycap_base(c)) {
            CFIndex end = next;
            if (end < length && chars[end] == REVENANT_VS16)
                end++;
            if (end < length && chars[end] == REVENANT_KEYCAP) {
                found(CFRangeMake(at, end + 1 - at), target);
                count++;
                at = end + 1;
            } else {
                at = next;
            }
            continue;
        }

        CFIndex next_width = 1;
        BOOL joins = revenant_can_be_pictographic(c) && next < length;
        UTF32Char following = 0;
        if (joins) {
            following = revenant_code_point_at(chars, length, next, &next_width);
            joins = following == REVENANT_ZWJ || revenant_is_cluster_extend(following);
        }
        if (!joins || !pictographic(c, lookup)) {
            at = next;
            continue;
        }

        CFIndex end = next;
        BOOL force = NO;
        for (;;) {
            while (end < length) {
                CFIndex extend_width = 1;
                UTF32Char extend = revenant_code_point_at(chars, length, end, &extend_width);
                if (!revenant_is_cluster_extend(extend))
                    break;
                if (extend != REVENANT_VS15)
                    force = YES;
                end += extend_width;
            }
            if (end >= length || chars[end] != REVENANT_ZWJ || end + 1 >= length)
                break;
            CFIndex joined_width = 1;
            UTF32Char joined = revenant_code_point_at(chars, length, end + 1, &joined_width);
            if (!revenant_can_be_pictographic(joined) || !pictographic(joined, lookup))
                break;
            force = YES;
            end += 1 + joined_width;
        }
        if (force) {
            found(CFRangeMake(at, end - at), target);
            count++;
        }
        at = end;
    }
    return count;
}
