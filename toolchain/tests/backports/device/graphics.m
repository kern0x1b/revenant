#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static UIColor *pixel_at(UIImage *image, int x, int y)
{
    uint8_t bytes[4] = {0, 0, 0, 0};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!space)
        space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes, 1, 1, 8, 4, space,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(space);
    if (!context)
        return nil;
    CGContextTranslateCTM(context, -x, -(image.size.height * image.scale - 1 - y));
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width * image.scale, image.size.height * image.scale),
                       image.CGImage);
    CGContextRelease(context);
    return [UIColor colorWithRed:bytes[2] / 255.0 green:bytes[1] / 255.0 blue:bytes[0] / 255.0 alpha:bytes[3] / 255.0];
}

static BOOL is_colour(UIColor *colour, CGFloat red, CGFloat green, CGFloat blue)
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (!colour || ![colour getRed:&r green:&g blue:&b alpha:&a])
        return NO;
    return fabs(r - red) < 0.02 && fabs(g - green) < 0.02 && fabs(b - blue) < 0.02;
}

static void run_checks(void)
{
    for (NSString *name in @[@"UIGraphicsRenderer", @"UIGraphicsRendererFormat", @"UIGraphicsRendererContext",
                             @"UIGraphicsImageRenderer", @"UIGraphicsImageRendererFormat",
                             @"UIGraphicsImageRendererContext"])
        CHECK_EQUAL(image_of(NSClassFromString(name)), @"libUIKitBackports.dylib",
                    [name stringByAppendingString:@" comes from the backports library"].UTF8String);

    UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
    CHECK(format.scale == [UIScreen mainScreen].scale, "a fresh format takes the screen's scale");
    CHECK(format.opaque == NO, "a fresh format is not opaque");
    CHECK([UIGraphicsImageRendererFormat defaultFormat].prefersExtendedRange == NO,
          "no armv7 device has deep colour, so the default format asks for no extended range");
    CHECK(![UIGraphicsImageRendererFormat instancesRespondToSelector:NSSelectorFromString(@"preferredRange")] &&
          ![UIGraphicsImageRendererFormat instancesRespondToSelector:NSSelectorFromString(@"setPreferredRange:")],
          "the iOS 12 preferred range is not there, since no context of this release is of extended range");

    format.scale = 2;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 10) format:format];
    CHECK(renderer.allowsImageOutput, "an image renderer allows image output");
    CHECK(CGRectEqualToRect(renderer.format.bounds, CGRectMake(0, 0, 20, 10)),
          "the renderer keeps its bounds on its own copy of the format");
    CHECK(CGRectEqualToRect(format.bounds, CGRectZero), "the format the caller kept is untouched");

    __block size_t seenWidth = 0, seenHeight = 0, seenBits = 0;
    __block CGColorSpaceModel seenModel = kCGColorSpaceModelUnknown;
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef seen = context.CGContext;
        seenWidth = CGBitmapContextGetWidth(seen);
        seenHeight = CGBitmapContextGetHeight(seen);
        seenBits = CGBitmapContextGetBitsPerComponent(seen);
        seenModel = CGColorSpaceGetModel(CGBitmapContextGetColorSpace(seen));
        CGContextSetRGBFillColor(context.CGContext, 1, 0, 0, 1);
        [context fillRect:CGRectMake(0, 0, 20, 10)];
        CGContextSetRGBFillColor(context.CGContext, 0, 0, 1, 1);
        [context fillRect:CGRectMake(0, 0, 5, 5)];
    }];
    CHECK(image != nil, "the renderer answers an image");
    CHECK(image.size.width == 20 && image.size.height == 10, "the image is the size asked for");
    CHECK(image.scale == 2, "the image carries the format's scale");
    CHECK(image.imageOrientation == UIImageOrientationUp, "the image is the right way up");
    CHECK(seenWidth == 40 && seenHeight == 20,
          "the bitmap is the size times the scale");
    CHECK(seenBits == 8, "the bitmap has eight bits a component");
    CHECK(seenModel == kCGColorSpaceModelRGB,
          "the bitmap is an RGB one");
    CHECK(is_colour(pixel_at(image, 30, 15), 1, 0, 0), "the fill reached the far corner");
    CHECK(is_colour(pixel_at(image, 2, 2), 0, 0, 1), "the second fill landed at the origin, y downwards");

    UIImage *opaqueImage = nil;
    format.opaque = YES;
    UIGraphicsImageRenderer *opaqueRenderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(4, 4) format:format];
    opaqueImage = [opaqueRenderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSetRGBFillColor(context.CGContext, 0, 1, 0, 1);
        [context fillRect:CGRectMake(0, 0, 4, 4)];
    }];
    CHECK(is_colour(pixel_at(opaqueImage, 1, 1), 0, 1, 0), "an opaque renderer draws");

    NSData *png = [renderer PNGDataWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextSetRGBFillColor(context.CGContext, 0, 1, 0, 1);
        [context fillRect:CGRectMake(0, 0, 20, 10)];
    }];
    CHECK(png.length > 8, "the renderer answers PNG data");
    CHECK(png.length > 8 && memcmp(png.bytes, "\x89PNG", 4) == 0, "the data really is a PNG");
    NSData *jpeg = [renderer JPEGDataWithCompressionQuality:0.8 actions:^(UIGraphicsImageRendererContext *context) {
        CGContextSetRGBFillColor(context.CGContext, 0, 1, 0, 1);
        [context fillRect:CGRectMake(0, 0, 20, 10)];
    }];
    CHECK(jpeg.length > 4 && memcmp(jpeg.bytes, "\xff\xd8", 2) == 0, "the renderer answers JPEG data");

    __block BOOL ran = NO;
    UIGraphicsImageRenderer *nothing = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeZero];
    UIImage *empty = [nothing imageWithActions:^(UIGraphicsImageRendererContext *context) { ran = YES; }];
    CHECK(!ran, "a renderer of no size cannot make a context, so it runs no drawing block");
    CHECK(empty != nil, "a renderer of no size answers an empty image, never nil");
    CHECK(empty.size.width == 0 && empty.size.height == 0, "that image has no size");
    NSData *emptyData = [nothing PNGDataWithActions:^(UIGraphicsImageRendererContext *context) { }];
    CHECK(emptyData != nil && emptyData.length == 0, "a renderer of no size answers empty data, never nil");
}

@interface CharonGraphicsDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonGraphicsDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"graphics.log"]);
    @try {
        run_checks();
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception",
                     [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n",
                                                   charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"graphics.done"]
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder
                                  withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonGraphicsDelegate");
    }
}
