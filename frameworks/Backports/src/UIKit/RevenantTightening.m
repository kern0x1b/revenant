#import "RevenantTightening.h"

static const double REVENANT_MAX_TIGHTENING_PER_GAP = 0.05;

BOOL revenant_tightening_kern(double width, double available, double pointSize, NSUInteger gaps, double *kern)
{
    *kern = 0;
    if (width <= available || gaps == 0 || pointSize <= 0)
        return NO;
    double delta = (available - width) / (double)gaps;
    if (-delta > REVENANT_MAX_TIGHTENING_PER_GAP * pointSize)
        return NO;
    *kern = delta;
    return YES;
}
