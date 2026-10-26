#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import <dlfcn.h>
#import <math.h>

typedef void (*RunDrawFunction)(CTRunRef, CGContextRef, CFRange);
typedef void (*LineDrawFunction)(CTLineRef, CGContextRef);
typedef void (*FrameDrawFunction)(CTFrameRef, CGContextRef);
typedef double (*BoundsFunction)(CTLineRef, CGFloat *, CGFloat *, CGFloat *);
typedef CGRect (*ImageFunction)(CTLineRef, CGContextRef);
typedef void (*OriginsFunction)(CTFrameRef, CFRange, CGPoint *);
typedef CGSize (*SuggestFunction)(CTFramesetterRef, CFRange, CFDictionaryRef, CGSize, CFRange *);
typedef CGRect (*BoundsOptionsFunction)(CTLineRef, CTLineBoundsOptions);
typedef CGFloat (*TrailingFunction)(CTLineRef);

extern void revenant_coretext_draw_run_shifted(CTRunRef drawn, CTRunRef attributed, CGContextRef context, CFRange range);
extern void revenant_coretext_draw_line_shifted(CTLineRef drawn, CTLineRef attributed, CGContextRef context);
extern void revenant_coretext_draw_frame_shifted(CTFrameRef drawn, CTFrameRef attributed, CGContextRef context);
extern void revenant_coretext_model_line_metrics(CTLineRef base, CTLineRef attributed, CGFloat *ascent, CGFloat *descent, CGFloat *leading);
extern CGRect revenant_coretext_model_line_image(CTLineRef base, CTLineRef attributed, CGContextRef context);
extern CGRect revenant_coretext_model_line_bounds(CTLineRef base, CTLineRef attributed, CTLineBoundsOptions options);
extern void revenant_coretext_model_frame_origins(CTFrameRef base, CTFrameRef attributed, CGPoint *origins);
extern CGFloat revenant_coretext_model_suggested_height(CTFrameRef base, CTFrameRef attributed);

typedef void (^Drawing)(CGContextRef context);

static const size_t width = 240;
static const size_t height = 80;

typedef struct {
    RunDrawFunction run;
    LineDrawFunction line;
    FrameDrawFunction frame;
    BoundsFunction bounds;
    ImageFunction image;
    OriginsFunction origins;
    SuggestFunction suggest;
    BoundsOptionsFunction boundsWithOptions;
    TrailingFunction trailing;
} Native;

static NSData *render(BOOL flipped, Drawing draw)
{
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (flipped) {
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, 1, -1);
        CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1, -1));
    }
    draw(context);
    NSData *data = [NSData dataWithBytes:pixels length:width * height * 4];
    CGContextRelease(context);
    free(pixels);
    return data;
}

static NSAttributedString *styled(NSString *string, NSRange range, CGFloat offset)
{
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:24]};
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:string attributes:attributes];
    if (range.length > 0)
        [result addAttribute:NSBaselineOffsetAttributeName value:@(offset) range:range];
    return result;
}

static CTLineRef line_of(NSAttributedString *text)
{
    return CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
}

static CTFrameRef frame_of(NSAttributedString *text, CGFloat frameHeight)
{
    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CGPathRef path = CGPathCreateWithRect(CGRectMake(20, 0, 200, frameHeight), NULL);
    CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, NULL);
    CGPathRelease(path);
    CFRelease(setter);
    return frame;
}

static NSData *system_line(NSAttributedString *text, LineDrawFunction draw, BOOL flipped)
{
    return render(flipped, ^(CGContextRef context) {
        CTLineRef line = line_of(text);
        CGContextSetTextPosition(context, 20, 20);
        draw(line, context);
        CFRelease(line);
    });
}

static NSData *model_line(NSAttributedString *drawn, NSAttributedString *attributed, BOOL flipped)
{
    return render(flipped, ^(CGContextRef context) {
        CTLineRef drawnLine = line_of(drawn);
        CTLineRef attributedLine = line_of(attributed);
        CGContextSetTextPosition(context, 20, 20);
        revenant_coretext_draw_line_shifted(drawnLine, attributedLine, context);
        CFRelease(drawnLine);
        CFRelease(attributedLine);
    });
}

