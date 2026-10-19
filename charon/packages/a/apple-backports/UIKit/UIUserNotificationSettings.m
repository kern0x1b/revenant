#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const CharonCategoryIdentifierKey = @"kCategoryIdentifierKey";
static NSString *const CharonActionsByContextKey = @"kActionsByContextKey";
static NSString *const CharonIdentifierKey = @"kIdentifierKey";
static NSString *const CharonTitleKey = @"kTitleKey";
static NSString *const CharonActivationModeKey = @"kActivationModeKey";
static NSString *const CharonAuthenticationRequiredKey = @"kIsAuthenticationRequiredKey";
static NSString *const CharonDestructiveKey = @"kIsDestructiveKey";
static NSString *const CharonBehaviorKey = @"kBehaviorKey";
static NSString *const CharonParametersKey = @"kParametersKey";

static NSString *charon_bool_name(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static NSString *charon_activation_mode_name(UIUserNotificationActivationMode mode)
{
    switch (mode) {
    case UIUserNotificationActivationModeForeground:
        return @"UIUserNotificationActivationModeForeground";
    case UIUserNotificationActivationModeBackground:
        return @"UIUserNotificationActivationModeBackground";
    default:
        return [NSString stringWithFormat:@"%lu", (unsigned long)mode];
    }
}

@interface UIUserNotificationCategory ()
- (void)charon_setIdentifier:(NSString *)identifier;
- (void)charon_setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context;
@end

@interface UIUserNotificationAction ()
- (void)charon_setIdentifier:(NSString *)identifier;
- (void)charon_setTitle:(NSString *)title;
- (void)charon_setActivationMode:(UIUserNotificationActivationMode)activationMode;
- (void)charon_setAuthenticationRequired:(BOOL)authenticationRequired;
- (void)charon_setDestructive:(BOOL)destructive;
- (void)charon_setBehavior:(UIUserNotificationActionBehavior)behavior;
- (void)charon_setParameters:(NSDictionary *)parameters;
@end

@implementation UIUserNotificationSettings {
    UIUserNotificationType _types;
    NSSet *_categories;
}

+ (instancetype)settingsForTypes:(UIUserNotificationType)types categories:(NSSet *)categories
{
    UIUserNotificationSettings *settings = [[self alloc] init];
    settings->_types = types;
    NSMutableSet *copied = [NSMutableSet setWithCapacity:categories.count];
    for (UIUserNotificationCategory *category in categories)
        [copied addObject:[category copy]];
    settings->_categories = [copied copy];
    return settings;
}

- (UIUserNotificationType)types
{
    return _types;
}

- (NSSet *)categories
{
    return _categories;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIUserNotificationSettings class]])
        return NO;
    UIUserNotificationSettings *other = object;
    return other->_types == _types && (other->_categories == _categories || [other->_categories isEqual:_categories]);
}

- (NSUInteger)hash
{
    return _types ^ _categories.hash;
}

- (NSString *)description
{
    NSMutableString *names = [NSMutableString string];
    if (_types & UIUserNotificationTypeAlert)
        [names appendString:@"UIUserNotificationTypeAlert"];
    if (_types & UIUserNotificationTypeBadge)
        [names appendString:@" UIUserNotificationTypeBadge"];
    if (_types & UIUserNotificationTypeSound)
        [names appendString:@" UIUserNotificationTypeSound"];
    NSString *types = names.length ? names : @"none";
    NSString *categories = _categories ? [NSString stringWithFormat:@"categories: %@;", _categories] : @"";
    return [NSString stringWithFormat:@"<%@: %p; types: (%@);%@>", [self class], self, types, categories];
}

@end

@implementation UIUserNotificationCategory {
@private
    NSString *_identifier;
    NSDictionary *_actions;
}

- (void)charon_setIdentifier:(NSString *)identifier
{
    _identifier = [identifier copy];
}

- (void)charon_setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context
{
    NSMutableDictionary *updated = _actions ? [_actions mutableCopy] : [NSMutableDictionary dictionary];
    [updated setObject:actions ? [actions copy] : [NSArray array] forKey:@(context)];
    _actions = [updated copy];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:CharonCategoryIdentifierKey] copy];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSNumber class], [UIUserNotificationAction class], nil];
        NSDictionary *actions = [coder decodeObjectOfClasses:classes forKey:CharonActionsByContextKey];
        _actions = [actions isKindOfClass:[NSDictionary class]] ? [actions copy] : nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:CharonCategoryIdentifierKey];
    [coder encodeObject:_actions forKey:CharonActionsByContextKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIUserNotificationCategory *copy = [[UIUserNotificationCategory allocWithZone:zone] init];
    copy->_identifier = _identifier;
    copy->_actions = [_actions copy];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    UIMutableUserNotificationCategory *copy = [[UIMutableUserNotificationCategory allocWithZone:zone] init];
    copy.identifier = _identifier;
    for (NSNumber *context in _actions)
        [copy setActions:[_actions objectForKey:context] forContext:context.unsignedIntegerValue];
    return copy;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSArray *)actionsForContext:(UIUserNotificationActionContext)context
{
    return [_actions objectForKey:@(context)];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIUserNotificationCategory class]])
        return NO;
    UIUserNotificationCategory *other = object;
    return [_identifier isEqual:other->_identifier] && [_actions isEqual:other->_actions];
}

