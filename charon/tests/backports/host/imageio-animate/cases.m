// The cases CGAnimateImageAtURLWithBlock and CGAnimateImageDataWithBlock have to answer, compiled twice:
// once against the HOST's own ImageIO and once against the port's object, so the two sets of answers are
// compared by run.sh line by line.
//
// THE GIF FILES ARE WRITTEN ONCE, by write-gifs.m, and read by both builds, so the two sides are asked
// about the same bytes. They are written by the host's own destination, which is the only writer either
// build has: the port's object defines these two functions and nothing else.
//
// A CALL THAT HAS NOT COME IS PRINTED AS A LINE TOO, as "-" for its index and pixels. Both builds therefore
// print the same number of records whatever the animation did, and a call that one build made and the other
// did not shows up as a value in a line both printed, not as a missing line that a diff would count as one
// case away from the next.
//
// THE TIMING IS COMPARED IN BUCKETS, not as a floating point number: the block's own argument is the frame
// (compared by its pixels) and the observable the harness holds the timing to is that the gap between two
// calls is the delay the file gives the frame just drawn, in a bucket of 20 ms. A gap printed to the
// microsecond would compare the scheduler, not ImageIO.
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

// Three bytes of the image's first pixel, so the frame the block was handed is identified by its content.
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

// One run of the data form. `calls` records land in the slots, `budget` is how long a run loop is given,
// and the return value of the function itself is recorded before the loop starts - the host returns before
// the first frame is drawn, so that order is part of what is being compared.
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
    // a block that is only called after the function returned is the host's shape; the port schedules it the
    // same way, and this records which it was without comparing a duration
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

// The same run, but reading the file through CGAnimateImageAtURLWithBlock. The file has to exist on disk,
// which is why run.sh writes the GIFs into its own build directory and passes that directory in.
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

#ifdef CHARON_PORT
        // the port's own object has to be what answers, which is proved here and not assumed: a weak
        // reference to a symbol the host exports would answer the host's
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
        // TWO CASES THE HOST HAS NO ANSWER FOR, because it does not survive them. They are the port's own
        // records and the harness's reason for saying so, with the measurement beside them:
        //
        //   a NULL block: the host answers 0 and then dies as soon as the run loop turns (measured
        //     2026-10-03: "returned 0", no spin printed, SIGSEGV), so there is no host answer to compare
        //     and this answers 0 and draws nothing.
        //   a kCGImageAnimationStartIndex at or past the frame count: the host answers 0 and then TRAPS
        //     (SIGTRAP, exit 133, measured for index 2 on a two-frame file and for index 9), which is the
        //     same shape. This answers 0 and draws nothing.
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

        // what the fixture files themselves say, which is what the animation reads: every frame's own delay
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

        // 1. one loop of a three-frame file whose frames declare 0.1, 0.3 and 0.5 seconds
        runData(@"three-loop-1", three, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        // 2. no loop count: the file wraps, and the block stops the animation at the sixth call
        runData(@"three-forever", three, nil, 4000);
        // 3. starting at the second frame
        runData(@"three-start-1", three,
                @{ (__bridge NSString *)kCGImageAnimationStartIndex : @1,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        // 4. a negative start index draws from 0
        runData(@"three-start-negative", three,
                @{ (__bridge NSString *)kCGImageAnimationStartIndex : @(-1),
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        // 5. two loops of the same file: six calls, and the sixth is the last index again
        runData(@"three-loop-2", three, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @2 }, 5000);
        // 6. one loop of a one-frame file: one call and the animation is over. Three loops of the same file
        //    is the case that says a one-frame source is played once and not looped.
        runData(@"one-loop-1", one, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 1000);
        runData(@"one-loop-3", one, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @3 }, 1000);
        runData(@"one-no-options", one, nil, 1000);
        // 7. the delay time option, asked for 0.02 and for 2.0 against the same file: the host ignores it
        //    and the gaps are the frame's own delays either way
        runData(@"three-option-0.02", three,
                @{ (__bridge NSString *)kCGImageAnimationDelayTime : @0.02,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runData(@"three-option-2.0", three,
                @{ (__bridge NSString *)kCGImageAnimationDelayTime : @2.0,
                   (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 5000);
        // 8. an empty options dictionary: no loop count, so the file wraps
        runData(@"three-empty-options", three, @{}, 3000);

        // 9. what is not an animation. A PNG, a JPEG and a THREE-FRAME TIFF are all refused with the same
        //    status and no call at all, so the frame count is not what decides it.
        runData(@"png", png, nil, 300);
        runData(@"three-frame-tiff", tiff, nil, 300);
        // 10. data that is not an image, and no data
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

        // 12. the URL form, for a file that is there and for ones that are not
        runURL(@"url-three", threePath, @{ (__bridge NSString *)kCGImageAnimationLoopCount : @1 }, 3000);
        runURL(@"url-missing", [build stringByAppendingPathComponent:@"no-such.gif"], nil, 300);
        runURL(@"url-null", nil, nil, 300);
        runURL(@"url-directory", build, nil, 300);

    }
    return 0;
}