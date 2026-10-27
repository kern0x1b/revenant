#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <math.h>
#import <CoreText/CoreText.h>

typedef struct {
    size_t top;
    size_t bottom;
    size_t left;
    size_t right;
    size_t ink;
    double centre;
} InkBox;

static InkBox drawn_ink(NSAttributedString *text, CGFloat originY)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    UIGraphicsPushContext(context);
    [text drawAtPoint:CGPointMake(20, originY)];
    UIGraphicsPopContext();
    InkBox box = { height, 0, width, 0, 0 };
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (pixels[(y * width + x) * 4 + 3] == 0)
                continue;
            box.ink++;
            if (y < box.top) box.top = y;
            if (y + 1 > box.bottom) box.bottom = y + 1;
            if (x < box.left) box.left = x;
            if (x + 1 > box.right) box.right = x + 1;
        }
    }
    CGContextRelease(context);
    free(pixels);
    return box;
}

static InkBox ink_of(unsigned char *pixels, size_t width, size_t height)
{
    InkBox box = { height, 0, width, 0, 0, 0 };
    double weight = 0, weighted_rows = 0;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            unsigned char alpha = pixels[(y * width + x) * 4 + 3];
            if (alpha == 0)
                continue;
            box.ink++;
            weight += alpha;
            weighted_rows += (double)alpha * (double)y;
            if (y < box.top) box.top = y;
            if (y + 1 > box.bottom) box.bottom = y + 1;
            if (x < box.left) box.left = x;
            if (x + 1 > box.right) box.right = x + 1;
        }
    }
    box.centre = weight > 0 ? weighted_rows / weight : 0;
    return box;
}

static InkBox core_text_ink_in(NSAttributedString *text, CGFloat originY, BOOL perRun, BOOL flipped)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (flipped) {
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, 1, -1);
        CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1, -1));
    }
    CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)text);
    CGContextSetTextPosition(context, 20, originY);
    if (perRun) {
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
            CTRunDraw(run, context, CFRangeMake(0, CTRunGetGlyphCount(run)));
        }
    } else {
        CTLineDraw(line, context);
    }
    CFRelease(line);
    InkBox box = ink_of(pixels, width, height);
    CGContextRelease(context);
    free(pixels);
    return box;
}

extern void revenant_coretext_draw_frame_shifted(CTFrameRef drawn, CTFrameRef attributed, CGContextRef context);
extern void revenant_coretext_model_frame_origins(CTFrameRef base, CTFrameRef attributed, CGPoint *origins);

static InkBox core_text_ink(NSAttributedString *text, CGFloat originY, BOOL perRun)
{
    return core_text_ink_in(text, originY, perRun, NO);
}

static InkBox drawn_ink_flipped(NSAttributedString *text, CGFloat originY)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    UIGraphicsPushContext(context);
    [text drawAtPoint:CGPointMake(20, originY)];
    UIGraphicsPopContext();
    InkBox box = ink_of(pixels, width, height);
    CGContextRelease(context);
    free(pixels);
    return box;
}

static InkBox core_text_frame_ink(NSAttributedString *text, BOOL manual)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)text);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(20, 0, 200, 80), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    if (manual)
        revenant_coretext_draw_frame_shifted(frame, frame, context);
    else
        CTFrameDraw(frame, context);
    CFRelease(frame);
    CGPathRelease(path);
    CFRelease(setter);
    InkBox box = ink_of(pixels, width, height);
    CGContextRelease(context);
    free(pixels);
    return box;
}

