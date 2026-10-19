#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>

#define CALL_SLOTS 6

static double now(void)
{
    return (double)CFAbsoluteTimeGetCurrent();
}

static void record(NSString *name, NSString *answer)
{
    printf("%s\t%s\n", name.UTF8String, answer.UTF8String);
}

static NSString *pixelOf(CGImageRef image)
{
    if (!image)
        return @"-";
    unsigned char px[4] = { 0, 0, 0, 0 };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(px, 1, 1, 8, 4, cs, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, 1, 1), image);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    return [NSString stringWithFormat:@"%u,%u,%u", px[0], px[1], px[2]];
}

static NSString *bucket(double seconds)
{
    return [NSString stringWithFormat:@"%.2f", floor(seconds * 20.0 + 0.5) / 20.0];
}

static void runData(NSString *label, NSData *data, NSDictionary *options, NSUInteger budgetMillis)
{
    NSMutableArray *indices = [NSMutableArray array];
    NSMutableArray *pixels = [NSMutableArray array];
    NSMutableArray *gaps = [NSMutableArray array];
    __block double previous = 0;
    __block BOOL first = YES;
    double before = now();
    OSStatus status = CGAnimateImageDataWithBlock((__bridge CFDataRef)data, (__bridge CFDictionaryRef)options,
                                                  ^(size_t index, CGImageRef image, bool *stop) {
                                                      double at = now();
                                                      [indices addObject:[NSString stringWithFormat:@"%lu",
                                                                                             (unsigned long)index]];
                                                      [pixels addObject:pixelOf(image)];
                                                      [gaps addObject:(first ? @"first" : bucket(at - previous))];
                                                      first = NO;
                                                      previous = at;
                                                      if (indices.count >= CALL_SLOTS)
                                                          *stop = true;
                                                  });
    double returned = now() - before;
    record([NSString stringWithFormat:@"%@ status", label], [NSString stringWithFormat:@"%d", (int)status]);
    record([NSString stringWithFormat:@"%@ calls at return", label], [NSString stringWithFormat:@"%lu",
                                                                                 (unsigned long)indices.count]);
    record([NSString stringWithFormat:@"%@ returned under 50ms", label], returned < 0.05 ? @"yes" : @"no");
    double until = now() + budgetMillis / 1000.0;
    while (now() < until) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
        if (indices.count >= CALL_SLOTS)
            break;
    }
    for (NSUInteger slot = 0; slot < CALL_SLOTS; slot++) {
        record([NSString stringWithFormat:@"%@ index %lu", label, (unsigned long)slot],
               slot < indices.count ? indices[slot] : @"-");
        record([NSString stringWithFormat:@"%@ pixel %lu", label, (unsigned long)slot],
               slot < pixels.count ? pixels[slot] : @"-");
        record([NSString stringWithFormat:@"%@ gap %lu", label, (unsigned long)slot],
               slot < gaps.count ? gaps[slot] : @"-");
    }
}

static void runURL(NSString *label, NSString *path, NSDictionary *options, NSUInteger budgetMillis)
{
    NSMutableArray *indices = [NSMutableArray array];
    NSMutableArray *pixels = [NSMutableArray array];
    __block double previous = 0;
    __block BOOL first = YES;
    NSMutableArray *gaps = [NSMutableArray array];
    NSURL *url = path ? [NSURL fileURLWithPath:path] : nil;
    OSStatus status = CGAnimateImageAtURLWithBlock((__bridge CFURLRef)url, (__bridge CFDictionaryRef)options,
                                                   ^(size_t index, CGImageRef image, bool *stop) {
                                                       double at = now();
                                                       [indices addObject:[NSString stringWithFormat:@"%lu",
                                                                                                 (unsigned long)index]];
                                                       [pixels addObject:pixelOf(image)];
                                                       [gaps addObject:(first ? @"first" : bucket(at - previous))];
                                                       first = NO;
                                                       previous = at;
                                                       if (indices.count >= CALL_SLOTS)
                                                           *stop = true;
                                                   });
    record([NSString stringWithFormat:@"%@ status", label], [NSString stringWithFormat:@"%d", (int)status]);
    double until = now() + budgetMillis / 1000.0;
    while (now() < until) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
        if (indices.count >= CALL_SLOTS)
            break;
    }
    for (NSUInteger slot = 0; slot < CALL_SLOTS; slot++) {
        record([NSString stringWithFormat:@"%@ index %lu", label, (unsigned long)slot],
               slot < indices.count ? indices[slot] : @"-");
        record([NSString stringWithFormat:@"%@ pixel %lu", label, (unsigned long)slot],
               slot < pixels.count ? pixels[slot] : @"-");
        record([NSString stringWithFormat:@"%@ gap %lu", label, (unsigned long)slot],
               slot < gaps.count ? gaps[slot] : @"-");
    }
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        NSString *build = argc > 1 ? @(argv[1]) : @"/tmp";
        NSData *three = [NSData dataWithContentsOfFile:[build stringByAppendingPathComponent:@"three.gif"]];
        NSData *one = [NSData dataWithContentsOfFile:[build stringByAppendingPathComponent:@"one.gif"]];
        NSData *png = [NSData dataWithContentsOfFile:[build stringByAppendingPathComponent:@"one.png"]];
        NSData *tiff = [NSData dataWithContentsOfFile:[build stringByAppendingPathComponent:@"three.tiff"]];
        NSString *threePath = [build stringByAppendingPathComponent:@"three.gif"];
        record(@"fixtures", [NSString stringWithFormat:@"%lu/%lu/%lu/%lu", (unsigned long)three.length,
                                                       (unsigned long)one.length, (unsigned long)png.length,
                                                       (unsigned long)tiff.length]);

