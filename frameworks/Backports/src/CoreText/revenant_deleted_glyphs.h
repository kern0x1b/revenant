// The deleted glyph of a run, and how the draw entry points of the backports leave it out.
//
// A font whose `morx` table has a delete action (the current AppleColorEmoji: a variation selector after a text-default emoji, the tail of a
// ligature) leaves the glyph 0xFFFF in the glyph array of a run: AAT's "deleted glyph". CoreText of iOS 6.1.3 keeps it there and hands it to
// the rasteriser, where FreeType answers FT_Err_Invalid_Argument (6) for a glyph index past the font's glyph count and libCGFreetype logs two
// <Error> lines, "AppleColorEmoji: FT_Load_Glyph failed: error 6.", for every drawing of the run (measured on the 4S: "Hi " and U+2764 U+FE0F
// gives a run of the glyphs 338 and 65535; Telegram's first chat list logs 6 lines for three such runs). The glyph has no ink and no advance,
// so leaving it out of the drawing changes no pixel; only the log and the FreeType call go.
//
// The helpers are static inline so that a host test can compile them without the library.

#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdlib.h>

#define REVENANT_DELETED_GLYPH ((CGGlyph)0xFFFF)

typedef void (*RevenantRunDrawFunction)(CTRunRef, CGContextRef, CFRange);
typedef void (*RevenantStretchFunction)(CFRange stretch, void *context);

static inline BOOL revenant_glyphs_have_deleted(const CGGlyph *glyphs, CFIndex count)
{
    for (CFIndex index = 0; index < count; index++) {
        if (glyphs[index] == REVENANT_DELETED_GLYPH)
            return YES;
    }
    return NO;
}

// Calls `stretch` once for every stretch of live glyphs in glyphs[from ..< from + length], in order, and answers YES. Answers NO and calls
// nothing when the range holds no deleted glyph: the caller then handles the range as it is, in one piece.
static inline BOOL revenant_live_stretches(const CGGlyph *glyphs, CFIndex from, CFIndex length, RevenantStretchFunction stretch, void *context)
{
    if (!revenant_glyphs_have_deleted(glyphs + from, length))
        return NO;
    CFIndex end = from + length;
    CFIndex at = from;
    while (at < end) {
        while (at < end && glyphs[at] == REVENANT_DELETED_GLYPH)
            at++;
        if (at >= end)
            break;
        CFIndex stop = at;
        while (stop < end && glyphs[stop] != REVENANT_DELETED_GLYPH)
            stop++;
        stretch(CFRangeMake(at, stop - at), context);
        at = stop;
    }
    return YES;
}

// The glyphs of a run: the run's own array when it has one, else a copy (freed by the caller through *owned).
static inline const CGGlyph *revenant_run_glyphs(CTRunRef run, CFIndex count, CGGlyph *stack, CFIndex stack_count, CGGlyph **owned)
{
    *owned = NULL;
    const CGGlyph *glyphs = CTRunGetGlyphsPtr(run);
    if (glyphs)
        return glyphs;
    CGGlyph *copy = count <= stack_count ? stack : (CGGlyph *)malloc(sizeof(CGGlyph) * (size_t)count);
    if (!copy)
        return NULL;
    if (copy != stack)
        *owned = copy;
    CTRunGetGlyphs(run, CFRangeMake(0, count), copy);
    return copy;
}

static inline BOOL revenant_run_has_deleted_glyph(CTRunRef run)
{
    CFIndex count = CTRunGetGlyphCount(run);
    if (count <= 0)
        return NO;
    CGGlyph stack[64];
    CGGlyph *owned = NULL;
    const CGGlyph *glyphs = revenant_run_glyphs(run, count, stack, 64, &owned);
    BOOL deleted = glyphs && revenant_glyphs_have_deleted(glyphs, count);
    free(owned);
    return deleted;
}

static inline BOOL revenant_line_has_deleted_glyph(CTLineRef line)
{
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        if (revenant_run_has_deleted_glyph((CTRunRef)CFArrayGetValueAtIndex(runs, index)))
            return YES;
    }
    return NO;
}

typedef struct {
    RevenantRunDrawFunction draw;
    CTRunRef run;
    CGContextRef context;
} RevenantRunStretch;

static inline void revenant_draw_stretch(CFRange stretch, void *context)
{
    RevenantRunStretch *target = (RevenantRunStretch *)context;
    target->draw(target->run, target->context, stretch);
}

// CTRunDraw's contract with a range of length 0: from the start of the range to the end of the run. A run without a deleted glyph in the
// range goes to `draw` unchanged, one call with the caller's range; otherwise every stretch of live glyphs is drawn by its own call. The glyphs
// keep their own positions (CTRunDraw places glyph i at the text position plus its position in the run), so the stretches fall where the whole
// run would have drawn them.
static inline void revenant_draw_run_live(RevenantRunDrawFunction draw, CTRunRef run, CGContextRef context, CFRange range)
{
    CFIndex count = CTRunGetGlyphCount(run);
    CFIndex from = range.location;
    CFIndex length = range.length > 0 ? range.length : count - from;
    if (from < 0 || length <= 0 || from + length > count) {
        draw(run, context, range);
        return;
    }
    CGGlyph stack[64];
    CGGlyph *owned = NULL;
    const CGGlyph *glyphs = revenant_run_glyphs(run, count, stack, 64, &owned);
    RevenantRunStretch target = {draw, run, context};
    if (!glyphs || !revenant_live_stretches(glyphs, from, length, revenant_draw_stretch, &target))
        draw(run, context, range);
    free(owned);
}