- (NSUInteger)hash
{
    return _identifier.hash ^ _actions.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, actions: %@>", [self class], self, _identifier, _actions];
}

@end

@implementation UIMutableUserNotificationCategory

- (void)setIdentifier:(NSString *)identifier
{
    [self charon_setIdentifier:identifier];
}

- (void)setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context
{
    [self charon_setActions:actions forContext:context];
}

@end

@implementation UIUserNotificationAction {
@private
    NSString *_identifier;
    NSString *_title;
    UIUserNotificationActivationMode _activationMode;
    BOOL _authenticationRequired;
    BOOL _destructive;
    UIUserNotificationActionBehavior _behavior;
    NSDictionary *_parameters;
}

- (void)charon_setIdentifier:(NSString *)identifier
{
    _identifier = [identifier copy];
}

- (void)charon_setTitle:(NSString *)title
{
    _title = [title copy];
}

- (void)charon_setActivationMode:(UIUserNotificationActivationMode)activationMode
{
    _activationMode = activationMode;
}

- (void)charon_setAuthenticationRequired:(BOOL)authenticationRequired
{
    _authenticationRequired = authenticationRequired;
}

- (void)charon_setDestructive:(BOOL)destructive
{
    _destructive = destructive;
}

- (void)charon_setBehavior:(UIUserNotificationActionBehavior)behavior
{
    _behavior = behavior;
}

- (void)charon_setParameters:(NSDictionary *)parameters
{
    _parameters = [parameters copy];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:CharonIdentifierKey] copy];
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:CharonTitleKey] copy];
        _activationMode = (UIUserNotificationActivationMode)[coder decodeIntegerForKey:CharonActivationModeKey];
        _authenticationRequired = [coder decodeBoolForKey:CharonAuthenticationRequiredKey];
        _destructive = [coder decodeBoolForKey:CharonDestructiveKey];
        _behavior = (UIUserNotificationActionBehavior)[coder decodeIntegerForKey:CharonBehaviorKey];
        _parameters = [[coder decodeObjectOfClass:[NSDictionary class] forKey:CharonParametersKey] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:CharonIdentifierKey];
    [coder encodeObject:_title forKey:CharonTitleKey];
    [coder encodeInteger:(NSInteger)_activationMode forKey:CharonActivationModeKey];
    [coder encodeBool:_authenticationRequired forKey:CharonAuthenticationRequiredKey];
    [coder encodeBool:_destructive forKey:CharonDestructiveKey];
    [coder encodeInteger:(NSInteger)_behavior forKey:CharonBehaviorKey];
    [coder encodeObject:_parameters forKey:CharonParametersKey];
}

- (void)charon_copyInto:(UIUserNotificationAction *)copy
{
    copy->_identifier = _identifier;
    copy->_title = _title;
    copy->_activationMode = _activationMode;
    copy->_authenticationRequired = _authenticationRequired;
    copy->_destructive = _destructive;
    copy->_behavior = _behavior;
    copy->_parameters = _parameters;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIUserNotificationAction *copy = [[UIUserNotificationAction allocWithZone:zone] init];
    [self charon_copyInto:copy];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    UIMutableUserNotificationAction *copy = [[UIMutableUserNotificationAction allocWithZone:zone] init];
    [self charon_copyInto:copy];
    return copy;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)title
{
    return _title;
}

- (UIUserNotificationActivationMode)activationMode
{
    return _activationMode;
}

- (BOOL)isAuthenticationRequired
{
    return _authenticationRequired;
}

- (BOOL)isDestructive
{
    return _destructive;
}

- (UIUserNotificationActionBehavior)behavior
{
    return _behavior;
}

- (NSDictionary *)parameters
{
    return _parameters;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, title: %@, activationMode: %@, isAuthenticationRequired:%@, isDestructive:%@>",
            [self class], self, _identifier, _title, charon_activation_mode_name(_activationMode), charon_bool_name(_authenticationRequired), charon_bool_name(_destructive)];
}

@end

@implementation UIMutableUserNotificationAction

- (void)setIdentifier:(NSString *)identifier
{
    [self charon_setIdentifier:identifier];
}

- (void)setTitle:(NSString *)title
{
    [self charon_setTitle:title];
}

- (void)setActivationMode:(UIUserNotificationActivationMode)activationMode
{
    [self charon_setActivationMode:activationMode];
}

- (void)setAuthenticationRequired:(BOOL)authenticationRequired
{
    [self charon_setAuthenticationRequired:authenticationRequired];
}

- (void)setDestructive:(BOOL)destructive
{
    [self charon_setDestructive:destructive];
}

- (void)setBehavior:(UIUserNotificationActionBehavior)behavior
{
    [self charon_setBehavior:behavior];
}

- (void)setParameters:(NSDictionary *)parameters
{
    [self charon_setParameters:parameters];
}

@end
