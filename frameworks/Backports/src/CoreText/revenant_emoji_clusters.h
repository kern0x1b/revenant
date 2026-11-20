// Emoji clusters of a UTF-16 text: the stretches that must be typeset by the emoji font as one piece.
//
// CoreText of iOS 6.1.3 cuts a text into runs by the coverage of the primary font and then looks for a font per run. A ZWJ sequence
// (U+1F468 U+200D U+1F4BB) is cut at the joiner: U+200D is covered by HelveticaNeue, U+2642 by HiraKakuPro, so the `morx` ligatures of the
// current AppleColorEmoji never see the whole sequence and the family draws as three people. iOS 9 and later, and WebKit, segment by
// extended grapheme clusters (UAX #29, GB9, GB9a, GB11, GB12, GB13) and hand a cluster of emoji to the emoji font whole. This file does the
// segmentation; the typesetter shadows (CTEmojiClusters6.m) put the emoji font over what it finds.
//
// No list of sequences: a cluster is what the rules of UAX #29 make of the code points, with the emoji font's own cmap standing in for
// Extended_Pictographic (the caller passes the lookup), so a sequence the font ligates tomorrow works without a change here.
//
//   cluster      = pictographic Extend* (ZWJ pictographic Extend*)*  |  regional regional  |  keycap-base VS16? U+20E3
//   Extend       = VS15, VS16, an emoji modifier (U+1F3FB..1F3FF), U+20E3, a tag (U+E0020..E007F)
//
// A cluster is reported when the emoji font has something to do with it: a joiner (ZWJ) that joins, VS16, a modifier, a tag, the keycap
// mark, or a pair of regional indicators. A lone pictographic, or one followed by VS15 only, is left to the cascade as before.
//
// Static inline so that the host test compiles it without the library.

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

// The code points that make a cluster the emoji font's business.
static inline BOOL revenant_is_emoji_mark(UTF32Char c)
{
    return c == REVENANT_VS16 || c == REVENANT_KEYCAP || revenant_is_emoji_modifier(c) || revenant_is_tag(c);
}

// Extend of UAX #29 in the emoji context (VS15 extends and asks for the text style: it does not make the cluster an emoji one).
static inline BOOL revenant_is_cluster_extend(UTF32Char c)
{
    return c == REVENANT_VS15 || revenant_is_emoji_mark(c);
}

// A code point the emoji font covers can still not start or follow a joiner as a pictographic: the marks, the joiner itself and the regional
// indicators are covered by the emoji font too.
static inline BOOL revenant_can_be_pictographic(UTF32Char c)
{
    return c > 0x7F && c != REVENANT_ZWJ && !revenant_is_cluster_extend(c) && !revenant_is_regional(c);
}

// The cheap test every typeset text takes first: a text with none of these code units holds no cluster to force. 0xD83C is the high
// surrogate of the regional indicators and the modifiers, 0xDB40 of the tags.
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

// Calls `found` for every cluster of chars[0 ..< length] that the emoji font must typeset whole, in order, and answers how many. The
// lookup `pictographic` is asked about a code point only next to a code point that could join or extend it, so a text without emoji marks
// never reaches it.
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
