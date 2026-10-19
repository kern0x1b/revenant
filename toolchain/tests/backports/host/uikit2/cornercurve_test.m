#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

extern NSString *const CharonHostkCACornerCurveCircular, *const CharonHostkCACornerCurveContinuous;

@interface CALayer (CharonHostCornerCurve)
- (NSString *)charonHostCornerCurve;
- (void)charonHostSetCornerCurve:(NSString *)cornerCurve;
@end

static double mismatch(CALayer *one, CALayer *two, CGSize size)
{
    CGFloat scale = 4;
    size_t w = (size_t)(size.width * scale), h = (size_t)(size.height * scale);
    unsigned char *a = calloc(w * h, 1), *b = calloc(w * h, 1);
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CALayer *layers[2] = {one, two};
    unsigned char *buffers[2] = {a, b};
    for (int index = 0; index < 2; index++) {
        CGContextRef context = CGBitmapContextCreate(buffers[index], w, h, 8, w, NULL, kCGImageAlphaOnly);
        CGContextTranslateCTM(context, 0, h);
        CGContextScaleCTM(context, scale, -scale);
        [layers[index] renderInContext:context];
        CGContextRelease(context);
    }
    CGColorSpaceRelease(gray);
    long differing = 0, covered = 0;
    for (size_t i = 0; i < w * h; i++) {
        covered += a[i] > 127;
        differing += (a[i] > 127) != (b[i] > 127);
    }
    free(a);
    free(b);
    return covered ? (double)differing / covered : 1;
}

int main(void)
{
    @autoreleasepool {
        for (NSValue *box in @[[NSValue valueWithCGSize:CGSizeMake(100, 100)], [NSValue valueWithCGSize:CGSizeMake(120, 60)], [NSValue valueWithCGSize:CGSizeMake(300, 44)]]) {
            CGSize size = box.CGSizeValue;
            for (NSNumber *radius in @[@6, @10, @16, @24, @40]) {
                CALayer *system = [CALayer layer], *ours = [CALayer layer];
                for (CALayer *layer in @[system, ours]) {
                    layer.frame = CGRectMake(0, 0, size.width, size.height);
                    layer.backgroundColor = [UIColor blackColor].CGColor;
                    layer.cornerRadius = radius.floatValue;
                    layer.masksToBounds = YES;
                }
                system.cornerCurve = kCACornerCurveContinuous;
                [ours charonHostSetCornerCurve:kCACornerCurveContinuous];
                double off = mismatch(system, ours, size);
                NSString *name = [NSString stringWithFormat:@"a continuous %gx%g layer with radius %@ covers the system's shape within 1.5%%: %.3f%%", size.width, size.height, radius, off * 100];
                CHECK(off < 0.015, name.UTF8String);
            }
        }

        CHECK_EQUAL(CharonHostkCACornerCurveCircular, kCACornerCurveCircular, "the circular constant");
        CHECK_EQUAL(CharonHostkCACornerCurveContinuous, kCACornerCurveContinuous, "the continuous constant");
        for (id value in @[kCACornerCurveContinuous, kCACornerCurveCircular, @"bogus", [NSNull null], @"", @"Continuous"]) {
            CALayer *ours = [CALayer layer], *theirs = [CALayer layer];
            CHECK_EQUAL([ours charonHostCornerCurve], theirs.cornerCurve, "a fresh layer starts as the system's");
            id given = [value isKindOfClass:[NSNull class]] ? nil : value;
            [ours charonHostSetCornerCurve:given];
            theirs.cornerCurve = given;
            NSString *first = [NSString stringWithFormat:@"a layer set to %@", value];
            CHECK_EQUAL([ours charonHostCornerCurve], theirs.cornerCurve, first.UTF8String);
            [ours charonHostSetCornerCurve:kCACornerCurveContinuous];
            theirs.cornerCurve = kCACornerCurveContinuous;
            [ours charonHostSetCornerCurve:given];
            theirs.cornerCurve = given;
            NSString *second = [NSString stringWithFormat:@"a continuous layer then set to %@", value];
            CHECK_EQUAL([ours charonHostCornerCurve], theirs.cornerCurve, second.UTF8String);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
