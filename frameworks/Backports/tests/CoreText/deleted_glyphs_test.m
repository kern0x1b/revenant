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

static NSString *stretches(const CGGlyph *glyphs, CFIndex from, CFIndex length)
{
    Recorded recorded = {0};
    BOOL filtered = revenant_live_stretches(glyphs, from, length, record, &recorded);
    return filtered ? describe(&recorded) : @"unchanged";
}

static void expect(const char *name, NSString *seen, NSString *expected)
{
    NSString *answer = revenant_negative ? @"unchanged" : seen;
    revenant_check([answer isEqualToString:expected], name, [NSString stringWithFormat:@"%@, expected %@", answer, expected]);
}

static int runDrawCalls;
static CFRange lastDrawRange;
static CFRange drawRanges[8];
static CGPoint drawPositions[8];

static void fakeDraw(CTRunRef run, CGContextRef context, CFRange range)
{
    if (runDrawCalls < 8) {
        drawRanges[runDrawCalls] = range;
        drawPositions[runDrawCalls] = CGContextGetTextPosition(context);
    }
    lastDrawRange = range;
    runDrawCalls++;
}

static CGContextRef bitmap(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 40, 40, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    return context;
}

static NSString *drawn(CTRunRef run, const CGGlyph *glyphs, CFIndex count, CGFloat offset, CGAffineTransform matrix, CGPoint *after)
{
    if (revenant_negative) {
        glyphs = NULL;
        offset = 0;
    }
    CGContextRef context = bitmap();
    CGContextSetTextMatrix(context, matrix);
    CGContextSetTextPosition(context, 10, 20);
    runDrawCalls = 0;
    revenant_draw_run_glyphs(fakeDraw, run, glyphs, count, offset, context, CFRangeMake(0, 0));
    *after = CGContextGetTextPosition(context);
    CGContextRelease(context);
    NSMutableString *calls = [NSMutableString string];
    for (int index = 0; index < runDrawCalls && index < 8; index++)
        [calls appendFormat:@"[%ld+%ld at %g,%g]", (long)drawRanges[index].location, (long)drawRanges[index].length, drawPositions[index].x, drawPositions[index].y];
    return calls;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

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
        revenant_draw_run_shifted(fakeDraw, run, 0, YES, bitmap(), CFRangeMake(0, 0));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 0 && lastDrawRange.length == 0 && !revenant_negative,
                       "a run without a deleted glyph is drawn by one call with the caller's range",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);
        runDrawCalls = 0;
        revenant_draw_run_shifted(fakeDraw, run, 0, YES, bitmap(), CFRangeMake(1, 3));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 1 && lastDrawRange.length == 3 && !revenant_negative,
                       "a sub-range is passed on unchanged",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);
        runDrawCalls = 0;
        revenant_draw_run_shifted(fakeDraw, run, 0, YES, bitmap(), CFRangeMake(9, 3));
        revenant_check(runDrawCalls == 1 && lastDrawRange.location == 9 && lastDrawRange.length == 3 && !revenant_negative,
                       "a range outside the run is passed on to CoreText to judge",
                       [NSString stringWithFormat:@"%d calls, last range %ld+%ld", runDrawCalls, (long)lastDrawRange.location, (long)lastDrawRange.length]);

        CGGlyph withDeleted[] = {1, DELETED, 3, 4, 5};
        CGPoint after = CGPointZero;
        CGAffineTransform identity = CGAffineTransformIdentity;
        NSString *seen = drawn(run, NULL, 0, 6, identity, &after);
        revenant_check([seen isEqualToString:@"[0+0 at 10,26]"] && after.x == 10 && after.y == 20,
                       "a baseline offset moves the text position along the text matrix for the call and puts it back", seen);
        seen = drawn(run, NULL, 0, 6, CGAffineTransformMakeScale(1, -1), &after);
        revenant_check([seen isEqualToString:@"[0+0 at 10,14]"] && after.x == 10 && after.y == 20,
                       "a flipped text matrix lowers the text position for a raised run", seen);
        seen = drawn(run, NULL, 0, 6, CGAffineTransformMakeScale(2, 3), &after);
        revenant_check([seen isEqualToString:@"[0+0 at 10,38]"] && after.x == 10 && after.y == 20,
                       "a scaled text matrix scales the offset", seen);
        seen = drawn(run, withDeleted, 5, 6, identity, &after);
        revenant_check([seen isEqualToString:@"[0+1 at 10,26][2+3 at 10,26]"] && after.x == 10 && after.y == 20,
                       "a raised run with a deleted glyph draws its live stretches at the raised position, once shifted", seen);
        seen = drawn(run, withDeleted, 5, 0, identity, &after);
        revenant_check([seen isEqualToString:@"[0+1 at 10,20][2+3 at 10,20]"] && after.x == 10 && after.y == 20,
                       "a run without an offset draws its live stretches where the text position is", seen);
        seen = drawn(run, NULL, 0, 0, identity, &after);
        revenant_check([seen isEqualToString:@"[0+0 at 10,20]"] && after.x == 10 && after.y == 20 && !revenant_negative,
                       "a run without an offset or a deleted glyph is drawn as it is", seen);
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
