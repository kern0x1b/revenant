// The deleted glyph (0xFFFF) of a run never reaches the rasteriser: the live stretches of a run are drawn, the deleted glyphs are left out.
// The stretch logic works on a glyph array, so the test feeds it arrays that hold the deleted glyph (the host CoreText does not produce one on
// every release), and runs the draw path on a real run of the host CoreText for the case without one.
#import "../Foundation/check.h"
#import <CoreText/CoreText.h>
#import "revenant_deleted_glyphs.h"

#define DELETED REVENANT_DELETED_GLYPH

typedef struct {
    CFRange ranges[16];
    int count;
} Recorded;

static void record(CFRange stretch, void *context)
{
    Recorded *recorded = (Recorded *)context;
    if (recorded->count < 16)
        recorded->ranges[recorded->count] = stretch;
    recorded->count++;
}

static NSString *describe(const Recorded *recorded)
{
    NSMutableString *text = [NSMutableString string];
    for (int index = 0; index < recorded->count && index < 16; index++)
        [text appendFormat:@"[%ld+%ld]", (long)recorded->ranges[index].location, (long)recorded->ranges[index].length];
    return recorded->count ? text : @"none";
}

// The stretches drawn for glyphs[from ..< from + length], as "[at+length]..." or "unchanged" when the range holds no deleted glyph.
static NSString *stretches(const CGGlyph *glyphs, CFIndex from, CFIndex length)
{
    Recorded recorded = {0};
    BOOL filtered = revenant_live_stretches(glyphs, from, length, record, &recorded);
    return filtered ? describe(&recorded) : @"unchanged";
}

static void expect(const char *name, NSString *seen, NSString *expected)
{
    // The red run: the unfixed library hands every glyph to the rasteriser in one piece, that is, the answer is always "unchanged".
    NSString *answer = revenant_negative ? @"unchanged" : seen;
    revenant_check([answer isEqualToString:expected], name, [NSString stringWithFormat:@"%@, expected %@", answer, expected]);
}

static int runDrawCalls;
static CFRange lastDrawRange;
static CFRange drawRanges[8];

static void fakeDraw(CTRunRef run, CGContextRef context, CFRange range)
{
    if (runDrawCalls < 8)
        drawRanges[runDrawCalls] = range;
    lastDrawRange = range;
    runDrawCalls++;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    // The measured case of the 4S: "Hi " then U+2764 U+FE0F gives glyphs 338 and 65535 in the emoji run.
    CGGlyph heart[] = {338, DELETED};
    expect("a run that ends in a deleted glyph draws the live glyph only", stretches(heart, 0, 2), @"[0+1]");

    CGGlyph middle[] = {10, DELETED, 20, 30};
    expect("a deleted glyph in the middle splits the run in two", stretches(middle, 0, 4), @"[0+1][2+2]");

    CGGlyph leading[] = {DELETED, 7, 8};
    expect("a deleted glyph in front is skipped", stretches(leading, 0, 3), @"[1+2]");

    CGGlyph several[] = {DELETED, DELETED, 5, DELETED, DELETED, DELETED, 6, 7, DELETED};
    expect("runs of deleted glyphs leave one stretch of live glyphs between them", stretches(several, 0, 9), @"[2+1][6+2]");

    CGGlyph onlyDeleted[] = {DELETED, DELETED};
    expect("a run of deleted glyphs only draws nothing", stretches(onlyDeleted, 0, 2), @"none");

    CGGlyph clean[] = {1, 2, 3, 0xFFFE, 0};
    expect("a run without the deleted glyph goes through in one piece (0xFFFE and glyph 0 are live)", stretches(clean, 0, 5), @"unchanged");

    CGGlyph partial[] = {DELETED, 4, 5, 6, DELETED};
    expect("a sub-range without a deleted glyph goes through in one piece", stretches(partial, 1, 3), @"unchanged");
    expect("a sub-range that ends at a deleted glyph keeps the live part", stretches(partial, 2, 3), @"[2+2]");
    expect("a sub-range of one deleted glyph draws nothing", stretches(partial, 4, 1), @"none");

    // A real run of the host CoreText: no deleted glyph, so the draw function is called once with the caller's own range.
    CFStringRef font_name = CFSTR("Helvetica");
    CTFontRef font = CTFontCreateWithName(font_name, 12.0, NULL);
    CFStringRef keys[] = {kCTFontAttributeName};
    CFTypeRef values[] = {font};
    CFDictionaryRef attributes = CFDictionaryCreate(NULL, (const void **)keys, (const void **)values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef text = CFAttributedStringCreate(NULL, CFSTR("Hello"), attributes);
    CTLineRef line = CTLineCreateWithAttributedString(text);
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    CTRunRef run = runs && CFArrayGetCount(runs) > 0 ? (CTRunRef)CFArrayGetValueAtIndex(runs, 0) : NULL;
    revenant_check(run != NULL && !revenant_negative, "the host builds a run for the control text", @"no run");
    if (run) {
        revenant_check(!revenant_run_has_deleted_glyph(run) && !revenant_line_has_deleted_glyph(line) && !revenant_negative,
                       "a plain Latin run holds no deleted glyph", @"deleted glyph in plain text");
        runDrawCalls = 0;
        revenant_draw_run_live(fakeDraw, run, NULL, CFRangeMake(0, 0));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 0 && lastDrawRange.length == 0 && !revenant_negative,
                       "a run without a deleted glyph is drawn by one call with the caller's range",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);
        runDrawCalls = 0;
        revenant_draw_run_live(fakeDraw, run, NULL, CFRangeMake(1, 3));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 1 && lastDrawRange.length == 3 && !revenant_negative,
                       "a sub-range is passed on unchanged",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);
        runDrawCalls = 0;
        revenant_draw_run_live(fakeDraw, run, NULL, CFRangeMake(9, 3));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 9 && lastDrawRange.length == 3 && !revenant_negative,
                       "a range outside the run is passed on to CoreText to judge",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);
    }
    if (line)
        CFRelease(line);
    if (text)
        CFRelease(text);
    CFRelease(attributes);
    if (font)
        CFRelease(font);
    return revenant_finish();
}
