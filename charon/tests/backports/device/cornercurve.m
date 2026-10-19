#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#import <UIKit/UIKit.h>
#import "check.h"

static const double charon_areas[][4] = {
{100, 100, 6, 159452},
{100, 100, 10, 158496},
{100, 100, 16, 156204},
{100, 100, 24, 151568},
{100, 100, 40, 136700},
{120, 60, 6, 114652},
{120, 60, 10, 113696},
{120, 60, 16, 111404},
{120, 60, 24, 106772},
{120, 60, 40, 93280},
{300, 44, 6, 210652},
{300, 44, 10, 209696},
{300, 44, 16, 207404},
{300, 44, 24, 202920},
{300, 44, 40, 192220},
};


int main(void)
{
    @autoreleasepool {
        Dl_info info;
        CHECK(dladdr(&kCACornerCurveContinuous, &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), "the corner curve constants come from the backports library");
        CHECK_EQUAL(kCACornerCurveCircular, @"circular", "the circular constant");
        CHECK_EQUAL(kCACornerCurveContinuous, @"continuous", "the continuous constant");
        CALayer *layer = [CALayer layer];
        CHECK_EQUAL(layer.cornerCurve, kCACornerCurveCircular, "a layer starts circular");
        layer.cornerCurve = kCACornerCurveContinuous;
        CHECK_EQUAL(layer.cornerCurve, kCACornerCurveContinuous, "and keeps continuous");
        CHECK_EQUAL([layer valueForKey:@"cornerCurve"], kCACornerCurveContinuous, "also through key-value coding");
        layer.cornerCurve = @"bogus";
        CHECK_EQUAL(layer.cornerCurve, kCACornerCurveCircular, "a value that is no curve makes it circular");
        layer.cornerCurve = kCACornerCurveContinuous;
        layer.cornerCurve = nil;
        CHECK_EQUAL(layer.cornerCurve, kCACornerCurveCircular, "and so does nil");
        for (size_t index = 0; index < sizeof charon_areas / sizeof charon_areas[0]; index++) {
            CALayer *shaped = [CALayer layer];
            shaped.frame = CGRectMake(0, 0, charon_areas[index][0], charon_areas[index][1]);
            shaped.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
            shaped.cornerRadius = charon_areas[index][2];
            shaped.masksToBounds = YES;
            shaped.cornerCurve = kCACornerCurveContinuous;
            size_t w = (size_t)(charon_areas[index][0] * 4), h = (size_t)(charon_areas[index][1] * 4);
            unsigned char *pixels = calloc(w * h, 1);
            CGContextRef context = CGBitmapContextCreate(pixels, w, h, 8, w, NULL, kCGImageAlphaOnly);
            CGContextTranslateCTM(context, 0, h);
            CGContextScaleCTM(context, 4, -4);
            [shaped renderInContext:context];
            double covered = 0;
            for (size_t i = 0; i < w * h; i++)
                covered += pixels[i] > 127;
            CGContextRelease(context);
            free(pixels);
            NSString *name = [NSString stringWithFormat:@"a continuous %gx%g layer with radius %g covers what the system's does (%g against %g)", charon_areas[index][0], charon_areas[index][1], charon_areas[index][2], covered, charon_areas[index][3]];
            CHECK(shaped.mask != nil && fabs(covered - charon_areas[index][3]) < 0.015 * charon_areas[index][3], name.UTF8String);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
