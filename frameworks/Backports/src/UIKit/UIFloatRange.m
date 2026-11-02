#include "../revenant_impl.h"
#import <UIKit/UIKit.h>
#include <float.h>
#include <math.h>

const UIFloatRange UIFloatRangeZero = {0, 0};
const UIFloatRange UIFloatRangeInfinite = {-INFINITY, INFINITY};

BOOL BACKPORT_IMPL(UIFloatRangeIsInfinite)(UIFloatRange range)
{
    return range.minimum <= -(double)FLT_MAX && range.maximum >= (double)FLT_MAX;
}
