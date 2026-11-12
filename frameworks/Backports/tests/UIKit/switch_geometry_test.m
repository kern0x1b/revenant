#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "RevenantSwitchGeometry.h"
#import "check.h"

typedef struct {
    size_t width;
    size_t height;
    size_t row;
    unsigned char *bytes;
} Pixels;

static Pixels pixels_of(CGImageRef image)
{
    Pixels pixels = {CGImageGetWidth(image), CGImageGetHeight(image), CGImageGetWidth(image) * 4, NULL};
    pixels.bytes = calloc(pixels.row * pixels.height, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels.bytes, pixels.width, pixels.height, 8, pixels.row, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, pixels.width, pixels.height), image);
    CGContextRelease(context);
    return pixels;
}

static const unsigned char *pixel(Pixels pixels, size_t x, size_t y)
{
    return pixels.bytes + y * pixels.row + x * 4;
}

static void expect_near(double value, double expected, double tolerance, const char *name)
{
    revenant_check(fabs(value - expected) <= tolerance, name, [NSString stringWithFormat:@"%g is not %g within %g", value, expected, tolerance]);
}

static void expect_rect(CGRect value, CGRect expected, const char *name)
{
    revenant_check(CGRectEqualToRect(value, expected), name, [NSString stringWithFormat:@"%@ is not %@", NSStringFromRect(NSRectFromCGRect(value)), NSStringFromRect(NSRectFromCGRect(expected))]);
}

static void expect_point(CGPoint value, CGPoint expected, const char *name)
{
    revenant_check(CGPointEqualToPoint(value, expected), name, [NSString stringWithFormat:@"%@ is not %@", NSStringFromPoint(NSPointFromCGPoint(value)), NSStringFromPoint(NSPointFromCGPoint(expected))]);
}

static void expect_bool(bool value, bool expected, const char *name)
{
    revenant_check(value == expected, name, [NSString stringWithFormat:@"%d is not %d", value, expected]);
}

static void check_geometry(void)
{
    revenant_check(CGSizeEqualToSize(RevenantSwitchSize, CGSizeMake(51, 31)), "the switch is 51 by 31", NSStringFromSize(NSSizeFromCGSize(RevenantSwitchSize)));
    expect_rect(RevenantSwitchKnobBounds(false), CGRectMake(0, 0, 43, 43), "the knob image is 43 by 43");
    expect_rect(RevenantSwitchKnobBounds(true), CGRectMake(0, 0, 50, 43), "a pressed knob is 7 points wider");
    expect_point(RevenantSwitchKnobPosition(false, false), CGPointMake(15.5, 18.5), "the knob of an off switch");
    expect_point(RevenantSwitchKnobPosition(true, false), CGPointMake(35.5, 18.5), "the knob of an on switch");
    expect_point(RevenantSwitchKnobPosition(false, true), CGPointMake(19, 18.5), "the pressed knob of an off switch");
    expect_point(RevenantSwitchKnobPosition(true, true), CGPointMake(revenant_negative ? 35.5 : 32, 18.5), "the pressed knob of an on switch");
    expect_rect(RevenantSwitchWellFrame(false), CGRectMake(-459, 0, 510, 31), "the well of an off switch is left of the track");
    expect_rect(RevenantSwitchWellFrame(true), CGRectMake(0, 0, 510, 31), "the well of an on switch covers the track");
    CGRect center = RevenantSwitchKnobContentsCenter();
    expect_near(center.origin.x * 43, 21, 1e-9, "the knob stretches at its middle column");
    expect_near(center.size.width * 43, 1, 1e-9, "the knob stretches one point");
}

static void check_well(void)
{
    expect_near(RevenantSwitchWellAlpha(0), 1, 1e-9, "the well is opaque at its start");
    expect_near(RevenantSwitchWellAlpha(51), 1, 1e-9, "the well is opaque over the first track width");
    expect_near(RevenantSwitchWellAlpha(150), 193.0 / 255, 1.0 / 255, "the well at 150 points");
    expect_near(RevenantSwitchWellAlpha(250), 130.0 / 255, 1.0 / 255, "the well at 250 points");
    expect_near(RevenantSwitchWellAlpha(450), 5.0 / 255, 1.0 / 255, "the well at 450 points");
    expect_near(RevenantSwitchWellAlpha(459), 0, 1e-9, "the well is clear over the last track width");

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    const CGFloat red[4] = {1, 0, 0, 1};
    CGColorRef color = CGColorCreate(space, red);
    CGColorSpaceRelease(space);
    CGImageRef image = RevenantSwitchWellImageCreate(color, 2);
    CGColorRelease(color);
    revenant_check(CGImageGetWidth(image) == 1020 && CGImageGetHeight(image) == 1, "the well image is 510 by 1 points at scale 2", [NSString stringWithFormat:@"%zu x %zu", CGImageGetWidth(image), CGImageGetHeight(image)]);
    Pixels pixels = pixels_of(image);
    CGImageRelease(image);
    size_t columns[] = {0, 300, 600, 900, 1019};
    int alphas[] = {255, 193, 99, 5, 0};
    for (size_t index = 0; index < sizeof(columns) / sizeof(*columns); index++) {
        const unsigned char *value = pixel(pixels, columns[index], 0);
        char name[64];
        snprintf(name, sizeof(name), "the well image at pixel %zu", columns[index]);
        expect_near(value[3], alphas[index], 2, name);
        expect_near(value[0], value[3], 1, "the well image is the colour premultiplied by the ramp");
    }
    free(pixels.bytes);
}

