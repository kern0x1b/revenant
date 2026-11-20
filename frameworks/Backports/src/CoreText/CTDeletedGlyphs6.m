#include "revenant_deleted_glyphs.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>

static void *revenant_deleted_glyphs_core_text(void)
{
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    });
    return handle;
}

static BOOL revenant_deleted_glyphs_apply(void)
{
    return NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0;
}

void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range)
{
    static RevenantRunDrawFunction system;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system = (RevenantRunDrawFunction)dlsym(revenant_deleted_glyphs_core_text(), "CTRunDraw");
    });
    if (!revenant_deleted_glyphs_apply()) {
        system(run, context, range);
        return;
    }
    revenant_draw_run_live(system, run, context, range);
}

void CTLineDraw(CTLineRef line, CGContextRef context)
{
    static void (*system_line)(CTLineRef, CGContextRef);
    static RevenantRunDrawFunction system_run;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        system_line = (void (*)(CTLineRef, CGContextRef))dlsym(revenant_deleted_glyphs_core_text(), "CTLineDraw");
        system_run = (RevenantRunDrawFunction)dlsym(revenant_deleted_glyphs_core_text(), "CTRunDraw");
    });
    if (!revenant_deleted_glyphs_apply() || !revenant_line_has_deleted_glyph(line)) {
        system_line(line, context);
        return;
    }
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++)
        revenant_draw_run_live(system_run, (CTRunRef)CFArrayGetValueAtIndex(runs, index), context, CFRangeMake(0, 0));
}
