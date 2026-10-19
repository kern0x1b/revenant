// Write the GIF and PNG fixtures both builds of the animation harness read, so the port and the host are
// asked about the same bytes. Built and run by run.sh, not by cases.m: a fixture written twice could be two
// files, and the whole comparison rests on the input being one.
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreServices/CoreServices.h>

static CGImageRef makeImage(unsigned char r)
{
    unsigned char px[8 * 8 * 4];
    for (size_t i = 0; i < sizeof px; i += 4) {
        px[i + 0] = r;
        px[i + 1] = (unsigned char)(255 - r);
        px[i + 2] = 128;
        px[i + 3] = 255;
    }
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CFDataRef d = CFDataCreate(NULL, px, sizeof px);
    CGDataProviderRef dp = CGDataProviderCreateWithCFData(d);
    CGImageRef img = CGImageCreate(8, 8, 8, 32, 32, cs, kCGImageAlphaPremultipliedLast, dp, NULL, false,
                                   kCGRenderingIntentDefault);
    CGColorSpaceRelease(cs);
    CGDataProviderRelease(dp);
    CFRelease(d);
    return img;
}

static BOOL writeFixture(NSString *path, CFStringRef type, NSArray *delays, BOOL withGIFDictionary)
{
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest =
        CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, type, delays.count, NULL);
    if (!dest) {
        printf("no destination for %s\n", path.lastPathComponent.UTF8String);
        return NO;
    }
    for (NSUInteger i = 0; i < delays.count; i++) {
        CGImageRef img = makeImage((unsigned char)(i * 40));
        NSDictionary *properties = nil;
        if (withGIFDictionary) {
            NSMutableDictionary *gif = [NSMutableDictionary dictionary];
            gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime] = delays[i];
            gif[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime] = delays[i];
            gif[(__bridge NSString *)kCGImagePropertyGIFLoopCount] = @0;
            properties = @{ (__bridge NSString *)kCGImagePropertyGIFDictionary : gif };
        }
        CGImageDestinationAddImage(dest, img, (__bridge CFDictionaryRef)properties);
        CGImageRelease(img);
    }
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    if (!ok) {
        printf("finalize failed for %s\n", path.lastPathComponent.UTF8String);
        return NO;
    }
    if (![data writeToFile:path atomically:YES]) {
        printf("write failed for %s\n", path.lastPathComponent.UTF8String);
        return NO;
    }
    printf("%s %lu bytes\n", path.lastPathComponent.UTF8String, (unsigned long)data.length);
    return YES;
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        NSString *build = argc > 1 ? @(argv[1]) : @"/tmp";
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:build withIntermediateDirectories:YES attributes:nil error:NULL];
        // the three-frame fixture: each frame its own delay, which is what the timing cases compare
        BOOL ok = writeFixture([build stringByAppendingPathComponent:@"three.gif"], kUTTypeGIF,
                        @[ @0.1, @0.3, @0.5 ], YES);
        ok = writeFixture([build stringByAppendingPathComponent:@"one.gif"], kUTTypeGIF, @[ @0.1 ], YES) && ok;
        ok = writeFixture([build stringByAppendingPathComponent:@"one.png"], kUTTypePNG, @[ @0.1 ], NO) && ok;
        // three pages and no GIF dictionary: the case that shows a frame count is not what decides
        ok = writeFixture([build stringByAppendingPathComponent:@"three.tiff"], kUTTypeTIFF, @[ @0.1, @0.1, @0.1 ], NO) && ok;
        if (!ok)
            return 1;
        // the fixtures have to be what the cases assume, or the comparison is of nothing: read the delays
        // back out of the file that was written
        CGImageSourceRef source = CGImageSourceCreateWithURL(
            (__bridge CFURLRef)[NSURL fileURLWithPath:[build stringByAppendingPathComponent:@"three.gif"]], NULL);
        if (!source) {
            printf("three.gif does not read back\n");
            return 1;
        }
        for (size_t i = 0; i < CGImageSourceGetCount(source); i++) {
            NSDictionary *properties =
                (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
            NSNumber *delay =
                properties[(__bridge NSString *)kCGImagePropertyGIFDictionary]
                          [(__bridge NSString *)kCGImagePropertyGIFDelayTime];
            printf("read back delay %lu = %s\n", (unsigned long)i, [delay description].UTF8String);
        }
        CFRelease(source);
    }
    return 0;
}