#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <math.h>

typedef void (*RunDrawFunction)(CTRunRef, CGContextRef, CFRange);
typedef void (*LineDrawFunction)(CTLineRef, CGContextRef);
typedef void (*FrameDrawFunction)(CTFrameRef, CGContextRef);
typedef double (*LineBoundsFunction)(CTLineRef, CGFloat *, CGFloat *, CGFloat *);
typedef CGRect (*LineImageBoundsFunction)(CTLineRef, CGContextRef);
typedef void (*FrameOriginsFunction)(CTFrameRef, CFRange, CGPoint *);
typedef CGSize (*SuggestSizeFunction)(CTFramesetterRef, CFRange, CFDictionaryRef, CGSize, CFRange *);
typedef CGRect (*LineBoundsWithOptionsFunction)(CTLineRef, CTLineBoundsOptions);

static NSString *const revenant_baseline_offset_name = @"NSBaselineOffset";

static RunDrawFunction system_run_draw = NULL;
static LineDrawFunction system_line_draw = NULL;
static FrameDrawFunction system_frame_draw = NULL;
static LineBoundsFunction system_line_bounds = NULL;
static LineImageBoundsFunction system_line_image_bounds = NULL;
static FrameOriginsFunction system_frame_origins = NULL;
static SuggestSizeFunction system_suggest_size = NULL;
static LineBoundsWithOptionsFunction system_line_bounds_with_options = NULL;

__attribute__((constructor)) static void revenant_resolve_system_text_layout(void)
{
    void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    if (!coreText)
        return;
    system_run_draw = (RunDrawFunction)dlsym(coreText, "CTRunDraw");
    system_line_draw = (LineDrawFunction)dlsym(coreText, "CTLineDraw");
    system_frame_draw = (FrameDrawFunction)dlsym(coreText, "CTFrameDraw");
    system_line_bounds = (LineBoundsFunction)dlsym(coreText, "CTLineGetTypographicBounds");
    system_line_image_bounds = (LineImageBoundsFunction)dlsym(coreText, "CTLineGetImageBounds");
    system_frame_origins = (FrameOriginsFunction)dlsym(coreText, "CTFrameGetLineOrigins");
    system_suggest_size = (SuggestSizeFunction)dlsym(coreText, "CTFramesetterSuggestFrameSizeWithConstraints");
    system_line_bounds_with_options = (LineBoundsWithOptionsFunction)dlsym(coreText, "CTLineGetBoundsWithOptions");
}

static size_t revenant_ink_top(const unsigned char *pixels, size_t width, size_t height)
{
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (pixels[(y * width + x) * 4 + 3] != 0)
                return y;
        }
    }
    return height;
}

static BOOL revenant_system_honours_baseline_offset(void)
{
    static dispatch_once_t once;
    static BOOL honours = NO;
    dispatch_once(&once, ^{
        if (!system_line_draw)
            return;
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 24, NULL);
        NSDictionary *plain = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font};
        NSDictionary *raised = @{(__bridge NSString *)kCTFontAttributeName: (__bridge id)font, revenant_baseline_offset_name: @6};
        const size_t width = 64;
        const size_t height = 64;
        size_t tops[2] = {0, 0};
        NSDictionary *styles[2] = {plain, raised};
        for (int index = 0; index < 2; index++) {
            unsigned char *pixels = calloc(width * height * 4, 1);
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(space);
            NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"H" attributes:styles[index]];
            CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
            CGContextSetTextPosition(context, 10, 20);
            system_line_draw(line, context);
            CFRelease(line);
            tops[index] = revenant_ink_top(pixels, width, height);
            CGContextRelease(context);
            free(pixels);
        }
        honours = tops[0] != tops[1];
        CFRelease(font);
    });
    return honours;
}

static BOOL revenant_needs_model(void)
{
    return !revenant_system_honours_baseline_offset();
}

static CGFloat revenant_run_offset(CTRunRef run)
{
    NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
    NSNumber *offset = attributes[revenant_baseline_offset_name];
    return [offset isKindOfClass:[NSNumber class]] ? offset.doubleValue : 0;
}

