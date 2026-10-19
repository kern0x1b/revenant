#pragma clang diagnostic ignored "-Wnullability-completeness"
#import "CharonWebExtension.h"

/* WKWebExtensionAction and WKWebExtensionCommand: what a web extension's toolbar button and its
 * keyboard commands ARE, as two value holders.
 *
 * Neither can be made by a program, and that is measured rather than read: both headers mark -init and
 * +new NS_UNAVAILABLE, and the host agrees when asked -- [WKWebExtensionAction alloc] and
 * [WKWebExtensionCommand alloc] both answer an object and neither -init is reachable. A CONTEXT hands
 * them out, because a button and a shortcut only mean something against a loaded extension and the
 * tabs it is acting on. So this file carries the two classes and their members, and takes its values
 * from the context that will build them; the port's own initialiser is charon_-prefixed and is what
 * WKWebExtensionContext calls, for the same reason the extension's is.
 *
 * What the host's own layout says, measured: each of the two keeps ALL of its state in a single
 * opaque storage ivar -- 192 bytes for the action, 72 for the command -- and nothing else but isa.
 * That is Apple's C++ storage and not a shape a port should copy; the port keeps ordinary ivars,
 * which is the same answer and is readable.
 *
 * WHAT IS NOT MEASURED HERE, named so it is not read as measured: what each member answers for a real
 * extension. An action's label, badge text and icon come from the manifest's action section, and a
 * command's title, activation key and modifiers come from its commands section, but an action or a
 * command only exists once a context has loaded an extension, and building a context needs
 * WKWebExtensionController, which is a later family and needs a web view this port does not have.
 * What the port does here is carry the members and store what it is given, which is the whole of what
 * a value holder owes. The manifest keys a context will read are named in facts/WebKit/WebExtension.md.
 */

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
        /* A button is enabled once the extension it belongs to is loaded, and the release's own
         * default for an action with nothing behind it is NO. */
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
    /* Readwrite in the release's header, so the port carries a setter rather than narrowing the
     * property: a caller that sets it expects the getter to answer it. */
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
    /* The popup is a web view, and this port has none to give: the release's popup is its own
     * extension's page, which needs the web view the context will own. Answering nil is what the
     * release answers for an action that presents no popup, and the flag says which. */
    return nil;
}

- (UIImage *)iconForSize:(CGSize)size
{
    /* The release scales the icon to the size asked for; the port answers the manifest's image at its
     * own size rather than inventing a scale the manifest does not name. */
    return _icon;
}

- (void)closePopup
{
    _presentsPopup = NO;
    _popupViewController = nil;
}

/* What a context hands the action, so that the context family does not have to reach into ivars. */
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
    /* A command's key command is built from its activation key and its modifiers, so a caller that
     * changes the modifiers changes the shortcut. */
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
