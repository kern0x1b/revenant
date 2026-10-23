#import "../Foundation/check.h"
#import <SceneKit/SceneKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../../src/SceneKit/RevenantSCNActionMath.h"
#import "../../src/SceneKit/RevenantSCNMath.h"
#include <math.h>

static BOOL revenant_close(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

static void revenant_expect_curve(const char *name, SCNActionTimingMode mode, NSString *curve)
{
    CAMediaTimingFunction *apple = [CAMediaTimingFunction functionWithName:curve];
    float first[2], second[2];
    [apple getControlPointAtIndex:1 values:first];
    [apple getControlPointAtIndex:2 values:second];
    double ours[4];
    RevenantSCNActionTimingPoints(mode, ours);
    BOOL same = revenant_close(ours[0], first[0], 1e-6) && revenant_close(ours[1], first[1], 1e-6) &&
                revenant_close(ours[2], second[0], 1e-6) && revenant_close(ours[3], second[1], 1e-6);
    revenant_check(same, name, [NSString stringWithFormat:@"ours (%g %g %g %g) is not Apple's (%g %g %g %g)",
                                ours[0], ours[1], ours[2], ours[3], first[0], first[1], second[0], second[1]]);
}

static void revenant_expect_ease(const char *name, double value, double expected)
{
    revenant_check(revenant_close(value, expected, 1e-6), name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
}

static void revenant_expect_quaternion(const char *name, SCNQuaternion value, SCNQuaternion expected)
{
    BOOL same = revenant_close(value.x, expected.x, 1e-5) && revenant_close(value.y, expected.y, 1e-5) &&
                revenant_close(value.z, expected.z, 1e-5) && revenant_close(value.w, expected.w, 1e-5);
    BOOL opposite = revenant_close(value.x, -expected.x, 1e-5) && revenant_close(value.y, -expected.y, 1e-5) &&
                    revenant_close(value.z, -expected.z, 1e-5) && revenant_close(value.w, -expected.w, 1e-5);
    revenant_check(same || opposite, name, [NSString stringWithFormat:@"(%g %g %g %g) is not (%g %g %g %g) up to sign",
                                            value.x, value.y, value.z, value.w, expected.x, expected.y, expected.z, expected.w]);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);

        revenant_expect_curve("ease in curve matches CoreAnimation", SCNActionTimingModeEaseIn, kCAMediaTimingFunctionEaseIn);
        revenant_expect_curve("ease out curve matches CoreAnimation", SCNActionTimingModeEaseOut, kCAMediaTimingFunctionEaseOut);
        revenant_expect_curve("ease in ease out curve matches CoreAnimation", SCNActionTimingModeEaseInEaseOut, kCAMediaTimingFunctionEaseInEaseOut);
        revenant_expect_curve("linear curve matches CoreAnimation", SCNActionTimingModeLinear, kCAMediaTimingFunctionLinear);

        revenant_expect_ease("linear progress is the input", RevenantSCNActionEase(0.25, SCNActionTimingModeLinear), 0.25);
        revenant_expect_ease("ease curve starts at zero", RevenantSCNActionEase(0, SCNActionTimingModeEaseInEaseOut), 0);
        revenant_expect_ease("ease curve ends at one", RevenantSCNActionEase(1, SCNActionTimingModeEaseInEaseOut), 1);
        revenant_expect_ease("ease in ease out is symmetric at one half", RevenantSCNActionEase(0.5, SCNActionTimingModeEaseInEaseOut), 0.5);
        double low = RevenantSCNActionEase(0.25, SCNActionTimingModeEaseInEaseOut);
        double high = RevenantSCNActionEase(0.75, SCNActionTimingModeEaseInEaseOut);
        revenant_expect_ease("ease in ease out is point symmetric", low + high, 1);
        revenant_check(RevenantSCNActionEase(0.5, SCNActionTimingModeEaseIn) < 0.5, "ease in lags linear at one half",
                       @"ease in is not below one half");
        revenant_check(RevenantSCNActionEase(0.5, SCNActionTimingModeEaseOut) > 0.5, "ease out leads linear at one half",
                       @"ease out is not above one half");

        revenant_expect_ease("shortest arc crosses the wrap forward", RevenantSCNActionShortestAngle(170 * M_PI / 180, -170 * M_PI / 180), 20 * M_PI / 180);
        revenant_expect_ease("shortest arc crosses the wrap backward", RevenantSCNActionShortestAngle(-170 * M_PI / 180, 170 * M_PI / 180), -20 * M_PI / 180);
        revenant_expect_ease("shortest arc within half a turn is the difference", RevenantSCNActionShortestAngle(0.25, 0.75), 0.5);

        SCNQuaternion identity = SCNVector4Make(0, 0, 0, 1);
        SCNQuaternion quarter = RevenantSCNQuaternionFromAxisAngle(SCNVector4Make(1, 0, 0, M_PI / 2));
        SCNQuaternion half = RevenantSCNQuaternionFromAxisAngle(SCNVector4Make(1, 0, 0, M_PI));
        SCNQuaternion third = RevenantSCNQuaternionFromAxisAngle(SCNVector4Make(1, 0, 0, 2 * M_PI / 3));
        SCNQuaternion sixth = RevenantSCNQuaternionFromAxisAngle(SCNVector4Make(1, 0, 0, M_PI / 3));
        revenant_expect_quaternion("quarter turn twice is a half turn", RevenantSCNQuaternionMultiply(quarter, quarter), half);
        revenant_expect_quaternion("identity is neutral for multiply", RevenantSCNQuaternionMultiply(quarter, identity), quarter);
        revenant_expect_quaternion("slerp at zero is the start", RevenantSCNQuaternionSlerp(identity, third, 0), identity);
        revenant_expect_quaternion("slerp at one is the end", RevenantSCNQuaternionSlerp(identity, third, 1), third);
        revenant_expect_quaternion("slerp at one half is half the angle", RevenantSCNQuaternionSlerp(identity, third, 0.5), sixth);
    }
    return revenant_finish();
}
