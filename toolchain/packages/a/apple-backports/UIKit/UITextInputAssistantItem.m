#import "CharonMenus.h"
#import <objc/runtime.h>

static void charon_say_shortcuts(NSArray *groups)
{
    if (groups.count)
        charon_menus_say_once(@"input-assistant-groups", @"UITextInputAssistantItem.leadingBarButtonGroups and .trailingBarButtonGroups: iOS 6 draws no shortcuts bar over the keyboard, so the groups are kept and read back and nothing is shown");
}

@implementation UITextInputAssistantItem {
    BOOL _allowsHidingShortcuts;
    NSArray<UIBarButtonItemGroup *> *_leadingBarButtonGroups;
    NSArray<UIBarButtonItemGroup *> *_trailingBarButtonGroups;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _allowsHidingShortcuts = YES;
        _leadingBarButtonGroups = @[];
        _trailingBarButtonGroups = @[];
    }
    return self;
}

- (BOOL)allowsHidingShortcuts
{
    return _allowsHidingShortcuts;
}

- (void)setAllowsHidingShortcuts:(BOOL)allows
{
    _allowsHidingShortcuts = allows;
}

- (NSArray<UIBarButtonItemGroup *> *)leadingBarButtonGroups
{
    return _leadingBarButtonGroups;
}

- (void)setLeadingBarButtonGroups:(NSArray<UIBarButtonItemGroup *> *)groups
{
    charon_say_shortcuts(groups);
    _leadingBarButtonGroups = [groups copy];
}

- (NSArray<UIBarButtonItemGroup *> *)trailingBarButtonGroups
{
    return _trailingBarButtonGroups;
}

- (void)setTrailingBarButtonGroups:(NSArray<UIBarButtonItemGroup *> *)groups
{
    charon_say_shortcuts(groups);
    _trailingBarButtonGroups = [groups copy];
}

@end

static const void *CharonAssistantItemKey = &CharonAssistantItemKey;

@implementation UIResponder (CharonInputAssistantItem)

- (UITextInputAssistantItem *)inputAssistantItem
{
    UITextInputAssistantItem *item = objc_getAssociatedObject(self, CharonAssistantItemKey);
    if (!item) {
        item = [[UITextInputAssistantItem alloc] init];
        objc_setAssociatedObject(self, CharonAssistantItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return item;
}

@end
