// UIScrollView+KeyboardScrolling17.m - allowsKeyboardScrolling, the one UIScrollView property iOS 17.0
// added. It is in a file of its own, and separate from the 17.4 object next to it, because a .m holds
// ONE release's API: the release-split check reads band points only, so a file holding both 17.0 and
// 17.4 rows passes it and only a reader catches it.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M4): the property is
// gettable and settable on the host, and a fresh UIScrollView answers YES. So the default is YES here
// too, which is the row's whole claim - a scroll view scrolls when the keyboard appears, which is what
// this release has always done with no property to say so.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonAllowsKeyboardScrollingKey;

@implementation UIScrollView (CharonKeyboardScrolling17)

// The default is YES and not a stored zero, so a caller that reads the property before writing it gets
// the release's own behaviour rather than a value this file invented.
- (BOOL)allowsKeyboardScrolling
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonAllowsKeyboardScrollingKey);
    return stored ? stored.boolValue : YES;
}

- (void)setAllowsKeyboardScrolling:(BOOL)allowsKeyboardScrolling
{
    objc_setAssociatedObject(self, &CharonAllowsKeyboardScrollingKey,
                            @(allowsKeyboardScrolling), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end