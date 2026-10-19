#import "CharonMenus.h"

@interface UIKey (CharonKey)
- (instancetype)initCharonWithCharacters:(NSString *)characters unmodified:(NSString *)unmodified keyCode:(UIKeyboardHIDUsage)keyCode modifierFlags:(UIKeyModifierFlags)modifierFlags;
@end

@implementation UIKey {
@private
    NSString *_modifiedInput;
    NSString *_unmodifiedInput;
    UIKeyboardHIDUsage _keyCode;
    UIKeyModifierFlags _modifierFlags;
}

- (instancetype)initCharonWithCharacters:(NSString *)characters unmodified:(NSString *)unmodified keyCode:(UIKeyboardHIDUsage)keyCode modifierFlags:(UIKeyModifierFlags)modifierFlags
{
    if ((self = [super init])) {
        _modifiedInput = [characters copy];
        _unmodifiedInput = [unmodified copy];
        _keyCode = keyCode;
        _modifierFlags = modifierFlags;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithCharacters:[coder decodeObjectForKey:@"_modifiedInput"] unmodified:[coder decodeObjectForKey:@"_unmodifiedInput"]
                                  keyCode:(UIKeyboardHIDUsage)[coder decodeIntegerForKey:@"_keyCode"] modifierFlags:(UIKeyModifierFlags)[coder decodeIntegerForKey:@"_modifierFlags"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_keyCode forKey:@"_keyCode"];
    [coder encodeObject:_modifiedInput forKey:@"_modifiedInput"];
    [coder encodeInteger:(NSInteger)_modifierFlags forKey:@"_modifierFlags"];
    [coder encodeObject:_unmodifiedInput forKey:@"_unmodifiedInput"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initCharonWithCharacters:_modifiedInput unmodified:_unmodifiedInput keyCode:_keyCode modifierFlags:_modifierFlags];
}

- (NSString *)characters
{
    return _modifiedInput;
}

- (NSString *)charactersIgnoringModifiers
{
    return _unmodifiedInput;
}

- (UIKeyModifierFlags)modifierFlags
{
    return _modifierFlags;
}

- (UIKeyboardHIDUsage)keyCode
{
    return _keyCode;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIKey class]])
        return NO;
    UIKey *other = object;
    return _keyCode == other->_keyCode && _modifierFlags == other->_modifierFlags;
}

- (NSUInteger)hash
{
    return (NSUInteger)_keyCode ^ (NSUInteger)_modifierFlags;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: characters=%@, unmodified=%@, keyCode=%ld, modifierFlags=%ld>", [self class], self, _modifiedInput, _unmodifiedInput, (long)_keyCode,
                     (long)_modifierFlags];
}

@end
