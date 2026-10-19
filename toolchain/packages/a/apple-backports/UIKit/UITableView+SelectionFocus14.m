#import "CharonMenus.h"
#import <objc/runtime.h>

static const char charon_focus_selection_key;

@implementation UITableView (CharonSelectionFollowsFocus14)

- (BOOL)selectionFollowsFocus
{
    NSNumber *held = objc_getAssociatedObject(self, &charon_focus_selection_key);
    return held ? held.boolValue : NO;
}

- (void)setSelectionFollowsFocus:(BOOL)selectionFollowsFocus
{
    if (selectionFollowsFocus)
        charon_menus_say_once(@"table-selection-follows-focus", @"UITableView.selectionFollowsFocus: iOS 6 has no focus engine to move the selection with, so the value is kept and read back and the selection does not follow focus");
    objc_setAssociatedObject(self, &charon_focus_selection_key, @(selectionFollowsFocus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
