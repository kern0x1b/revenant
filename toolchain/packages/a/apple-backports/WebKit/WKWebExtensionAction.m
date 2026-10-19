#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtension.h"

@implementation WKWebExtensionAction {
    __weak WKWebExtensionContext *_webExtensionContext;
    __weak id<WKWebExtensionTab> _associatedTab;
    NSString *_label;
    NSString *_badgeText;
    NSString *_inspectionName;
    NSArray *_menuItems;
    UIImage *_icon;
    UIViewController *_popupViewController;
    BOOL _hasUnreadBadgeText;
    BOOL _enabled;
    BOOL _presentsPopup;
}

- (instancetype)charon_initWithContext:(WKWebExtensionContext *)context
{
    if ((self = [super init])) {
        _webExtensionContext = context;
        _menuItems = @[];
        _enabled = NO;
    }
    return self;
}

- (WKWebExtensionContext *)webExtensionContext
{
    return _webExtensionContext;
}

- (id<WKWebExtensionTab>)associatedTab
{
    return _associatedTab;
}

- (NSString *)label
{
    return _label;
}

- (NSString *)badgeText
{
    return _badgeText;
}

- (BOOL)hasUnreadBadgeText
{
    return _hasUnreadBadgeText;
}

- (void)setHasUnreadBadgeText:(BOOL)hasUnreadBadgeText
{
    _hasUnreadBadgeText = hasUnreadBadgeText;
}

- (NSString *)inspectionName
{
    return _inspectionName;
}

- (void)setInspectionName:(NSString *)inspectionName
{
    _inspectionName = [inspectionName copy];
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (NSArray<UIMenuElement *> *)menuItems
{
    return _menuItems;
}

- (BOOL)presentsPopup
{
    return _presentsPopup;
}

- (UIViewController *)popupViewController
{
    return _popupViewController;
}

- (WKWebView *)popupWebView
{
    return nil;
}

- (UIImage *)iconForSize:(CGSize)size
{
    return _icon;
}

- (void)closePopup
{
    _presentsPopup = NO;
    _popupViewController = nil;
}

- (void)charon_setLabel:(NSString *)label
              badgeText:(NSString *)badgeText
       inspectionName:(NSString *)inspectionName
             menuItems:(NSArray<UIMenuElement *> *)menuItems
                   icon:(UIImage *)icon
       presentsPopup:(BOOL)presentsPopup
  popupViewController:(UIViewController *)popupViewController
               enabled:(BOOL)enabled
{
    _label = [label copy];
    _badgeText = [badgeText copy];
    _inspectionName = [inspectionName copy];
    _menuItems = [menuItems copy] ?: @[];
    _icon = icon;
    _presentsPopup = presentsPopup;
    _popupViewController = popupViewController;
    _enabled = enabled;
    _hasUnreadBadgeText = badgeText.length > 0;
}

- (void)charon_setAssociatedTab:(id<WKWebExtensionTab>)tab
{
    _associatedTab = tab;
}

@end

@implementation WKWebExtensionCommand {
    __weak WKWebExtensionContext *_webExtensionContext;
    NSString *_identifier;
    NSString *_title;
    NSString *_activationKey;
    UIKeyModifierFlags _modifierFlags;
    UIMenuElement *_menuItem;
    UIKeyCommand *_keyCommand;
}

- (instancetype)charon_initWithContext:(WKWebExtensionContext *)context
                             identifier:(NSString *)identifier
                                  title:(NSString *)title
{
    if ((self = [super init])) {
        _webExtensionContext = context;
        _identifier = [identifier copy];
        _title = [title copy];
    }
    return self;
}

- (WKWebExtensionContext *)webExtensionContext
{
    return _webExtensionContext;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)title
{
    return _title;
}

- (NSString *)activationKey
{
    return _activationKey;
}

- (void)setActivationKey:(NSString *)activationKey
{
    [self charon_setActivationKey:activationKey menuItem:_menuItem];
}

- (UIKeyModifierFlags)modifierFlags
{
    return _modifierFlags;
}

- (void)setModifierFlags:(UIKeyModifierFlags)modifierFlags
{
    _modifierFlags = modifierFlags;
    if (_activationKey.length > 0)
        _keyCommand = [UIKeyCommand keyCommandWithInput:_activationKey modifierFlags:modifierFlags action:@selector(perform:)];
}

- (UIMenuElement *)menuItem
{
    return _menuItem;
}

- (UIKeyCommand *)keyCommand
{
    return _keyCommand;
}

- (void)charon_setActivationKey:(NSString *)activationKey menuItem:(UIMenuElement *)menuItem
{
    _activationKey = [activationKey copy];
    _menuItem = menuItem;
    if (_activationKey.length > 0)
        _keyCommand = [UIKeyCommand keyCommandWithInput:_activationKey modifierFlags:_modifierFlags action:@selector(perform:)];
}

@end
