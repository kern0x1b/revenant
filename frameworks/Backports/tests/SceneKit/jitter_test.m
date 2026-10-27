#import "../Foundation/check.h"
#import "../../src/SceneKit/RevenantSCNJitter.h"
#include <math.h>

static BOOL revenant_near(double value, double expected, double tolerance)
{
    return fabs(value - expected) <= tolerance;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        NSUInteger count = [RevenantSCNJitter sampleCount];
        revenant_check(count == 8, "the jitter cycles through eight samples", [NSString stringWithFormat:@"the cycle is %lu samples", (unsigned long)count]);

        BOOL inside = YES;
        float sumX = 0, sumY = 0;
        for (NSUInteger frame = 0; frame < count; frame++) {
            float x = 0, y = 0;
            [RevenantSCNJitter offsetForFrame:frame x:&x y:&y];
            inside = inside && x >= -0.5f && x < 0.5f && y >= -0.5f && y < 0.5f;
            sumX += x;
            sumY += y;
        }
        revenant_check(inside, "every sample lies within half a pixel of the pixel centre", @"a sample lies outside half a pixel");
        revenant_check(revenant_near(sumX / count, 0, 0.1) && revenant_near(sumY / count, 0, 0.1), "the samples are centred on the pixel", @"the samples are biased away from the pixel centre");

        float x0 = 0, y0 = 0, x8 = 0, y8 = 0, x1 = 0, y1 = 0;
        [RevenantSCNJitter offsetForFrame:0 x:&x0 y:&y0];
        [RevenantSCNJitter offsetForFrame:count x:&x8 y:&y8];
        [RevenantSCNJitter offsetForFrame:1 x:&x1 y:&y1];
        revenant_check(x0 == x8 && y0 == y8, "frame eight repeats the first sample", @"frame eight differs from frame zero");
        revenant_check(x0 != x1 || y0 != y1, "consecutive frames take different samples", @"consecutive frames take the same sample");

        revenant_check(revenant_near([RevenantSCNJitter weightForAccumulated:0], 1, 1e-6), "the first sample replaces the buffer", @"the first sample does not replace the buffer");
        revenant_check(revenant_near([RevenantSCNJitter weightForAccumulated:1], 0.5, 1e-6), "the second sample is blended half and half", @"the second sample is not blended half and half");
        revenant_check(revenant_near([RevenantSCNJitter weightForAccumulated:3], 0.25, 1e-6), "the fourth sample has weight a quarter", @"the fourth sample weight is wrong");

        double accumulated = 0;
        double values[8] = {1, 2, 3, 4, 5, 6, 7, 8};
        for (NSUInteger index = 0; index < count; index++) {
            float weight = [RevenantSCNJitter weightForAccumulated:index];
            accumulated = index == 0 ? values[0] : weight * values[index] + (1 - weight) * accumulated;
        }
        revenant_check(revenant_near(accumulated, 4.5, 1e-4), "the blended buffer is the mean of the samples", [NSString stringWithFormat:@"the blend is %g, not 4.5", accumulated]);

        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
