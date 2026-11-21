#import "../app/revenant_check.h"
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

typedef void (*LineDrawFunction)(CTLineRef, CGContextRef);
typedef void (*RunDrawFunction)(CTRunRef, CGContextRef, CFRange);
typedef void (*FrameDrawFunction)(CTFrameRef, CGContextRef);
typedef double (*LineBoundsFunction)(CTLineRef, CGFloat *, CGFloat *, CGFloat *);

static const size_t kWidth = 80;
static const size_t kHeight = 120;

static size_t ink_top(const unsigned char *pixels)
{
    for (size_t y = 0; y < kHeight; y++) {
        for (size_t x = 0; x < kWidth; x++) {
            if (pixels[(y * kWidth + x) * 4 + 3] != 0)
                return y;
        }
    }
    return kHeight;
}

static size_t ink_bottom(const unsigned char *pixels)
{
    for (size_t y = kHeight; y > 0; y--) {
        for (size_t x = 0; x < kWidth; x++) {
            if (pixels[((y - 1) * kWidth + x) * 4 + 3] != 0)
                return y - 1;
        }
    }
    return 0;
}

static NSAttributedString *text_of(NSString *string, CTFontRef font, NSNumber *offset)
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:(__bridge id)font forKey:(__bridge NSString *)kCTFontAttributeName];
    if (offset)
        attributes[@"NSBaselineOffset"] = offset;
    return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

static NSAttributedString *text_with(CTFontRef font, NSNumber *offset)
{
    return text_of(@"H", font, offset);
}

static CGContextRef new_context(unsigned char **pixels)
{
    *pixels = calloc(kWidth * kHeight * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(*pixels, kWidth, kHeight, 8, kWidth * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    return context;
}

static size_t line_top(CTFontRef font, NSNumber *offset, LineDrawFunction draw)
{
    unsigned char *pixels;
    CGContextRef context = new_context(&pixels);
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text_with(font, offset));
    CGContextSetTextPosition(context, 10, 20);
    draw(line, context);
    size_t top = ink_top(pixels);
    CFRelease(line);
    CGContextRelease(context);
    free(pixels);
    return top;
}

static size_t run_top(CTFontRef font, NSNumber *offset, RunDrawFunction draw)
{
    unsigned char *pixels;
    CGContextRef context = new_context(&pixels);
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text_with(font, offset));
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    CGContextSetTextPosition(context, 10, 20);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++)
        draw((CTRunRef)CFArrayGetValueAtIndex(runs, index), context, CFRangeMake(0, 0));
    size_t top = ink_top(pixels);
    CFRelease(line);
    CGContextRelease(context);
    free(pixels);
    return top;
}

static size_t frame_bottom(CTFontRef font, NSNumber *offset, FrameDrawFunction draw)
{
    unsigned char *pixels;
    CGContextRef context = new_context(&pixels);
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text_of(@"H\nH", font, offset));
    CGPathRef path = CGPathCreateWithRect(CGRectMake(10, 0, 60, 100), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    draw(frame, context);
    size_t top = ink_bottom(pixels);
    CFRelease(frame);
    CGPathRelease(path);
    CFRelease(setter);
    CGContextRelease(context);
    free(pixels);
    return top;
}

static double ascent_of(CTFontRef font, NSNumber *offset, LineBoundsFunction bounds)
{
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text_with(font, offset));
    CGFloat ascent = 0, descent = 0, leading = 0;
    bounds(line, &ascent, &descent, &leading);
    CFRelease(line);
    return ascent;
}

static NSString *image_of(const char *symbol)
{
    Dl_info where;
    memset(&where, 0, sizeof where);
    dladdr(dlsym(RTLD_DEFAULT, symbol), &where);
    return where.dli_fname ? [NSString stringWithUTF8String:where.dli_fname] : @"none";
}

REVENANT_CASE(coretext_baseline_offset)
{
    void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
    LineDrawFunction systemLine = (LineDrawFunction)dlsym(coreText, "CTLineDraw");
    RunDrawFunction systemRun = (RunDrawFunction)dlsym(coreText, "CTRunDraw");
    FrameDrawFunction systemFrame = (FrameDrawFunction)dlsym(coreText, "CTFrameDraw");
    LineBoundsFunction systemBounds = (LineBoundsFunction)dlsym(coreText, "CTLineGetTypographicBounds");
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 24, NULL);
    NSNumber *raised = @6;

    size_t systemLinePlain = line_top(font, nil, systemLine), systemLineRaised = line_top(font, raised, systemLine);
    size_t appLinePlain = line_top(font, nil, CTLineDraw), appLineRaised = line_top(font, raised, CTLineDraw);
    size_t systemRunPlain = run_top(font, nil, systemRun), systemRunRaised = run_top(font, raised, systemRun);
    size_t appRunPlain = run_top(font, nil, CTRunDraw), appRunRaised = run_top(font, raised, CTRunDraw);
    size_t systemFramePlain = frame_bottom(font, nil, systemFrame), systemFrameRaised = frame_bottom(font, raised, systemFrame);
    size_t appFramePlain = frame_bottom(font, nil, CTFrameDraw), appFrameRaised = frame_bottom(font, raised, CTFrameDraw);
    double systemAscent = ascent_of(font, raised, systemBounds) - ascent_of(font, nil, systemBounds);
    double appAscent = ascent_of(font, raised, CTLineGetTypographicBounds) - ascent_of(font, nil, CTLineGetTypographicBounds);
    CFRelease(font);

    printf("baseline fact: CTLineDraw image %s\n", [image_of("CTLineDraw") UTF8String]);
    printf("baseline fact: CTRunDraw image %s\n", [image_of("CTRunDraw") UTF8String]);
    printf("baseline fact: CTFrameDraw image %s\n", [image_of("CTFrameDraw") UTF8String]);
    printf("baseline fact: line top system %zu -> %zu, app %zu -> %zu\n", systemLinePlain, systemLineRaised, appLinePlain, appLineRaised);
    printf("baseline fact: run top system %zu -> %zu, app %zu -> %zu\n", systemRunPlain, systemRunRaised, appRunPlain, appRunRaised);
    printf("baseline fact: two-line frame ink bottom system %zu -> %zu, app %zu -> %zu\n", systemFramePlain, systemFrameRaised, appFramePlain, appFrameRaised);
    printf("baseline fact: ascent change system %.2f, app %.2f\n", systemAscent, appAscent);
    fflush(stdout);

    BOOL negativeCase = (BOOL)negative;
    revenant_expect_true(@"the app's CTLineDraw raises the ink by NSBaselineOffset 6",
                         (appLinePlain - appLineRaised == 6) != negativeCase,
                         [NSString stringWithFormat:@"%zu to %zu", appLinePlain, appLineRaised]);
    revenant_expect_true(@"the app's CTRunDraw raises the ink by NSBaselineOffset 6",
                         (appRunPlain - appRunRaised == 6) != negativeCase,
                         [NSString stringWithFormat:@"%zu to %zu", appRunPlain, appRunRaised]);
    revenant_expect_true(@"the app's CTLineGetTypographicBounds ascent grows by NSBaselineOffset 6",
                         (appAscent > 5.5 && appAscent < 6.5) != negativeCase,
                         [NSString stringWithFormat:@"%.2f", appAscent]);
}
