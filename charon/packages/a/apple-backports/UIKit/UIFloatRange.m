#import <UIKit/UIKit.h>
#include <float.h>
#include <math.h>

// UIFloatRange's exported data and its one exported function (9.0), for UIAttachmentBehavior's attachmentRange
// (facts/UIKit/UIDynamicAnimator.md §6.4). UIFloatRangeMake and UIFloatRangeIsEqualToRange are static inline in the
// header and have no symbol to carry. A file of their own: the 7.0 attachment's file is left out of the bands whose
// release has the 7.0 classes, and these are needed there too.

const UIFloatRange UIFloatRangeZero = {0, 0};
const UIFloatRange UIFloatRangeInfinite = {-INFINITY, INFINITY};

// The host's test, not "both ends infinite": the minimum at most -FLT_MAX and the maximum at least FLT_MAX, both as
// double, so {-1e39, 1e39} is infinite and a NaN at either end is not (host listing of UIFloatRangeIsInfinite: fcmp
// with -3.4028234663852886e38, cset ls; fcmp with 3.4028234663852886e38, csel lt, which an unordered compare takes).
BOOL UIFloatRangeIsInfinite(UIFloatRange range)
{
    return range.minimum <= -(double)FLT_MAX && range.maximum >= (double)FLT_MAX;
}