#ifdef REVENANT_PORT
        {
            struct { const char *name; const void *address; } rows[] = {
                { "CGAnimateImageAtURLWithBlock", (const void *)&CGAnimateImageAtURLWithBlock },
                { "CGAnimateImageDataWithBlock", (const void *)&CGAnimateImageDataWithBlock },
            };
            NSMutableString *held = [NSMutableString string];
            for (size_t i = 0; i < sizeof rows / sizeof rows[0]; i++) {
                Dl_info info;
                if (dladdr(rows[i].address, &info) && info.dli_fname && strstr(info.dli_fname, "ImageIO") == NULL)
                    [held appendFormat:@"%s=port,", rows[i].name];
                else
                    [held appendFormat:@"%s=imageio,", rows[i].name];
            }
            record(@"PORTONLY binding", held);
        }
        {
            OSStatus status = CGAnimateImageDataWithBlock((__bridge CFDataRef)three, nil, NULL);
            record(@"PORTONLY null-block status", [NSString stringWithFormat:@"%d", (int)status]);
        }
        {
            __block NSUInteger calls = 0;
            OSStatus status = CGAnimateImageDataWithBlock(
                (__bridge CFDataRef)three,
                (__bridge CFDictionaryRef)@{ (__bridge NSString *)kCGImageAnimationStartIndex : @9 },
                ^(size_t index, CGImageRef image, bool *stop) {
                    calls++;
                });
            double until = now() + 0.4;
            while (now() < until)
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
            record(@"PORTONLY start-past-end", [NSString stringWithFormat:@"%d calls=%lu", (int)status,
                                                                             (unsigned long)calls]);
        }
#endif

        {
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)three, NULL);
            record(@"three.gif type", (__bridge NSString *)CGImageSourceGetType(source));
            for (size_t i = 0; i < CGImageSourceGetCount(source); i++) {
                NSDictionary *properties =
                    (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
                NSNumber *delay =
                    properties[(__bridge NSString *)kCGImagePropertyGIFDictionary]
                              [(__bridge NSString *)kCGImagePropertyGIFDelayTime];
                record([NSString stringWithFormat:@"three.gif delay %lu", (unsigned long)i],
                       delay ? bucket([delay doubleValue]) : @"(nil)");
            }
            CFRelease(source);
        }

        runData(@"three-loop-1", three, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runData(@"three-forever", three, nil, 4000);
        runData(@"three-start-1", three,
                @{ (__bridge NSString *)kCGImageAnimationStartIndex : @1,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runData(@"three-start-negative", three,
                @{ (__bridge NSString *)kCGImageAnimationStartIndex : @(-1),
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runData(@"three-loop-2", three, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @2 }, 5000);
        runData(@"one-loop-1", one, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 1000);
        runData(@"one-loop-3", one, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @3 }, 1000);
        runData(@"one-no-options", one, nil, 1000);
        runData(@"three-option-0.02", three,
                @{ (__bridge NSString *)kCGImageAnimationDelayTime : @0.02,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runData(@"three-option-2.0", three,
                @{ (__bridge NSString *)kCGImageAnimationDelayTime : @2.0,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 5000);
        runData(@"three-empty-options", three, @{}, 3000);

        runData(@"png", png, nil, 300);
        runData(@"three-frame-tiff", tiff, nil, 300);
        runData(@"garbage", [@"not an image" dataUsingEncoding:NSUTF8StringEncoding], nil, 300);
        runData(@"empty-data", [NSData data], nil, 300);
        {
            __block NSUInteger calls = 0;
            OSStatus status = CGAnimateImageDataWithBlock(NULL, nil, ^(size_t index, CGImageRef image, bool *stop) {
                calls++;
            });
            record(@"null-data status", [NSString stringWithFormat:@"%d calls=%lu", (int)status,
                                                                   (unsigned long)calls]);
        }

        runURL(@"url-three", threePath, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runURL(@"url-missing", [build stringByAppendingPathComponent:@"no-such.gif"], nil, 300);
        runURL(@"url-null", nil, nil, 300);
        runURL(@"url-directory", build, nil, 300);

    }
    return 0;
}
