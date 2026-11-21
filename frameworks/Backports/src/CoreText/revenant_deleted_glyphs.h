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

static inline CGSize revenant_move_text_position(CGContextRef context, CGFloat offset)
{
    CGSize move = CGSizeApplyAffineTransform(CGSizeMake(0, offset), CGContextGetTextMatrix(context));
    CGPoint start = CGContextGetTextPosition(context);
    CGContextSetTextPosition(context, start.x + move.width, start.y + move.height);
    return move;
}

static inline void revenant_move_back_text_position(CGContextRef context, CGSize move)
{
    CGPoint end = CGContextGetTextPosition(context);
    CGContextSetTextPosition(context, end.x - move.width, end.y - move.height);
}

static inline void revenant_draw_run_glyphs(RevenantRunDrawFunction draw, CTRunRef run, const CGGlyph *glyphs, CFIndex count,
                                            CGFloat offset, CGContextRef context, CFRange range)
{
    CGSize move = CGSizeZero;
    if (offset != 0)
        move = revenant_move_text_position(context, offset);
    CFIndex from = range.location;
    CFIndex length = range.length > 0 ? range.length : count - from;
    RevenantRunStretch target = {draw, run, context};
    if (glyphs == NULL || from < 0 || length <= 0 || from + length > count
        || !revenant_live_stretches(glyphs, from, length, revenant_draw_stretch, &target))
        draw(run, context, range);
    if (offset != 0)
        revenant_move_back_text_position(context, move);
}

static inline void revenant_draw_run_shifted(RevenantRunDrawFunction draw, CTRunRef run, CGFloat offset, BOOL live,
                                             CGContextRef context, CFRange range)
{
    CFIndex count = live ? CTRunGetGlyphCount(run) : 0;
    CGGlyph stack[64];
    CGGlyph *owned = NULL;
    const CGGlyph *glyphs = count > 0 ? revenant_run_glyphs(run, count, stack, 64, &owned) : NULL;
    revenant_draw_run_glyphs(draw, run, glyphs, count, offset, context, range);
    free(owned);
}
