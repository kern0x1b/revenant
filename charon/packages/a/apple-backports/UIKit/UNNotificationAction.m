#import "CharonUserNotifications.h"

static NSString *charon_yes_no(BOOL value)
{
    return value ? @"YES" : @"NO";
}

@implementation UNNotificationAction {
@private
    NSString *_identifier;
    NSString *_title;
    UNNotificationActionOptions _options;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
{
    return [[self alloc] initCharonWithIdentifier:identifier title:title options:options];
}

- (instancetype)initCharonWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _title = [title copy];
        _options = options;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]
                                    title:[coder decodeObjectOfClass:[NSString class] forKey:@"title"]
                                  options:(UNNotificationActionOptions)[coder decodeIntegerForKey:@"options"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_title forKey:@"title"];
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

- (NSString *)title
{
    return _title;
}

- (UNNotificationActionOptions)options
{
    return _options;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNNotificationAction class]])
        return NO;
    UNNotificationAction *other = object;
    return (_identifier == other.identifier || [_identifier isEqual:other.identifier]) && (_title == other.title || [_title isEqual:other.title])
        && _options == other.options;
}

- (NSUInteger)hash
{
    return _identifier.hash ^ _options ^ _title.hash;
}

- (NSString *)charon_description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier: %@, title: %@, isAuthenticationRequired: %@, isDestructive: %@, isForeground: %@",
                                      [self class], self, _identifier, _title, charon_yes_no(_options & UNNotificationActionOptionAuthenticationRequired),
                                      charon_yes_no(_options & UNNotificationActionOptionDestructive), charon_yes_no(_options & UNNotificationActionOptionForeground)];
}

- (NSString *)description
{
    return [[self charon_description] stringByAppendingString:@">"];
}

@end

@implementation UNTextInputNotificationAction {
@private
    NSString *_textInputButtonTitle;
    NSString *_textInputPlaceholder;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                textInputButtonTitle:(NSString *)buttonTitle textInputPlaceholder:(NSString *)placeholder
{
    return [[self alloc] initCharonWithIdentifier:identifier title:title options:options textInputButtonTitle:buttonTitle textInputPlaceholder:placeholder];
}

- (instancetype)initCharonWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options
                    textInputButtonTitle:(NSString *)buttonTitle textInputPlaceholder:(NSString *)placeholder
{
    if ((self = [super initCharonWithIdentifier:identifier title:title options:options])) {
        _textInputButtonTitle = [buttonTitle copy];
        _textInputPlaceholder = [placeholder copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _textInputButtonTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"textInputButtonTitle"];
        _textInputPlaceholder = [coder decodeObjectOfClass:[NSString class] forKey:@"textInputPlaceholder"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_textInputButtonTitle forKey:@"textInputButtonTitle"];
    [coder encodeObject:_textInputPlaceholder forKey:@"textInputPlaceholder"];
}

- (NSString *)textInputButtonTitle
{
    return _textInputButtonTitle;
}

- (NSString *)textInputPlaceholder
{
    return _textInputPlaceholder;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNTextInputNotificationAction class]] || ![super isEqual:object])
        return NO;
    UNTextInputNotificationAction *other = object;
    return (_textInputButtonTitle == other.textInputButtonTitle || [_textInputButtonTitle isEqual:other.textInputButtonTitle])
        && (_textInputPlaceholder == other.textInputPlaceholder || [_textInputPlaceholder isEqual:other.textInputPlaceholder]);
}

- (NSUInteger)hash
{
    return [super hash] ^ _textInputButtonTitle.hash ^ _textInputPlaceholder.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@, textInputButtonTitle: %@, textInputPlaceholder: %@>", [self charon_description], _textInputButtonTitle,
                                      _textInputPlaceholder];
}

@end
