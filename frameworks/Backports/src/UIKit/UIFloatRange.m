#include "../revenant_impl.h"
#import <UIKit/UIKit.h>
#include <float.h>
#include <math.h>

const UIFloatRange BACKPORT_IMPL(UIFloatRangeZero) = {0, 0};
const UIFloatRange BACKPORT_IMPL(UIFloatRangeInfinite) = {-INFINITY, INFINITY};

BOOL BACKPORT_IMPL(UIFloatRangeIsInfinite)(UIFloatRange range)
{
    return range.minimum <= -(double)FLT_MAX && range.maximum >= (double)FLT_MAX;
}
