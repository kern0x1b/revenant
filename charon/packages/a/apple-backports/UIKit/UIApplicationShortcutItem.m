#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NSString *const UIApplicationLaunchOptionsShortcutItemKey = @"UIApplicationLaunchOptionsShortcutItemKey";

@implementation UIApplicationShortcutIcon {
    UIApplicationShortcutIconType _type;
    NSString *_templateImageName;
}

+ (instancetype)iconWithType:(UIApplicationShortcutIconType)type
{
    UIApplicationShortcutIcon *icon = [[self alloc] init];
    icon->_type = type;
    return icon;
}

+ (instancetype)iconWithTemplateImageName:(NSString *)templateImageName
{
    UIApplicationShortcutIcon *icon = [[self alloc] init];
    icon->_templateImageName = [templateImageName copy];
    return icon;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation UIApplicationShortcutItem {
    @package
    NSString *_type;
    NSString *_localizedTitle;
    NSString *_localizedSubtitle;
    UIApplicationShortcutIcon *_icon;
    NSDictionary *_userInfo;
    // The identifier is copied on set, as the header says and the host does (tests/backports/host/shortcut-item). It is nil until set.
    @package
    id _targetContentIdentifier;
}

- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)localizedTitle localizedSubtitle:(NSString *)localizedSubtitle icon:(UIApplicationShortcutIcon *)icon userInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        _type = [type copy];
        _localizedTitle = [localizedTitle copy];
        _localizedSubtitle = [localizedSubtitle copy];
        _icon = [icon copy];
        _userInfo = [userInfo copy];
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)localizedTitle
{
    return [self initWithType:type localizedTitle:localizedTitle localizedSubtitle:nil icon:nil userInfo:nil];
}

- (NSString *)type
{
    return _type;
}

- (NSString *)localizedTitle
{
    return _localizedTitle;
}

- (NSString *)localizedSubtitle
{
    return _localizedSubtitle;
}

- (UIApplicationShortcutIcon *)icon
{
    return _icon;
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (id)targetContentIdentifier
{
    return _targetContentIdentifier;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    UIMutableApplicationShortcutItem *copy = [[UIMutableApplicationShortcutItem alloc] initWithType:_type localizedTitle:_localizedTitle localizedSubtitle:_localizedSubtitle icon:_icon userInfo:_userInfo];
    copy->_targetContentIdentifier = _targetContentIdentifier;
    return copy;
}

@end

@implementation UIMutableApplicationShortcutItem

- (id)copyWithZone:(NSZone *)zone
{
    UIApplicationShortcutItem *copy = [[UIApplicationShortcutItem alloc] initWithType:_type localizedTitle:_localizedTitle localizedSubtitle:_localizedSubtitle icon:_icon userInfo:_userInfo];
    copy->_targetContentIdentifier = _targetContentIdentifier;
    return copy;
}

- (void)setType:(NSString *)type
{
    _type = [type copy];
}

- (void)setLocalizedTitle:(NSString *)title
{
    _localizedTitle = [title copy];
}

- (void)setLocalizedSubtitle:(NSString *)subtitle
{
    _localizedSubtitle = [subtitle copy];
}

- (void)setIcon:(UIApplicationShortcutIcon *)icon
{
    _icon = [icon copy];
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    _userInfo = [userInfo copy];
}

- (void)setTargetContentIdentifier:(id)targetContentIdentifier
{
    _targetContentIdentifier = [targetContentIdentifier copy];
}

@end

static const void *CharonShortcutItemsKey = &CharonShortcutItemsKey;

@implementation UIApplication (CharonShortcutItems)

- (NSArray<UIApplicationShortcutItem *> *)shortcutItems
{
    return objc_getAssociatedObject(self, CharonShortcutItemsKey);
}

- (void)setShortcutItems:(NSArray<UIApplicationShortcutItem *> *)items
{
    objc_setAssociatedObject(self, CharonShortcutItemsKey, [items copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
