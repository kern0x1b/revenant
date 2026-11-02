#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 200000
const UIAccessibilityTraits BACKPORT_IMPL(UIAccessibilityTraitTabBar) = 0x8000;
#else
UIAccessibilityTraits BACKPORT_IMPL(UIAccessibilityTraitTabBar) = 0x8000;
#endif
const CGSize BACKPORT_IMPL(UICollectionViewFlowLayoutAutomaticSize) = {CGFLOAT_MAX, CGFLOAT_MAX};
