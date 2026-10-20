#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 200000
const UIAccessibilityTraits UIAccessibilityTraitTabBar = 0x8000;
#else
UIAccessibilityTraits UIAccessibilityTraitTabBar = 0x8000;
#endif
const CGSize UICollectionViewFlowLayoutAutomaticSize = {CGFLOAT_MAX, CGFLOAT_MAX};
