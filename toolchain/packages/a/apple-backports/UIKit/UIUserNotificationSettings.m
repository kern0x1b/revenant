#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const RevenantCategoryIdentifierKey = @"kCategoryIdentifierKey";
static NSString *const RevenantActionsByContextKey = @"kActionsByContextKey";
static NSString *const RevenantIdentifierKey = @"kIdentifierKey";
static NSString *const RevenantTitleKey = @"kTitleKey";
static NSString *const RevenantActivationModeKey = @"kActivationModeKey";
static NSString *const RevenantAuthenticationRequiredKey = @"kIsAuthenticationRequiredKey";
static NSString *const RevenantDestructiveKey = @"kIsDestructiveKey";
static NSString *const RevenantBehaviorKey = @"kBehaviorKey";
static NSString *const RevenantParametersKey = @"kParametersKey";

static NSString *revenant_bool_name(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static NSString *revenant_activation_mode_name(UIUserNotificationActivationMode mode)
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
- (void)revenant_setIdentifier:(NSString *)identifier;
- (void)revenant_setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context;
@end

@interface UIUserNotificationAction ()
- (void)revenant_setIdentifier:(NSString *)identifier;
- (void)revenant_setTitle:(NSString *)title;
- (void)revenant_setActivationMode:(UIUserNotificationActivationMode)activationMode;
- (void)revenant_setAuthenticationRequired:(BOOL)authenticationRequired;
- (void)revenant_setDestructive:(BOOL)destructive;
- (void)revenant_setBehavior:(UIUserNotificationActionBehavior)behavior;
- (void)revenant_setParameters:(NSDictionary *)parameters;
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

- (void)revenant_setIdentifier:(NSString *)identifier
{
    _identifier = [identifier copy];
}

- (void)revenant_setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context
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
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:RevenantCategoryIdentifierKey] copy];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSNumber class], [UIUserNotificationAction class], nil];
        NSDictionary *actions = [coder decodeObjectOfClasses:classes forKey:RevenantActionsByContextKey];
        _actions = [actions isKindOfClass:[NSDictionary class]] ? [actions copy] : nil;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:RevenantCategoryIdentifierKey];
    [coder encodeObject:_actions forKey:RevenantActionsByContextKey];
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
    [self revenant_setIdentifier:identifier];
}

- (void)setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context
{
    [self revenant_setActions:actions forContext:context];
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

- (void)revenant_setIdentifier:(NSString *)identifier
{
    _identifier = [identifier copy];
}

- (void)revenant_setTitle:(NSString *)title
{
    _title = [title copy];
}

- (void)revenant_setActivationMode:(UIUserNotificationActivationMode)activationMode
{
    _activationMode = activationMode;
}

- (void)revenant_setAuthenticationRequired:(BOOL)authenticationRequired
{
    _authenticationRequired = authenticationRequired;
}

- (void)revenant_setDestructive:(BOOL)destructive
{
    _destructive = destructive;
}

- (void)revenant_setBehavior:(UIUserNotificationActionBehavior)behavior
{
    _behavior = behavior;
}

- (void)revenant_setParameters:(NSDictionary *)parameters
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
        _identifier = [[coder decodeObjectOfClass:[NSString class] forKey:RevenantIdentifierKey] copy];
        _title = [[coder decodeObjectOfClass:[NSString class] forKey:RevenantTitleKey] copy];
        _activationMode = (UIUserNotificationActivationMode)[coder decodeIntegerForKey:RevenantActivationModeKey];
        _authenticationRequired = [coder decodeBoolForKey:RevenantAuthenticationRequiredKey];
        _destructive = [coder decodeBoolForKey:RevenantDestructiveKey];
        _behavior = (UIUserNotificationActionBehavior)[coder decodeIntegerForKey:RevenantBehaviorKey];
        _parameters = [[coder decodeObjectOfClass:[NSDictionary class] forKey:RevenantParametersKey] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:RevenantIdentifierKey];
    [coder encodeObject:_title forKey:RevenantTitleKey];
    [coder encodeInteger:(NSInteger)_activationMode forKey:RevenantActivationModeKey];
    [coder encodeBool:_authenticationRequired forKey:RevenantAuthenticationRequiredKey];
    [coder encodeBool:_destructive forKey:RevenantDestructiveKey];
    [coder encodeInteger:(NSInteger)_behavior forKey:RevenantBehaviorKey];
    [coder encodeObject:_parameters forKey:RevenantParametersKey];
}

- (void)revenant_copyInto:(UIUserNotificationAction *)copy
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
    [self revenant_copyInto:copy];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    UIMutableUserNotificationAction *copy = [[UIMutableUserNotificationAction allocWithZone:zone] init];
    [self revenant_copyInto:copy];
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
            [self class], self, _identifier, _title, revenant_activation_mode_name(_activationMode), revenant_bool_name(_authenticationRequired), revenant_bool_name(_destructive)];
}

@end

@implementation UIMutableUserNotificationAction

- (void)setIdentifier:(NSString *)identifier
{
    [self revenant_setIdentifier:identifier];
}

- (void)setTitle:(NSString *)title
{
    [self revenant_setTitle:title];
}

- (void)setActivationMode:(UIUserNotificationActivationMode)activationMode
{
    [self revenant_setActivationMode:activationMode];
}

- (void)setAuthenticationRequired:(BOOL)authenticationRequired
{
    [self revenant_setAuthenticationRequired:authenticationRequired];
}

- (void)setDestructive:(BOOL)destructive
{
    [self revenant_setDestructive:destructive];
}

- (void)setBehavior:(UIUserNotificationActionBehavior)behavior
{
    [self revenant_setBehavior:behavior];
}

- (void)setParameters:(NSDictionary *)parameters
{
    [self revenant_setParameters:parameters];
}

@end