static BOOL revenant_line_has_offset(CTLineRef line)
{
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        if (revenant_run_offset((CTRunRef)CFArrayGetValueAtIndex(runs, index)) != 0)
            return YES;
    }
    return NO;
}

static BOOL revenant_frame_has_offset(CTFrameRef frame)
{
    CFArrayRef lines = CTFrameGetLines(frame);
    for (CFIndex index = 0; index < CFArrayGetCount(lines); index++) {
        if (revenant_line_has_offset((CTLineRef)CFArrayGetValueAtIndex(lines, index)))
            return YES;
    }
    return NO;
}

typedef struct {
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
} RevenantLineBox;

static RevenantLineBox revenant_line_box(CTLineRef base, CTLineRef attributed)
{
    RevenantLineBox box = {0, 0, 0};
    system_line_bounds(base, &box.ascent, &box.descent, &box.leading);
    if (!revenant_line_has_offset(attributed))
        return box;
    box.ascent = 0;
    box.descent = 0;
    CFArrayRef runs = CTLineGetGlyphRuns(base);
    CFArrayRef sources = CTLineGetGlyphRuns(attributed);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CGFloat ascent = 0, descent = 0, leading = 0;
        CTRunGetTypographicBounds((CTRunRef)CFArrayGetValueAtIndex(runs, index), CFRangeMake(0, 0), &ascent, &descent, &leading);
        CGFloat offset = revenant_run_offset((CTRunRef)CFArrayGetValueAtIndex(sources, index));
        box.ascent = fmax(box.ascent, ascent + offset);
        box.descent = fmax(box.descent, fmax(0, descent - offset));
    }
    return box;
}

static CGRect revenant_line_image(CTLineRef base, CTLineRef attributed, CGContextRef context)
{
    if (!revenant_line_has_offset(attributed))
        return system_line_image_bounds(base, context);
    CGRect result = CGRectNull;
    CFArrayRef runs = CTLineGetGlyphRuns(base);
    CFArrayRef sources = CTLineGetGlyphRuns(attributed);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
        CFIndex glyphs = CTRunGetGlyphCount(run);
        if (glyphs == 0)
            continue;
        CGRect ink = CTRunGetImageBounds(run, context, CFRangeMake(0, glyphs));
        ink = CGRectOffset(ink, 0, revenant_run_offset((CTRunRef)CFArrayGetValueAtIndex(sources, index)));
        result = CGRectUnion(result, ink);
    }
    return result;
}

static RevenantLineBox revenant_line_box_change(CTLineRef base, CTLineRef attributed)
{
    RevenantLineBox plain = {0, 0, 0};
    system_line_bounds(base, &plain.ascent, &plain.descent, &plain.leading);
    RevenantLineBox box = revenant_line_box(base, attributed);
    return (RevenantLineBox){box.ascent - plain.ascent, box.descent - plain.descent, 0};
}

static CGRect revenant_line_bounds(CTLineRef base, CTLineRef attributed, CTLineBoundsOptions options)
{
    BOOL glyphs = (options & kCTLineBoundsUseGlyphPathBounds) && !(options & kCTLineBoundsUseOpticalBounds);
    if (!glyphs || !revenant_line_has_offset(attributed))
        return system_line_bounds_with_options(base, options);
    return revenant_line_image(base, attributed, NULL);
}

static void revenant_frame_origins_model(CTFrameRef base, CTFrameRef attributed, CGPoint *origins)
{
    CFArrayRef lines = CTFrameGetLines(base);
    CFArrayRef sources = CTFrameGetLines(attributed);
    CFIndex count = CFArrayGetCount(lines);
    if (count == 0)
        return;
    CGPoint *system = calloc(count, sizeof(CGPoint));
    system_frame_origins(base, CFRangeMake(0, 0), system);
    CGFloat shift = 0;
    RevenantLineBox previous = {0, 0, 0};
    for (CFIndex index = 0; index < count; index++) {
        RevenantLineBox change = revenant_line_box_change((CTLineRef)CFArrayGetValueAtIndex(lines, index),
                                                          (CTLineRef)CFArrayGetValueAtIndex(sources, index));
        shift = index == 0 ? -change.ascent : shift - previous.descent - change.ascent;
        origins[index] = CGPointMake(system[index].x, round(system[index].y + shift));
        previous = change;
    }
    free(system);
}

