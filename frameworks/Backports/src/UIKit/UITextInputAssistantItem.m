#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UITextInputAssistantItem (RevenantShortcutsBar)
- (void)revenant_attachToResponder:(UIResponder *)responder;
- (void)revenant_shortcutsDidChange;
@end

@implementation UITextInputAssistantItem {
    BOOL _allowsHidingShortcuts;
    NSArray<UIBarButtonItemGroup *> *_leadingBarButtonGroups;
    NSArray<UIBarButtonItemGroup *> *_trailingBarButtonGroups;
    __weak UIResponder *_owner;
    UIToolbar *_shortcutsBar;
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
    _leadingBarButtonGroups = [groups copy];
    [self revenant_shortcutsDidChange];
}

- (NSArray<UIBarButtonItemGroup *> *)trailingBarButtonGroups
{
    return _trailingBarButtonGroups;
}

- (void)setTrailingBarButtonGroups:(NSArray<UIBarButtonItemGroup *> *)groups
{
    _trailingBarButtonGroups = [groups copy];
    [self revenant_shortcutsDidChange];
}

- (void)revenant_attachToResponder:(UIResponder *)responder
{
    _owner = responder;
}

- (void)revenant_shortcutsDidChange
{
    UIResponder *owner = _owner;
    if (!owner || UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
        return;
    UIView *current = owner.inputAccessoryView;
    if (current && current != _shortcutsBar)
        return;
    UIView *bar = nil;
    if (_leadingBarButtonGroups.count || _trailingBarButtonGroups.count) {
        NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray array];
        for (UIBarButtonItemGroup *group in _leadingBarButtonGroups)
            [items addObjectsFromArray:group.barButtonItems];
        [items addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL]];
        for (UIBarButtonItemGroup *group in _trailingBarButtonGroups)
            [items addObjectsFromArray:group.barButtonItems];
        if (!_shortcutsBar) {
            _shortcutsBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 44)];
            _shortcutsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        }
        _shortcutsBar.items = items;
        bar = _shortcutsBar;
    } else {
        _shortcutsBar = nil;
    }
    if ([owner isKindOfClass:[UITextField class]])
        ((UITextField *)owner).inputAccessoryView = bar;
    else if ([owner isKindOfClass:[UITextView class]])
        ((UITextView *)owner).inputAccessoryView = bar;
    else
        return;
    [owner reloadInputViews];
}

@end

static const void *RevenantAssistantItemKey = &RevenantAssistantItemKey;

@implementation UIResponder (RevenantInputAssistantItem)

- (UITextInputAssistantItem *)inputAssistantItem
{
    UITextInputAssistantItem *item = objc_getAssociatedObject(self, RevenantAssistantItemKey);
    if (!item) {
        item = [[UITextInputAssistantItem alloc] init];
        [item revenant_attachToResponder:self];
        objc_setAssociatedObject(self, RevenantAssistantItemKey, item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return item;
}

@end
