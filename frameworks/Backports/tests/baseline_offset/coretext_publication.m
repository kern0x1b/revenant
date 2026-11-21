#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

extern void revenant_note_baseline_offset(CFAttributedStringRef string);

typedef void (*LineDraw)(CTLineRef, CGContextRef);

static NSAttributedString *text(double offset)
{
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 24, NULL);
    NSMutableDictionary *attributes = [@{(__bridge id)kCTFontAttributeName: (__bridge id)font} mutableCopy];
    if (offset != 0)
        attributes[@"NSBaselineOffset"] = @(offset);
    CFRelease(font);
    return [[NSAttributedString alloc] initWithString:@"Hxg" attributes:attributes];
}

static NSData *render(CTLineRef line, LineDraw draw)
{
    const size_t width = 120, height = 60;
    unsigned char *pixels = calloc(width * height * 4, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextSetTextPosition(context, 10, 20);
    draw(line, context);
    CGContextRelease(context);
    return [NSData dataWithBytesNoCopy:pixels length:width * height * 4 freeWhenDone:YES];
}

int main(void)
{
    @autoreleasepool {
        void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_NOW);
        LineDraw system_draw = (LineDraw)dlsym(coreText, "CTLineDraw");
        NSAttributedString *raised = text(6);
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)raised);
        NSData *native = render(line, system_draw);
        BOOL passes = [render(line, CTLineDraw) isEqualToData:native];

        dispatch_semaphore_t made = dispatch_semaphore_create(0);
        dispatch_semaphore_t drawn = dispatch_semaphore_create(0);
        __block BOOL takesModel = NO;
        dispatch_queue_t maker = dispatch_queue_create("maker", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t painter = dispatch_queue_create("painter", DISPATCH_QUEUE_SERIAL);
        dispatch_async(painter, ^{
            dispatch_semaphore_wait(made, DISPATCH_TIME_FOREVER);
            takesModel = ![render(line, CTLineDraw) isEqualToData:native];
            dispatch_semaphore_signal(drawn);
        });
        dispatch_async(maker, ^{
            revenant_note_baseline_offset((__bridge CFAttributedStringRef)raised);
            dispatch_semaphore_signal(made);
        });
        dispatch_semaphore_wait(drawn, DISPATCH_TIME_FOREVER);
        BOOL again = ![render(line, CTLineDraw) isEqualToData:native];
        printf("CT-PUBLICATION before-seen-passes-through=%d made-elsewhere-takes-model=%d model-everywhere-after=%d\n", passes, takesModel, again);
        CFRelease(line);
        return passes && takesModel && again ? 0 : 1;
    }
}