static CGFloat revenant_suggested_height(CTFrameRef base, CTFrameRef attributed)
{
    CFIndex count = CFArrayGetCount(CTFrameGetLines(base));
    if (count == 0)
        return 0;
    CGPoint *origins = calloc(count, sizeof(CGPoint));
    revenant_frame_origins_model(base, attributed, origins);
    RevenantLineBox last = revenant_line_box((CTLineRef)CFArrayGetValueAtIndex(CTFrameGetLines(base), count - 1),
                                             (CTLineRef)CFArrayGetValueAtIndex(CTFrameGetLines(attributed), count - 1));
    CGRect box = CGPathGetPathBoundingBox(CTFrameGetPath(base));
    CGFloat bottom = origins[count - 1].y - last.descent;
    CGFloat height = ceil(box.size.height - bottom);
    free(origins);
    return height;
}

static void revenant_draw_run(CTRunRef run, CGFloat offset, CGContextRef context, CFRange range)
{
    if (offset == 0) {
        system_run_draw(run, context, range);
        return;
    }
    CGAffineTransform matrix = CGContextGetTextMatrix(context);
    CGSize move = CGSizeApplyAffineTransform(CGSizeMake(0, offset), matrix);
    CGPoint start = CGContextGetTextPosition(context);
    CGContextSetTextPosition(context, start.x + move.width, start.y + move.height);
    system_run_draw(run, context, range);
    CGPoint end = CGContextGetTextPosition(context);
    CGContextSetTextPosition(context, end.x - move.width, end.y - move.height);
}

static void revenant_draw_line_runs(CTLineRef drawn, CTLineRef attributed, CGContextRef context)
{
    CFArrayRef runs = CTLineGetGlyphRuns(drawn);
    CFArrayRef sources = CTLineGetGlyphRuns(attributed);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
        CTRunRef source = (CTRunRef)CFArrayGetValueAtIndex(sources, index);
        revenant_draw_run(run, revenant_run_offset(source), context, CFRangeMake(0, CTRunGetGlyphCount(run)));
    }
}

static void revenant_draw_frame_lines(CTFrameRef drawn, CTFrameRef attributed, CGContextRef context)
{
    CFArrayRef lines = CTFrameGetLines(drawn);
    CFArrayRef sources = CTFrameGetLines(attributed);
    CFIndex count = CFArrayGetCount(lines);
    if (count == 0)
        return;
    CGPoint *origins = calloc(count, sizeof(CGPoint));
    revenant_frame_origins_model(drawn, attributed, origins);
    CGRect box = CGPathGetPathBoundingBox(CTFrameGetPath(drawn));
    for (CFIndex index = 0; index < count; index++) {
        CGContextSetTextPosition(context, origins[index].x + box.origin.x, origins[index].y + box.origin.y);
        revenant_draw_line_runs((CTLineRef)CFArrayGetValueAtIndex(lines, index),
                                (CTLineRef)CFArrayGetValueAtIndex(sources, index), context);
    }
    free(origins);
}

void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range)
{
    revenant_draw_run(run, revenant_needs_model() ? revenant_run_offset(run) : 0, context, range);
}

void CTLineDraw(CTLineRef line, CGContextRef context)
{
    if (!revenant_needs_model() || !revenant_line_has_offset(line)) {
        system_line_draw(line, context);
        return;
    }
    revenant_draw_line_runs(line, line, context);
}

void CTFrameDraw(CTFrameRef frame, CGContextRef context)
{
    if (!revenant_needs_model() || !revenant_frame_has_offset(frame)) {
        system_frame_draw(frame, context);
        return;
    }
    revenant_draw_frame_lines(frame, frame, context);
}

