// Emoji clusters typeset whole, as CoreText of iOS 9 and later does it.
//
// CoreText of iOS 6.1.3 cuts a text into runs by the coverage of the primary font, so the joiner of a ZWJ sequence, a variation selector or a
// tag lands in another font than the emoji and the `morx` ligatures of AppleColorEmoji never see the whole cluster (revenant_emoji_clusters.h).
// The typesetter creators below find the clusters (UAX #29 rules over the emoji font's own cmap, no list of sequences) and put the emoji font
// over each one in a copy of the attributed string; the caller's string is not touched, nor the characters or their indices: only the font
// attribute of the cluster's range changes. A text without a joiner, a mark, a regional indicator or a keycap is handed to CoreText as it is,
// after a scan that reads the UTF-16 once.
//
// iOS 7 and later do their own clustering and get the system's answer unchanged.

#include "revenant_emoji_clusters.h"
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <pthread.h>

static void *revenant_emoji_core_text(void)
{
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    });
    return handle;
}

static BOOL revenant_emoji_clusters_apply(void)
{
    return NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0;
}

// The emoji font at a size, made once per size. NULL when the device has no AppleColorEmoji (CTFontCreateWithName answers its default font for a
// name it does not know, so the name of the answer is checked).
static pthread_mutex_t revenant_emoji_fonts_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef revenant_emoji_fonts;
static const CGFloat revenant_emoji_reference_size = 17.0;

static CTFontRef revenant_emoji_font_made(CGFloat size)
{
    CTFontRef font = CTFontCreateWithName(CFSTR("AppleColorEmoji"), size, NULL);
    if (font == NULL)
        return NULL;
    CFStringRef name = CTFontCopyPostScriptName(font);
    BOOL emoji = name != NULL && CFStringFind(name, CFSTR("AppleColorEmoji"), 0).location != kCFNotFound;
    if (name)
        CFRelease(name);
    if (!emoji) {
        CFRelease(font);
        return NULL;
    }
    return font;
}

// Retained; NULL when there is no emoji font.
static CTFontRef revenant_emoji_font(CGFloat size)
{
    double keyed = (double)size;
    CFNumberRef key = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &keyed);
    pthread_mutex_lock(&revenant_emoji_fonts_lock);
    if (revenant_emoji_fonts == NULL)
        revenant_emoji_fonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontRef font = (CTFontRef)CFDictionaryGetValue(revenant_emoji_fonts, key);
    if (font)
        CFRetain(font);
    pthread_mutex_unlock(&revenant_emoji_fonts_lock);
    if (font == NULL) {
        font = revenant_emoji_font_made(size);
        if (font) {
            pthread_mutex_lock(&revenant_emoji_fonts_lock);
            if (CFDictionaryGetCount(revenant_emoji_fonts) < 32)
                CFDictionarySetValue(revenant_emoji_fonts, key, font);
            pthread_mutex_unlock(&revenant_emoji_fonts_lock);
        }
    }
    CFRelease(key);
    return font;
}

// The lookup of one text: the emoji font is made when the first code point needs it, not before. Making it maps the font file (+64 MiB of address
// space on the 4S, measured), which a text of Arabic or Indic letters with a joiner must not cost.
typedef struct {
    CTFontRef font;
    BOOL made;
} RevenantEmojiLookup;

// The emoji font's cmap is the Extended_Pictographic of this module: a code point it covers (and a joiner or mark asks about) is a pictographic.
// A letter or a mark of any script is never one (UAX #29 keeps Extended_Pictographic apart from them), so those are answered without the font.
static BOOL revenant_emoji_covers(UTF32Char character, void *context)
{
    static CFCharacterSetRef letters;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        letters = CFCharacterSetGetPredefined(kCFCharacterSetLetter);
    });
    if (CFCharacterSetIsLongCharacterMember(letters, character))
        return NO;
    RevenantEmojiLookup *lookup = (RevenantEmojiLookup *)context;
    if (!lookup->made) {
        lookup->font = revenant_emoji_font(revenant_emoji_reference_size);
        lookup->made = YES;
    }
    CTFontRef font = lookup->font;
    if (font == NULL)
        return NO;
    UniChar units[2];
    CGGlyph glyphs[2] = {0, 0};
    CFIndex count = 1;
    if (character >= 0x10000) {
        units[0] = (UniChar)(0xD800 + ((character - 0x10000) >> 10));
        units[1] = (UniChar)(0xDC00 + ((character - 0x10000) & 0x3FF));
        count = 2;
    } else {
        units[0] = (UniChar)character;
    }
    return CTFontGetGlyphsForCharacters(font, units, glyphs, count) && glyphs[0] != 0;
}

typedef struct {
    CFRange *ranges;
    CFIndex count;
    CFIndex capacity;
    CFRange inline_ranges[8];
} RevenantClusterList;

static void revenant_cluster_list_add(CFRange cluster, void *context)
{
    RevenantClusterList *list = (RevenantClusterList *)context;
    if (list->count == list->capacity) {
        CFIndex capacity = list->capacity * 2;
        CFRange *grown = (CFRange *)malloc(sizeof(CFRange) * (size_t)capacity);
        if (grown == NULL)
            return;
        memcpy(grown, list->ranges, sizeof(CFRange) * (size_t)list->count);
        if (list->ranges != list->inline_ranges)
            free(list->ranges);
        list->ranges = grown;
        list->capacity = capacity;
    }
    list->ranges[list->count++] = cluster;
}

