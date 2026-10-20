#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_focus_selection_key;

@implementation UICollectionView (RevenantSelectionFollowsFocus14)

- (BOOL)selectionFollowsFocus
{
    NSNumber *held = objc_getAssociatedObject(self, &revenant_focus_selection_key);
    return held ? held.boolValue : NO;
}

- (void)setSelectionFollowsFocus:(BOOL)selectionFollowsFocus
{
    if (selectionFollowsFocus)
        revenant_menus_say_once(@"collection-selection-follows-focus", @"UICollectionView.selectionFollowsFocus: iOS 6 has no focus engine to move the selection with, so the value is kept and read back and the selection does not follow focus");
    objc_setAssociatedObject(self, &revenant_focus_selection_key, @(selectionFollowsFocus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