static NSData *system_runs(NSAttributedString *text, RunDrawFunction draw)
{
    return render(NO, ^(CGContextRef context) {
        CTLineRef line = line_of(text);
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CGContextSetTextPosition(context, 20, 20);
        for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
            draw(run, context, CFRangeMake(0, CTRunGetGlyphCount(run)));
        }
        CFRelease(line);
    });
}

static NSData *model_runs(NSAttributedString *drawn, NSAttributedString *attributed)
{
    return render(NO, ^(CGContextRef context) {
        CTLineRef drawnLine = line_of(drawn);
        CTLineRef attributedLine = line_of(attributed);
        CFArrayRef runs = CTLineGetGlyphRuns(drawnLine);
        CFArrayRef sources = CTLineGetGlyphRuns(attributedLine);
        CGContextSetTextPosition(context, 20, 20);
        for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, index);
            CTRunRef source = (CTRunRef)CFArrayGetValueAtIndex(sources, index);
            revenant_coretext_draw_run_shifted(run, source, context, CFRangeMake(0, CTRunGetGlyphCount(run)));
        }
        CFRelease(drawnLine);
        CFRelease(attributedLine);
    });
}

static NSData *system_frame(NSAttributedString *text, FrameDrawFunction draw, BOOL flipped)
{
    return render(flipped, ^(CGContextRef context) {
        CTFrameRef frame = frame_of(text, 80);
        draw(frame, context);
        CFRelease(frame);
    });
}

static NSData *model_frame(NSAttributedString *drawn, NSAttributedString *attributed)
{
    return render(NO, ^(CGContextRef context) {
        CTFrameRef drawnFrame = frame_of(drawn, 80);
        CTFrameRef attributedFrame = frame_of(attributed, 80);
        revenant_coretext_draw_frame_shifted(drawnFrame, attributedFrame, context);
        CFRelease(drawnFrame);
        CFRelease(attributedFrame);
    });
}

static size_t top_row(NSData *pixels)
{
    const unsigned char *bytes = pixels.bytes;
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            if (bytes[(y * width + x) * 4 + 3] != 0)
                return y;
        }
    }
    return height;
}

static BOOL close_enough(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 0.001;
}

static BOOL close_rect(CGRect a, CGRect b)
{
    return close_enough(a.origin.x, b.origin.x) && close_enough(a.origin.y, b.origin.y)
        && close_enough(a.size.width, b.size.width) && close_enough(a.size.height, b.size.height);
}

static BOOL layout_check(const char *label, NSAttributedString *plain, NSAttributedString *raised, Native native)
{
    CTLineRef plainLine = line_of(plain);
    CTLineRef raisedLine = line_of(raised);
    CGFloat nativeAscent = 0, nativeDescent = 0, nativeLeading = 0;
    native.bounds(raisedLine, &nativeAscent, &nativeDescent, &nativeLeading);
    CGFloat modelAscent = 0, modelDescent = 0, modelLeading = 0;
    revenant_coretext_model_line_metrics(plainLine, raisedLine, &modelAscent, &modelDescent, &modelLeading);
    BOOL metrics = close_enough(nativeAscent, modelAscent) && close_enough(nativeDescent, modelDescent)
        && close_enough(nativeLeading, modelLeading);
    BOOL image = close_rect(native.image(raisedLine, NULL), revenant_coretext_model_line_image(plainLine, raisedLine, NULL));
    CFRelease(plainLine);
    CFRelease(raisedLine);

    CTFrameRef plainFrame = frame_of(plain, 80);
    CTFrameRef raisedFrame = frame_of(raised, 80);
    CFIndex count = CFArrayGetCount(CTFrameGetLines(raisedFrame));
    CGPoint *nativeOrigins = calloc(count ? count : 1, sizeof(CGPoint));
    CGPoint *modelOrigins = calloc(count ? count : 1, sizeof(CGPoint));
    native.origins(raisedFrame, CFRangeMake(0, 0), nativeOrigins);
    revenant_coretext_model_frame_origins(plainFrame, raisedFrame, modelOrigins);
    BOOL origins = YES;
    for (CFIndex index = 0; index < count; index++)
        origins = origins && close_enough(nativeOrigins[index].x, modelOrigins[index].x) && close_enough(nativeOrigins[index].y, modelOrigins[index].y);
    CFRelease(plainFrame);
    CFRelease(raisedFrame);
    free(nativeOrigins);
    free(modelOrigins);

    CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)raised);
    CGSize nativeSize = native.suggest(setter, CFRangeMake(0, 0), NULL, CGSizeMake(200, 1000), NULL);
    CFRelease(setter);
    CTFrameRef plainTall = frame_of(plain, 1000);
    CTFrameRef raisedTall = frame_of(raised, 1000);
    CGFloat modelHeight = revenant_coretext_model_suggested_height(plainTall, raisedTall);
    BOOL suggest = close_enough(nativeSize.height, modelHeight);
    CFRelease(plainTall);
    CFRelease(raisedTall);

    printf("CT-LAYOUT %s metrics=%d image=%d origins=%d suggest=%d ascent=%.3f/%.3f descent=%.3f/%.3f height=%.3f/%.3f\n",
           label, metrics, image, origins, suggest, nativeAscent, modelAscent, nativeDescent, modelDescent, nativeSize.height, modelHeight);
    return metrics && image && origins && suggest;
}