static Pixels knob_pixels(bool on)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    const CGFloat white[4] = {1, 1, 1, 1};
    CGColorRef color = CGColorCreate(space, white);
    CGColorSpaceRelease(space);
    CGImageRef image = RevenantSwitchKnobImageCreate(color, 2, on);
    CGColorRelease(color);
    revenant_check(CGImageGetWidth(image) == 86 && CGImageGetHeight(image) == 86, "the knob image is 43 points at scale 2", [NSString stringWithFormat:@"%zu x %zu", CGImageGetWidth(image), CGImageGetHeight(image)]);
    Pixels pixels = pixels_of(image);
    CGImageRelease(image);
    return pixels;
}

static void check_knob(void)
{
    expect_rect(RevenantSwitchKnobTrackRect(false), CGRectMake(6, 3, 51, 31), "the track in the image of an off knob");
    expect_rect(RevenantSwitchKnobTrackRect(true), CGRectMake(-14, 3, 51, 31), "the track in the image of an on knob");
    Pixels off = knob_pixels(false);
    struct {
        size_t x, y;
        int alpha;
        const char *name;
    } samples[] = {
        {43, 37, 255, "the knob is opaque white at its centre"},
        {16, 37, 249, "the left edge of the knob"},
        {69, 37, 249, "the right edge of the knob"},
        {43, 10, 249, "the top edge of the knob"},
        {43, 63, 249, "the bottom edge of the knob"},
        {15, 37, 12, "the shadow beside the knob"},
        {13, 37, 9, "the shadow one point beside the knob"},
        {77, 37, 2, "the shadow four points beside the knob, inside the track"},
        {43, 9, 4, "the shadow above the knob"},
        {43, 64, revenant_negative ? 0 : 23, "the shadow under the knob"},
        {43, 67, 17, "the shadow two points under the knob"},
        {43, 68, 0, "the shadow ends at the bottom of the track"},
        {8, 37, 0, "no shadow left of the track"},
        {25, 63, 0, "no shadow outside the curve of the track"},
        {0, 0, 0, "the corner of the image is clear"},
    };
    for (size_t index = 0; index < sizeof(samples) / sizeof(*samples); index++) {
        const unsigned char *value = pixel(off, samples[index].x, samples[index].y);
        expect_near(value[3], samples[index].alpha, 2, samples[index].name);
    }
    const unsigned char *shadow = pixel(off, 43, 64);
    revenant_check(shadow[0] == 0 && shadow[1] == 0 && shadow[2] == 0, "the shadow is black", [NSString stringWithFormat:@"%d %d %d", shadow[0], shadow[1], shadow[2]]);
    Pixels on = knob_pixels(true);
    expect_near(pixel(on, 8, 37)[3], 2, 2, "the on knob keeps the shadow on its left, inside the track");
    expect_near(pixel(on, 77, 37)[3], 0, 0, "no shadow right of the track of an on knob");
    expect_near(pixel(on, 60, 63)[3], 0, 0, "no shadow outside the right curve of the track");
    expect_near(pixel(on, 43, 64)[3], 23, 2, "the on knob has the same shadow under it");
    free(off.bytes);
    free(on.bytes);
}

static void check_tracking(void)
{
    RevenantSwitchTracking tracking;
    RevenantSwitchTrackingBegin(&tracking, false, 20);
    expect_bool(RevenantSwitchTrackingEnd(&tracking, true), true, "a tap turns an off switch on");
    RevenantSwitchTrackingBegin(&tracking, true, 20);
    expect_bool(RevenantSwitchTrackingEnd(&tracking, true), false, "a tap turns an on switch off");
    RevenantSwitchTrackingBegin(&tracking, true, 20);
    expect_bool(RevenantSwitchTrackingEnd(&tracking, false), true, "a touch that ends outside leaves the switch");
    RevenantSwitchTrackingBegin(&tracking, false, 20);
    expect_bool(RevenantSwitchTrackingMove(&tracking, 28), false, "a move within the slop is still a tap");
    expect_bool(RevenantSwitchTrackingEnd(&tracking, true), true, "a tap that moved a little still toggles");

    RevenantSwitchTrackingBegin(&tracking, false, 10);
    expect_bool(RevenantSwitchTrackingMove(&tracking, 35), false, "a drag of 25 points does not flip an off switch");
    expect_bool(RevenantSwitchTrackingMove(&tracking, 35.5), true, "a drag of half the width flips an off switch on");
    expect_bool(tracking.displayedOn, true, "the dragged switch shows on");
    expect_bool(RevenantSwitchTrackingMove(&tracking, 40), false, "further right stays on");
    expect_bool(RevenantSwitchTrackingMove(&tracking, 10.5), false, "the way back is measured from the flip");
    expect_bool(RevenantSwitchTrackingMove(&tracking, 10), true, "half the width back flips it off");
    expect_bool(RevenantSwitchTrackingEnd(&tracking, true), false, "a drag ends where it shows");

    RevenantSwitchTrackingBegin(&tracking, true, 40);
    expect_bool(RevenantSwitchTrackingMove(&tracking, 14.5), true, "a drag of half the width to the left flips an on switch off");
    expect_bool(RevenantSwitchTrackingEnd(&tracking, false), false, "a drag that ends outside still ends where it shows");
    RevenantSwitchTrackingBegin(&tracking, true, 40);
    expect_bool(RevenantSwitchTrackingMove(&tracking, 60), false, "dragging an on switch right does nothing");
    expect_bool(RevenantSwitchTrackingEnd(&tracking, true), true, "a drag without a flip keeps the value");
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        check_geometry();
        check_well();
        check_knob();
        check_tracking();
    }
    return revenant_finish();
}
