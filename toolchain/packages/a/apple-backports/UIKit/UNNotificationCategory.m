#import "CharonUserNotifications.h"

@implementation UNNotificationCategory {
@private
    NSString *_identifier;
    NSArray *_actions;
    NSArray *_intentIdentifiers;
    UNNotificationCategoryOptions _options;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers options:(UNNotificationCategoryOptions)options
{
    return [[self alloc] initCharonWithIdentifier:identifier actions:actions intentIdentifiers:intentIdentifiers options:options];
}

- (instancetype)initCharonWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intentIdentifiers
                                 options:(UNNotificationCategoryOptions)options
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _actions = [actions copy];
        _intentIdentifiers = [intentIdentifiers copy];
        _options = options;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSSet *actions = [NSSet setWithObjects:[NSArray class], [UNNotificationAction class], [UNTextInputNotificationAction class], nil];
    return [self initCharonWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]
                                  actions:[coder decodeObjectOfClasses:actions forKey:@"actions"]
                        intentIdentifiers:[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"intentIdentifiers"]
                                  options:(UNNotificationCategoryOptions)[coder decodeIntegerForKey:@"options"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_actions forKey:@"actions"];
    [coder encodeObject:_intentIdentifiers forKey:@"intentIdentifiers"];
    [coder encodeInteger:(NSInteger)_options forKey:@"options"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSArray *)actions
{
    return _actions;
}

- (NSArray *)intentIdentifiers
{
    return _intentIdentifiers;
}

- (UNNotificationCategoryOptions)options
{
    return _options;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNNotificationCategory class]])
        return NO;
    UNNotificationCategory *other = object;
    return (_actions == other.actions || [_actions isEqual:other.actions]) && (_intentIdentifiers == other.intentIdentifiers || [_intentIdentifiers isEqual:other.intentIdentifiers])
        && (_identifier == other.identifier || [_identifier isEqual:other.identifier]) && _options == other.options
        && (self.hiddenPreviewsBodyPlaceholder == other.hiddenPreviewsBodyPlaceholder || [self.hiddenPreviewsBodyPlaceholder isEqualToString:other.hiddenPreviewsBodyPlaceholder])
        && (self.categorySummaryFormat == other.categorySummaryFormat || [self.categorySummaryFormat isEqualToString:other.categorySummaryFormat]);
}

- (NSUInteger)hash
{
    return _actions.hash ^ _intentIdentifiers.hash ^ _identifier.hash ^ _options;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, actions: %@, minimalAction: %@, intentIdentifiers: %@, custom dismiss: %@, CarPlay: %@>",
                                      [self class], self, _identifier, _actions, @[], _intentIdentifiers, (_options & UNNotificationCategoryOptionCustomDismissAction) ? @"YES" : @"NO",
                                      (_options & UNNotificationCategoryOptionAllowInCarPlay) ? @"YES" : @"NO"];
}

@end