static BOOL bounds_check(const char *label, NSAttributedString *plain, NSAttributedString *raised, Native native)
{
    CTLineRef plainLine = line_of(plain);
    CTLineRef raisedLine = line_of(raised);
    BOOL glyphs = close_rect(native.boundsWithOptions(raisedLine, kCTLineBoundsUseGlyphPathBounds),
                             revenant_coretext_model_line_bounds(plainLine, raisedLine, kCTLineBoundsUseGlyphPathBounds));
    CGRect nativeOptical = native.boundsWithOptions(raisedLine, kCTLineBoundsUseOpticalBounds);
    BOOL optical = close_rect(nativeOptical, revenant_coretext_model_line_bounds(plainLine, raisedLine, kCTLineBoundsUseOpticalBounds))
        && close_rect(nativeOptical, native.boundsWithOptions(plainLine, kCTLineBoundsUseOpticalBounds));
    BOOL trailing = close_enough(native.trailing(raisedLine), native.trailing(plainLine));
    printf("CT-BOUNDS %s glyph=%d optical=%d trailing=%d\n", label, glyphs, optical, trailing);
    CFRelease(plainLine);
    CFRelease(raisedLine);
    return glyphs && optical && trailing;
}

int main(void)
{
    @autoreleasepool {
        void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
        Native native = {
            (RunDrawFunction)dlsym(coreText, "CTRunDraw"),
            (LineDrawFunction)dlsym(coreText, "CTLineDraw"),
            (FrameDrawFunction)dlsym(coreText, "CTFrameDraw"),
            (BoundsFunction)dlsym(coreText, "CTLineGetTypographicBounds"),
            (ImageFunction)dlsym(coreText, "CTLineGetImageBounds"),
            (OriginsFunction)dlsym(coreText, "CTFrameGetLineOrigins"),
            (SuggestFunction)dlsym(coreText, "CTFramesetterSuggestFrameSizeWithConstraints"),
            (BoundsOptionsFunction)dlsym(coreText, "CTLineGetBoundsWithOptions"),
            (TrailingFunction)dlsym(coreText, "CTLineGetTrailingWhitespaceWidth"),
        };

        NSAttributedString *plain = styled(@"Hxg", NSMakeRange(0, 3), 0);
        NSAttributedString *raised = styled(@"Hxg", NSMakeRange(0, 3), 6);
        BOOL lineEqual = [system_line(raised, native.line, NO) isEqualToData:model_line(plain, raised, NO)];
        BOOL runEqual = [system_runs(raised, native.run) isEqualToData:model_runs(plain, raised)];
        BOOL frameEqual = [system_frame(raised, native.frame, NO) isEqualToData:model_frame(plain, raised)];
        BOOL negativeDiffers = ![system_line(raised, native.line, NO) isEqualToData:system_line(plain, native.line, NO)];

        NSData *flippedPlain = system_line(plain, native.line, YES);
        NSData *flippedRaised = system_line(raised, native.line, YES);
        NSData *modelFlipped = model_line(plain, raised, YES);
        NSData *appKitPlain = render(YES, ^(CGContextRef context) {
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:YES]];
            [plain drawAtPoint:NSMakePoint(20, 20)];
            [NSGraphicsContext restoreGraphicsState];
        });
        NSData *appKitRaised = render(YES, ^(CGContextRef context) {
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:YES]];
            [raised drawAtPoint:NSMakePoint(20, 20)];
            [NSGraphicsContext restoreGraphicsState];
        });
        BOOL flippedLowered = top_row(flippedRaised) > top_row(flippedPlain);
        BOOL flippedModelRaises = top_row(modelFlipped) < top_row(flippedPlain);
        BOOL flippedAppKitUnmoved = top_row(appKitRaised) == top_row(appKitPlain);
        printf("CT-ORACLE line-equal=%d run-equal=%d frame-equal=%d negative-differs=%d flipped-lowered=%d flipped-model-raises=%d flipped-appkit-unmoved=%d\n",
               lineEqual, runEqual, frameEqual, negativeDiffers, flippedLowered, flippedModelRaises, flippedAppKitUnmoved);
        BOOL oracle = lineEqual && runEqual && frameEqual && negativeDiffers && flippedLowered && flippedModelRaises && flippedAppKitUnmoved;

        BOOL layoutEqual = YES;
        layoutEqual = layout_check("one-raised", styled(@"Hxg", NSMakeRange(0, 3), 0), styled(@"Hxg", NSMakeRange(0, 3), 6), native) && layoutEqual;
        layoutEqual = layout_check("one-lowered", styled(@"Hxg", NSMakeRange(0, 3), 0), styled(@"Hxg", NSMakeRange(0, 3), -4), native) && layoutEqual;
        layoutEqual = layout_check("mixed-raised", styled(@"Hxg", NSMakeRange(0, 2), 0), styled(@"Hxg", NSMakeRange(0, 2), 6), native) && layoutEqual;
        layoutEqual = layout_check("two-raised", styled(@"Hxg\nHxg", NSMakeRange(0, 7), 0), styled(@"Hxg\nHxg", NSMakeRange(0, 7), 6), native) && layoutEqual;
        layoutEqual = layout_check("two-lowered", styled(@"Hxg\nHxg", NSMakeRange(0, 7), 0), styled(@"Hxg\nHxg", NSMakeRange(0, 7), -4), native) && layoutEqual;
        layoutEqual = layout_check("two-second-raised", styled(@"Hxg\nHxg", NSMakeRange(4, 3), 0), styled(@"Hxg\nHxg", NSMakeRange(4, 3), 6), native) && layoutEqual;
        printf("CT-LAYOUT all-equal=%d\n", layoutEqual);

        BOOL boundsEqual = YES;
        boundsEqual = bounds_check("one-raised", styled(@"Hxg", NSMakeRange(0, 3), 0), styled(@"Hxg", NSMakeRange(0, 3), 6), native) && boundsEqual;
        boundsEqual = bounds_check("one-lowered", styled(@"Hxg", NSMakeRange(0, 3), 0), styled(@"Hxg", NSMakeRange(0, 3), -4), native) && boundsEqual;
        boundsEqual = bounds_check("mixed-raised", styled(@"Hxg", NSMakeRange(0, 2), 0), styled(@"Hxg", NSMakeRange(0, 2), 6), native) && boundsEqual;
        boundsEqual = bounds_check("two-second-raised", styled(@"Hxg\nHxg", NSMakeRange(4, 3), 0), styled(@"Hxg\nHxg", NSMakeRange(4, 3), 6), native) && boundsEqual;
        boundsEqual = bounds_check("trailing-space-raised", styled(@"Hxg  ", NSMakeRange(0, 5), 0), styled(@"Hxg  ", NSMakeRange(0, 5), 6), native) && boundsEqual;
        printf("CT-BOUNDS all-equal=%d\n", boundsEqual);

        return oracle && layoutEqual && boundsEqual ? 0 : 1;
    }
}
