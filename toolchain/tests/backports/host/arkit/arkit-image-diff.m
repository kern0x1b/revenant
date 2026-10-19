#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <math.h>
#import "ARKitShim.h"

static int failures = 0;
static int checks = 0;
static void Check(BOOL ok, NSString *what)
{
    checks++;
    printf("  %-64s %s\n", what.UTF8String, ok ? "ok" : "FAIL");
    if (!ok) {
        failures++;
    }
}

static CGImageRef CharonPicture(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 0, space,
                                             kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(ctx, 0.2, 0.4, 0.6, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, width, height));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return image;
}

static BOOL Near(CGFloat got, CGFloat want)
{
    return fabs(got - want) < 1e-6;
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        printf("# transcript: a reference image's physical size, and the reading of a group\n");

        CGImageRef wide = CharonPicture(200, 100);
        ARReferenceImage *image = [[ARReferenceImage alloc] initWithCGImage:wide
                                                              orientation:kCGImagePropertyOrientationUp
                                                           physicalWidth:2.0];
        Check(image != nil, @"a picture and a width make a reference image");
        Check(Near(image.physicalSize.width, 2.0),
              @"a 2.0 m width is 2.0 m wide, whatever the picture");
        Check(Near(image.physicalSize.height, 1.0),
              @"and 200x100 is 2:1, so it is 1.0 m high");
        Check(Near(image.physicalSize.width / image.physicalSize.height, 2.0),
              @"the ratio is the picture's own, which is the whole of the arithmetic");

        CGImageRef tall = CharonPicture(100, 300);
        ARReferenceImage *other = [[ARReferenceImage alloc] initWithCGImage:tall
                                                              orientation:kCGImagePropertyOrientationUp
                                                           physicalWidth:1.5];
        Check(Near(other.physicalSize.height, 4.5),
              @"a 100x300 picture given 1.5 m is 4.5 m high, so the picture is really read");

        ARReferenceImage *widthless = [[ARReferenceImage alloc] initWithCGImage:wide
                                                                   orientation:kCGImagePropertyOrientationUp
                                                                physicalWidth:0];
        Check(widthless.physicalSize.width == 0 && widthless.physicalSize.height == 0,
              @"a width of zero gives no physical size at all, and not a default");

        ARReferenceImage *none = [[ARReferenceImage alloc] initWithCGImage:NULL
                                                             orientation:kCGImagePropertyOrientationUp
                                                          physicalWidth:2.0];
        Check(none == nil, @"a nil picture is nil, not an object that matches nothing");

        NSBundle *bundle = [NSBundle bundleWithPath:
                @"tests/backports/host/arkit/ARKitImageGroupFixture.bundle"];
        Check(bundle != nil, @"the fixture bundle is a bundle the host can read");
        NSSet<ARReferenceImage *> *group = [ARReferenceImage referenceImagesInGroupNamed:@"door"
                                                                                  bundle:bundle];
        Check(group.count == 1, @"the group holds the one image its Contents.json names");
        ARReferenceImage *door = group.anyObject;
        Check([door.name isEqualToString:@"door"], @"and the image is named after the group");
        Check(Near(door.physicalSize.width, 0.9), @"at the 0.9 m the Contents.json states");
        Check(Near(door.physicalSize.height, 1.8),
              @"and 1.8 m high, which is the 64x128 picture's 1:2 ratio");
        Check([door.resourceGroupName isEqualToString:@"door"],
              @"and it knows which group it came from, by the name the caller gave");

        Check([ARReferenceImage referenceImagesInGroupNamed:@"absent" bundle:bundle] == nil,
              @"a group that is not there is nil, not an empty set");

        Check(image.resourceGroupName == nil,
              @"an image the caller built is in no group");

        CGImageRelease(wide);
        CGImageRelease(tall);
        printf("# %d check(s), %d failure(s)\n", checks, failures);
        printf("\nVERDICT %s\n", failures ? "FAIL" : "ok");
        return failures ? 1 : 0;
    }
}
