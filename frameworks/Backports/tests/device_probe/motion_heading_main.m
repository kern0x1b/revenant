#import <CoreMotion/CoreMotion.h>
#include <math.h>
#import "check.h"
#import "RevenantMotionHeading.h"

void RevenantTagDeviceMotion(CMDeviceMotion *motion, CMAttitudeReferenceFrame frame);

static CMDeviceMotion *revenant_first_motion(CMMotionManager *manager, CMAttitudeReferenceFrame frame, int *delivered)
{
    __block CMDeviceMotion *first = nil;
    __block int count = 0;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    manager.deviceMotionUpdateInterval = 0.05;
    [manager startDeviceMotionUpdatesUsingReferenceFrame:frame toQueue:queue withHandler:^(CMDeviceMotion *motion, NSError *error) {
        if (motion && !first) {
            first = motion;
        }
        if (motion) {
            count++;
        }
    }];
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while ([until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    CMDeviceMotion *result = first;
    int total = count;
    [manager stopDeviceMotionUpdates];
    if (delivered) {
        *delivered = total;
    }
    return result;
}

int main(void)
{
    @autoreleasepool {
        revenant_check([CMDeviceMotion instancesRespondToSelector:@selector(heading)], "CMDeviceMotion answers heading", @"no heading selector");

        CMMotionManager *manager = [[CMMotionManager alloc] init];
        int delivered = 0;
        CMDeviceMotion *live = revenant_first_motion(manager, CMAttitudeReferenceFrameXArbitraryZVertical, &delivered);
        revenant_check(live != nil && delivered >= 5, "the wrapped start method still delivers motion", [NSString stringWithFormat:@"%d delivered", delivered]);
        if (!live) {
            return revenant_finish();
        }

        CMRotationMatrix m = live.attitude.rotationMatrix;
        CMAcceleration g = live.gravity;
        double drift = fabs(g.x + m.m13) + fabs(g.y + m.m23) + fabs(g.z + m.m33);
        revenant_check(drift < 0.15, "gravity equals minus the third column of the rotation matrix, so the matrix maps the reference frame to the device", [NSString stringWithFormat:@"gravity %.3f %.3f %.3f column %.3f %.3f %.3f", g.x, g.y, g.z, m.m13, m.m23, m.m33]);
        double transposed = fabs(g.x + m.m31) + fabs(g.y + m.m32) + fabs(g.z + m.m33);
        revenant_check(transposed > drift, "the transposed reading of the matrix fits gravity worse", [NSString stringWithFormat:@"%.3f against %.3f", transposed, drift]);

        revenant_check(live.heading == -1.0, "a motion in an arbitrary frame has no heading", [NSString stringWithFormat:@"%f", live.heading]);

        if ([CMMotionManager availableAttitudeReferenceFrames] & CMAttitudeReferenceFrameXArbitraryCorrectedZVertical) {
            CMDeviceMotion *corrected = revenant_first_motion(manager, CMAttitudeReferenceFrameXArbitraryCorrectedZVertical, NULL);
            revenant_check(corrected != nil && corrected.heading == -1.0, "a motion in the corrected arbitrary frame has no heading", corrected ? [NSString stringWithFormat:@"%f", corrected.heading] : @"no motion");
        }

        [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        CMDeviceMotion *polled = manager.deviceMotion;
        revenant_check(polled != nil && polled.heading == -1.0, "a polled motion in an arbitrary frame has no heading", polled ? [NSString stringWithFormat:@"%f", polled.heading] : @"no motion");
        [manager stopDeviceMotionUpdates];

        CMDeviceMotion *copy = [live copy];
        revenant_check(copy != nil && copy.heading == -1.0, "a copy of an untagged motion has no heading", @"copy failed");

        RevenantTagDeviceMotion(live, CMAttitudeReferenceFrameXMagneticNorthZVertical);
        double expected = RevenantMotionHeadingDegrees(m.m21, m.m22, m.m23, m.m31, m.m32, m.m33);
        double tagged = live.heading;
        revenant_check(tagged >= 0.0 && tagged < 360.0 && fabs(tagged - expected) < 1e-9, "a motion tagged with the magnetic north frame reads the heading of its attitude", [NSString stringWithFormat:@"%f against %f", tagged, expected]);

        CMDeviceMotion *tagged_copy = [live copy];
        revenant_check(tagged_copy != nil && fabs(tagged_copy.heading - expected) < 1e-9, "a copy keeps the frame of its original", tagged_copy ? [NSString stringWithFormat:@"%f against %f", tagged_copy.heading, expected] : @"copy failed");

        RevenantTagDeviceMotion(live, CMAttitudeReferenceFrameXTrueNorthZVertical);
        revenant_check(fabs(live.heading - expected) < 1e-9, "the true north frame reads the same way", [NSString stringWithFormat:@"%f", live.heading]);

        RevenantTagDeviceMotion(live, CMAttitudeReferenceFrameXArbitraryCorrectedZVertical);
        revenant_check(live.heading == -1.0, "retagging to an arbitrary frame removes the heading", [NSString stringWithFormat:@"%f", live.heading]);

        for (int index = 0; index < 2000; index++) {
            @autoreleasepool {
                CMDeviceMotion *again = [live copy];
                RevenantTagDeviceMotion(again, CMAttitudeReferenceFrameXMagneticNorthZVertical);
                (void)again.heading;
            }
        }
        revenant_check(YES, "two thousand copies are released", @"");
    }
    return revenant_finish();
}