@protocol RevenantPointSized <NSObject>
- (CGFloat)pointSize;
@end

// The size of the font an attribute holds: a CTFont, or a UIFont of iOS 6 (UICFFont, which is not a CTFont and answers pointSize). CoreText's own
// default font is 12 points.
static CGFloat revenant_attribute_font_size(CFTypeRef font)
{
    if (font == NULL)
        return 12.0;
    if (CFGetTypeID(font) == CTFontGetTypeID())
        return CTFontGetSize((CTFontRef)font);
    id<RevenantPointSized> object = (__bridge id<RevenantPointSized>)font;
    if ([object respondsToSelector:@selector(pointSize)])
        return [object pointSize];
    return 12.0;
}

// +1: the attributed string itself when there is nothing to change, else a mutable copy with the emoji font over every cluster.
static CFAttributedStringRef revenant_emoji_clustered(CFAttributedStringRef attributed)
{
    if (attributed == NULL)
        return NULL;
    if (!revenant_emoji_clusters_apply())
        return (CFAttributedStringRef)CFRetain(attributed);
    CFStringRef string = CFAttributedStringGetString(attributed);
    CFIndex length = string ? CFStringGetLength(string) : 0;
    if (length < 2)
        return (CFAttributedStringRef)CFRetain(attributed);

    UniChar stack[256];
    UniChar *owned = NULL;
    const UniChar *chars = CFStringGetCharactersPtr(string);
    // A string CoreFoundation keeps as eight-bit ASCII (every Latin text) has no code unit of a joiner, a mark or a surrogate: nothing to scan, and no copy to widen it.
    if (chars == NULL && CFStringGetCStringPtr(string, kCFStringEncodingASCII) != NULL)
        return (CFAttributedStringRef)CFRetain(attributed);
    if (chars == NULL) {
        UniChar *buffer = stack;
        if (length > 256) {
            owned = (UniChar *)malloc(sizeof(UniChar) * (size_t)length);
            if (owned == NULL)
                return (CFAttributedStringRef)CFRetain(attributed);
            buffer = owned;
        }
        CFStringGetCharacters(string, CFRangeMake(0, length), buffer);
        chars = buffer;
    }
    if (!revenant_text_may_hold_cluster(chars, length)) {
        free(owned);
        return (CFAttributedStringRef)CFRetain(attributed);
    }

    RevenantEmojiLookup lookup = {NULL, NO};
    RevenantClusterList list = {0};
    list.ranges = list.inline_ranges;
    list.capacity = 8;
    revenant_emoji_clusters(chars, length, revenant_emoji_covers, &lookup, revenant_cluster_list_add, &list);
    if (lookup.font)
        CFRelease(lookup.font);
    free(owned);

    CFAttributedStringRef result = NULL;
    if (list.count > 0) {
        CFMutableAttributedStringRef copy = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, attributed);
        if (copy) {
            for (CFIndex index = 0; index < list.count; index++) {
                CFRange cluster = list.ranges[index];
                CGFloat size = revenant_attribute_font_size(CFAttributedStringGetAttribute(attributed, cluster.location, kCTFontAttributeName, NULL));
                CTFontRef emoji = revenant_emoji_font(size);
                if (emoji) {
                    CFAttributedStringSetAttribute(copy, cluster, kCTFontAttributeName, emoji);
                    CFRelease(emoji);
                }
            }
            result = copy;
        }
    }
    if (list.ranges != list.inline_ranges)
        free(list.ranges);
    return result ? result : (CFAttributedStringRef)CFRetain(attributed);
}

CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef string)
{
    static __typeof__(&CTTypesetterCreateWithAttributedString) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTTypesetterCreateWithAttributedString))dlsym(revenant_emoji_core_text(), "CTTypesetterCreateWithAttributedString");
    });
    CFAttributedStringRef clustered = revenant_emoji_clustered(string);
    CTTypesetterRef typesetter = system(clustered);
    if (clustered)
        CFRelease(clustered);
    return typesetter;
}

CTTypesetterRef CTTypesetterCreateWithAttributedStringAndOptions(CFAttributedStringRef string, CFDictionaryRef options)
{
    static __typeof__(&CTTypesetterCreateWithAttributedStringAndOptions) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTTypesetterCreateWithAttributedStringAndOptions))dlsym(revenant_emoji_core_text(), "CTTypesetterCreateWithAttributedStringAndOptions");
    });
    CFAttributedStringRef clustered = revenant_emoji_clustered(string);
    CTTypesetterRef typesetter = system(clustered, options);
    if (clustered)
        CFRelease(clustered);
    return typesetter;
}

CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef string)
{
    static __typeof__(&CTLineCreateWithAttributedString) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTLineCreateWithAttributedString))dlsym(revenant_emoji_core_text(), "CTLineCreateWithAttributedString");
    });
    CFAttributedStringRef clustered = revenant_emoji_clustered(string);
    CTLineRef line = system(clustered);
    if (clustered)
        CFRelease(clustered);
    return line;
}

CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef string)
{
    static __typeof__(&CTFramesetterCreateWithAttributedString) system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (__typeof__(&CTFramesetterCreateWithAttributedString))dlsym(revenant_emoji_core_text(), "CTFramesetterCreateWithAttributedString");
    });
    CFAttributedStringRef clustered = revenant_emoji_clustered(string);
    CTFramesetterRef framesetter = system(clustered);
    if (clustered)
        CFRelease(clustered);
    return framesetter;
}