double CTLineGetTypographicBounds(CTLineRef line, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    if (!revenant_needs_model() || !revenant_line_has_offset(line))
        return system_line_bounds(line, ascent, descent, leading);
    double width = system_line_bounds(line, NULL, NULL, NULL);
    RevenantLineBox box = revenant_line_box(line, line);
    if (ascent) *ascent = box.ascent;
    if (descent) *descent = box.descent;
    if (leading) *leading = box.leading;
    return width;
}

CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions options)
{
    if (!revenant_needs_model())
        return system_line_bounds_with_options(line, options);
    return revenant_line_bounds(line, line, options);
}

CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef context)
{
    if (!revenant_needs_model() || !revenant_line_has_offset(line))
        return system_line_image_bounds(line, context);
    return revenant_line_image(line, line, context);
}

void CTFrameGetLineOrigins(CTFrameRef frame, CFRange range, CGPoint origins[])
{
    if (!revenant_needs_model() || !revenant_frame_has_offset(frame)) {
        system_frame_origins(frame, range, origins);
        return;
    }
    CFIndex count = CFArrayGetCount(CTFrameGetLines(frame));
    CGPoint *all = calloc(count ? count : 1, sizeof(CGPoint));
    revenant_frame_origins_model(frame, frame, all);
    CFIndex first = range.location;
    CFIndex wanted = range.length == 0 ? count - first : range.length;
    for (CFIndex index = 0; index < wanted && first + index < count; index++)
        origins[index] = all[first + index];
    free(all);
}

CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef framesetter, CFRange stringRange, CFDictionaryRef frameAttributes,
                                                    CGSize constraints, CFRange *fitRange)
{
    CGSize size = system_suggest_size(framesetter, stringRange, frameAttributes, constraints, fitRange);
    if (!revenant_needs_model())
        return size;
    CGFloat height = constraints.height < 1e6 ? constraints.height : 1e6;
    CGPathRef path = CGPathCreateWithRect(CGRectMake(0, 0, constraints.width, height), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, stringRange, path, frameAttributes);
    if (frame && revenant_frame_has_offset(frame))
        size.height = revenant_suggested_height(frame, frame);
    if (frame)
        CFRelease(frame);
    CGPathRelease(path);
    return size;
}

#pragma GCC visibility push(hidden)

void revenant_coretext_model_line_metrics(CTLineRef base, CTLineRef attributed, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    RevenantLineBox box = revenant_line_box(base, attributed);
    *ascent = box.ascent;
    *descent = box.descent;
    *leading = box.leading;
}

CGRect revenant_coretext_model_line_image(CTLineRef base, CTLineRef attributed, CGContextRef context)
{
    return revenant_line_image(base, attributed, context);
}

CGRect revenant_coretext_model_line_bounds(CTLineRef base, CTLineRef attributed, CTLineBoundsOptions options)
{
    return revenant_line_bounds(base, attributed, options);
}

void revenant_coretext_model_frame_origins(CTFrameRef base, CTFrameRef attributed, CGPoint *origins)
{
    revenant_frame_origins_model(base, attributed, origins);
}

CGFloat revenant_coretext_model_suggested_height(CTFrameRef base, CTFrameRef attributed)
{
    return revenant_suggested_height(base, attributed);
}

void revenant_coretext_draw_run_shifted(CTRunRef drawn, CTRunRef attributed, CGContextRef context, CFRange range)
{
    revenant_draw_run(drawn, revenant_run_offset(attributed), context, range);
}

void revenant_coretext_draw_line_shifted(CTLineRef drawn, CTLineRef attributed, CGContextRef context)
{
    revenant_draw_line_runs(drawn, attributed, context);
}

void revenant_coretext_draw_frame_shifted(CTFrameRef drawn, CTFrameRef attributed, CGContextRef context)
{
    revenant_draw_frame_lines(drawn, attributed, context);
}

#pragma GCC visibility pop
