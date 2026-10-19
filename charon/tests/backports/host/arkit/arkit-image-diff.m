// A reference image's physical size, and the reading of a group: the two things about ARReferenceImage
// a host can measure without a camera.
//
// The physical size is pure arithmetic over a picture whose pixels are known, so a host can check it:
// a 200x100 picture given a width of 2.0 m is 2.0 m by 1.0 m, a 100x300 picture given 1.5 m is 4.5 m
// high, and a width of zero is no size at all rather than a default. Nothing here needs a frame, which
// is the point - it is the one number in the image-tracking family a host can answer.
//
// A group is a folder and a Contents.json, so a host can check the reading of one too: the fixture
// beside this file is a real .arreferenceimage with a real 64x128 PNG in it, and what comes back is
// that picture's own size and the width the file states.
//
// The two oracles are arithmetic and a file, which is why these are host differentials and not
// assertions about the framework's answer on hardware. What they cannot reach is validation, which is
// whether a session finds the thing in a frame, and trackingImages, which needs a configuration.
//
// The port's ARReferenceImage.m is compiled into this binary, so what runs is the port's code and not a
// re-implementation of it; ARKitShim.h declares the class, because ARKit has never shipped on macOS.
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

// A picture of a known size, built rather than loaded, so the numbers in the check and the numbers in
// the code come from the same place and a wrong size cannot cancel itself out.
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

// Within a tolerance, because the arithmetic is in floating point and 0.9 * 128 / 64 is not exactly
// 1.8. The tolerance is a millionth of a metre, which is a nanometre: the arithmetic can be that far
// out and no further, so a wrong formula cannot hide inside it.
static BOOL Near(CGFloat got, CGFloat want)
{
    return fabs(got - want) < 1e-6;
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        printf("# transcript: a reference image's physical size, and the reading of a group\n");

        // ---- physicalSize: the width the caller gave, and the picture's own aspect ratio ----
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

        // the ratio is the picture's and not a constant, so a different picture gives a different one
        CGImageRef tall = CharonPicture(100, 300);
        ARReferenceImage *other = [[ARReferenceImage alloc] initWithCGImage:tall
                                                              orientation:kCGImagePropertyOrientationUp
                                                           physicalWidth:1.5];
        Check(Near(other.physicalSize.height, 4.5),
              @"a 100x300 picture given 1.5 m is 4.5 m high, so the picture is really read");

        // and no width is no size: the framework's own signature is nonnull and a reference image with
        // no width is a picture a tracked shape can be measured against nothing
        ARReferenceImage *widthless = [[ARReferenceImage alloc] initWithCGImage:wide
                                                                   orientation:kCGImagePropertyOrientationUp
                                                                physicalWidth:0];
        Check(widthless.physicalSize.width == 0 && widthless.physicalSize.height == 0,
              @"a width of zero gives no physical size at all, and not a default");

        // and a nil picture is not a reference image at all, which is what the framework's nonnull
        // signature says and what the port answers
        ARReferenceImage *none = [[ARReferenceImage alloc] initWithCGImage:NULL
                                                             orientation:kCGImagePropertyOrientationUp
                                                          physicalWidth:2.0];
        Check(none == nil, @"a nil picture is nil, not an object that matches nothing");

        // ---- the group: a real folder, a real Contents.json, a real picture ----
        NSBundle *bundle = [NSBundle bundleWithPath:
                @"tests/backports/host/arkit/ARKitImageGroupFixture.bundle"];
        Check(bundle != nil, @"the fixture bundle is a bundle the host can read");
        NSSet<ARReferenceImage *> *group = [ARReferenceImage referenceImagesInGroupNamed:@"door"
                                                                                  bundle:bundle];
        Check(group.count == 1, @"the group holds the one image its Contents.json names");
        // Straight out of the set, with no copy: ARReferenceImage is not NSCopying - the 26.2 header
        // declares it as a plain NSObject - and a copy here would be the test asking the class for
        // something it does not carry, which is what the first run of this file did and what aborted
        // it: -[ARReferenceImage copyWithZone:] is not a selector this class has.
        ARReferenceImage *door = group.anyObject;
        Check([door.name isEqualToString:@"door"], @"and the image is named after the group");
        Check(Near(door.physicalSize.width, 0.9), @"at the 0.9 m the Contents.json states");
        Check(Near(door.physicalSize.height, 1.8),
              @"and 1.8 m high, which is the 64x128 picture's 1:2 ratio");
        Check([door.resourceGroupName isEqualToString:@"door"],
              @"and it knows which group it came from, by the name the caller gave");

        Check([ARReferenceImage referenceImagesInGroupNamed:@"absent" bundle:bundle] == nil,
              @"a group that is not there is nil, not an empty set");

        // an image built by the caller belongs to no group, which is what the header's nullable says
        Check(image.resourceGroupName == nil,
              @"an image the caller built is in no group");

        CGImageRelease(wide);
        CGImageRelease(tall);
        printf("# %d check(s), %d failure(s)\n", checks, failures);
        printf("\nVERDICT %s\n", failures ? "FAIL" : "ok");
        return failures ? 1 : 0;
    }
}