static InkBox rect_ink(NSAttributedString *text, CGFloat originY)
{
    const size_t width = 240;
    const size_t height = 80;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    UIGraphicsPushContext(context);
    [text drawInRect:CGRectMake(20, originY, 200, 40)];
    UIGraphicsPopContext();
    InkBox box = ink_of(pixels, width, height);
    CGContextRelease(context);
    free(pixels);
    return box;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("BASELINE-PROBE step=application\n");
        (void)[UIApplication sharedApplication];
        void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
        unsigned long (*font_type_id)(void) = graphics ? dlsym(graphics, "GSFontGetTypeID") : NULL;
        void (*gs_initialize)(void) = graphics ? dlsym(graphics, "GSInitialize") : NULL;
        printf("BASELINE-PROBE step=gs-font-type-id before=%lu\n", font_type_id ? font_type_id() : 0ul);
        if (gs_initialize) {
            gs_initialize();
        }
        printf("BASELINE-PROBE step=gs-initialize present=%d after=%lu\n", gs_initialize != NULL, font_type_id ? font_type_id() : 0ul);
        printf("BASELINE-PROBE step=font\n");
        UIFont *font = [UIFont systemFontOfSize:24];
        printf("BASELINE-PROBE step=strings\n");
        NSMutableAttributedString *plain = [[NSMutableAttributedString alloc] initWithString:@"Hxg" attributes:@{NSFontAttributeName: font}];
        NSMutableAttributedString *raised = [[NSMutableAttributedString alloc] initWithString:@"Hxg" attributes:@{NSFontAttributeName: font}];
        [raised addAttribute:NSBaselineOffsetAttributeName value:@6.0 range:NSMakeRange(0, raised.length)];
        printf("BASELINE-PROBE step=draw-plain\n");
        InkBox a = drawn_ink(plain, 20);
        printf("BASELINE-PROBE step=draw-raised\n");
        InkBox b = drawn_ink(raised, 20);
        printf("BASELINE-PROBE step=draw-control\n");
        InkBox c = drawn_ink(plain, 14);
        printf("BASELINE-PROBE plain top=%lu bottom=%lu left=%lu right=%lu ink=%lu\n",
               (unsigned long)a.top, (unsigned long)a.bottom, (unsigned long)a.left, (unsigned long)a.right, (unsigned long)a.ink);
        printf("BASELINE-PROBE raised top=%lu bottom=%lu left=%lu right=%lu ink=%lu\n",
               (unsigned long)b.top, (unsigned long)b.bottom, (unsigned long)b.left, (unsigned long)b.right, (unsigned long)b.ink);
        printf("BASELINE-PROBE shift=%ld ink-equal=%d\n", (long)b.top - (long)a.top, a.ink == b.ink);
        printf("BASELINE-PROBE control shift=%ld ink-equal=%d\n", (long)c.top - (long)a.top, a.ink == c.ink);
        InkBox lineA = core_text_ink(plain, 20, NO);
        InkBox lineB = core_text_ink(raised, 20, NO);
        InkBox lineC = core_text_ink(plain, 14, NO);
        printf("BASELINE-PROBE ct-line shift=%ld ink-equal=%d control=%ld ink=%lu\n", (long)lineB.top - (long)lineA.top,
               lineA.ink == lineB.ink, (long)lineC.top - (long)lineA.top, (unsigned long)lineA.ink);
        InkBox runA = core_text_ink(plain, 20, YES);
        InkBox runB = core_text_ink(raised, 20, YES);
        printf("BASELINE-PROBE ct-run shift=%ld ink-equal=%d ink=%lu\n", (long)runB.top - (long)runA.top, runA.ink == runB.ink,
               (unsigned long)runA.ink);
        InkBox rectA = rect_ink(plain, 20);
        InkBox rectB = rect_ink(raised, 20);
        printf("BASELINE-PROBE draw-in-rect shift=%ld ink-equal=%d ink=%lu centre-shift=%.3f\n", (long)rectB.top - (long)rectA.top,
               rectA.ink == rectB.ink, (unsigned long)rectA.ink, rectB.centre - rectA.centre);
        InkBox frameA = core_text_frame_ink(plain, NO);
        InkBox frameB = core_text_frame_ink(raised, NO);
        printf("BASELINE-PROBE ct-frame shift=%ld ink-equal=%d ink=%lu\n", (long)frameB.top - (long)frameA.top, frameA.ink == frameB.ink,
               (unsigned long)frameA.ink);
        InkBox frameManual = core_text_frame_ink(plain, YES);
        printf("BASELINE-PROBE ct-frame-manual plain-top=%lu system-top=%lu plain-ink=%lu system-ink=%lu centre-diff=%.3f\n",
               (unsigned long)frameManual.top, (unsigned long)frameA.top, (unsigned long)frameManual.ink, (unsigned long)frameA.ink,
               frameManual.centre - frameA.centre);
        CTLineRef metricsPlain = CTLineCreateWithAttributedString((CFAttributedStringRef)plain);
        CTLineRef metricsRaised = CTLineCreateWithAttributedString((CFAttributedStringRef)raised);
        CGFloat ascentA = 0, descentA = 0, leadingA = 0, ascentB = 0, descentB = 0, leadingB = 0;
        CTLineGetTypographicBounds(metricsPlain, &ascentA, &descentA, &leadingA);
        CTLineGetTypographicBounds(metricsRaised, &ascentB, &descentB, &leadingB);
        printf("BASELINE-PROBE ct-metrics ascent=%g,%g descent=%g,%g\n", ascentA, ascentB, descentA, descentB);
        CGRect imageA = CTLineGetImageBounds(metricsPlain, NULL);
        CGRect imageB = CTLineGetImageBounds(metricsRaised, NULL);
        printf("BASELINE-PROBE ct-image plain-y=%g raised-y=%g height=%g,%g\n", imageA.origin.y, imageB.origin.y, imageA.size.height,
               imageB.size.height);
        CGRect glyphA = CTLineGetBoundsWithOptions(metricsPlain, kCTLineBoundsUseGlyphPathBounds);
        CGRect glyphB = CTLineGetBoundsWithOptions(metricsRaised, kCTLineBoundsUseGlyphPathBounds);
        CGRect opticalA = CTLineGetBoundsWithOptions(metricsPlain, kCTLineBoundsUseOpticalBounds);
        CGRect opticalB = CTLineGetBoundsWithOptions(metricsRaised, kCTLineBoundsUseOpticalBounds);
        printf("BASELINE-PROBE ct-bounds glyph-y=%g,%g glyph-height=%g,%g optical-equal=%d\n", glyphA.origin.y, glyphB.origin.y,
               glyphA.size.height, glyphB.size.height, CGRectEqualToRect(opticalA, opticalB));
        NSAttributedString *spacedPlain = [[NSAttributedString alloc] initWithString:@"Hxg  " attributes:@{NSFontAttributeName: font}];
        NSMutableAttributedString *spacedRaised = [[NSMutableAttributedString alloc] initWithString:@"Hxg  "
                                                                                          attributes:@{NSFontAttributeName: font}];
        [spacedRaised addAttribute:NSBaselineOffsetAttributeName value:@6.0 range:NSMakeRange(0, spacedRaised.length)];
        CTLineRef spacedA = CTLineCreateWithAttributedString((CFAttributedStringRef)spacedPlain);
        CTLineRef spacedB = CTLineCreateWithAttributedString((CFAttributedStringRef)spacedRaised);
        printf("BASELINE-PROBE ct-trailing plain=%g raised=%g\n", CTLineGetTrailingWhitespaceWidth(spacedA),
               CTLineGetTrailingWhitespaceWidth(spacedB));
        CFRelease(spacedA);
        CFRelease(spacedB);
        CFRelease(metricsPlain);
        CFRelease(metricsRaised);
        CGFloat plainOrigin = 0, raisedOrigin = 0;
        for (int index = 0; index < 2; index++) {
            CTFramesetterRef originSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)(index ? raised : plain));
            CGPathRef originPath = CGPathCreateWithRect(CGRectMake(20, 0, 200, 80), NULL);
            CTFrameRef originFrame = CTFramesetterCreateFrame(originSetter, CFRangeMake(0, 0), originPath, NULL);
            CGPoint origin = CGPointZero;
            CTFrameGetLineOrigins(originFrame, CFRangeMake(0, 1), &origin);
            if (index)
                raisedOrigin = origin.y;
            else
                plainOrigin = origin.y;
            CFRelease(originFrame);
            CGPathRelease(originPath);
            CFRelease(originSetter);
        }
        printf("BASELINE-PROBE ct-origin first-line plain=%g raised=%g\n", plainOrigin, raisedOrigin);
        InkBox flippedLineA = core_text_ink_in(plain, 30, NO, YES);
        InkBox flippedLineB = core_text_ink_in(raised, 30, NO, YES);
        printf("BASELINE-PROBE ct-line-flipped shift=%ld ink-equal=%d ink=%lu\n", (long)flippedLineB.top - (long)flippedLineA.top,
               flippedLineA.ink == flippedLineB.ink, (unsigned long)flippedLineA.ink);
        InkBox flippedDrawA = drawn_ink_flipped(plain, 30);
        InkBox flippedDrawB = drawn_ink_flipped(raised, 30);
        printf("BASELINE-PROBE draw-flipped shift=%ld ink-equal=%d ink=%lu\n", (long)flippedDrawB.top - (long)flippedDrawA.top,
               flippedDrawA.ink == flippedDrawB.ink, (unsigned long)flippedDrawA.ink);
        CGSize boundsA = [plain boundingRectWithSize:CGSizeMake(400, 400) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        CGSize boundsB = [raised boundingRectWithSize:CGSizeMake(400, 400) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size;
        printf("BASELINE-PROBE bounds plain=%g,%g raised=%g,%g\n", boundsA.width, boundsA.height, boundsB.width, boundsB.height);
        printf("BASELINE-PROBE-DONE\n");
    }
    return 0;
}
