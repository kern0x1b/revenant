#import <UIKit/UIKit.h>

// 16.4/16.5's header declares this plainly (no const, measured: UIAccessibilityConstants.h:106); 26.2's
// declares it const (same file, same line, measured). See UIAccessibility+Settings.m for the same split
// on two neighbouring constants, why 200000 (not one of the two measured __IPHONE_OS_VERSION_MAX_ALLOWED
// values, 160400/260200) is still a safe threshold, and what re-measuring it needs if a third SDK arrives.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 200000
const UIAccessibilityTraits UIAccessibilityTraitTabBar = 0x8000;
#else
UIAccessibilityTraits UIAccessibilityTraitTabBar = 0x8000;
#endif
const CGSize UICollectionViewFlowLayoutAutomaticSize = {CGFLOAT_MAX, CGFLOAT_MAX};
