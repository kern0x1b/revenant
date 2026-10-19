#import "CharonMenus.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-protocol-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const UIKeyInputUpArrow = @"UIKeyInputUpArrow";
NSString *const UIKeyInputDownArrow = @"UIKeyInputDownArrow";
NSString *const UIKeyInputLeftArrow = @"UIKeyInputLeftArrow";
NSString *const UIKeyInputRightArrow = @"UIKeyInputRightArrow";
NSString *const UIKeyInputEscape = @"UIKeyInputEscape";

static NSString *charon_modifier_text(NSInteger flags)
{
    static const struct {
        NSInteger flag;
        const char *name;
    } names[] = {{UIKeyModifierAlphaShift, "AlphaShift"}, {UIKeyModifierNumericPad, "NumPad"}, {UIKeyModifierControl, "Ctrl"}, {UIKeyModifierAlternate, "Opt"},
                 {UIKeyModifierShift, "Shift"}, {UIKeyModifierCommand, "Cmd"}};
    NSMutableArray *found = [NSMutableArray array];
    for (size_t index = 0; index < sizeof(names) / sizeof(names[0]); index++) {
        if (flags & names[index].flag)
            [found addObject:[NSString stringWithUTF8String:names[index].name]];
    }
    return [found componentsJoinedByString:@"-"];
}

@implementation UIKeyCommand {
@private
    NSString *_input;
    UIKeyModifierFlags _modifierFlags;
}

@dynamic wantsPriorityOverSystemBehavior, allowsAutomaticLocalization, allowsAutomaticMirroring;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [self initCharonWithTitle:@"" image:nil action:sel_registerName("_nop") propertyList:nil alternates:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _input = [[coder decodeObjectOfClass:[NSString class] forKey:@"input"] copy];
        _modifierFlags = (UIKeyModifierFlags)[coder decodeIntegerForKey:@"modifierFlags"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if (_input)
        [coder encodeObject:_input forKey:@"input"];
    [coder encodeInteger:_modifierFlags forKey:@"modifierFlags"];
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags propertyList:(id)propertyList
{
    return [self commandWithTitle:title image:image action:action input:input modifierFlags:modifierFlags propertyList:propertyList alternates:@[]];
}

+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags propertyList:(id)propertyList
                      alternates:(NSArray<UICommandAlternate *> *)alternates
{
    UIKeyCommand *command = [[self alloc] initCharonWithTitle:title image:image action:action propertyList:propertyList alternates:alternates];
    command->_input = [input copy];
    command->_modifierFlags = modifierFlags;
    return command;
}

+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action
{
    return [self commandWithTitle:@"" image:nil action:action input:input modifierFlags:modifierFlags propertyList:nil];
}

+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle
{
    UIKeyCommand *command = [self keyCommandWithInput:input modifierFlags:modifierFlags action:action];
    command.discoverabilityTitle = discoverabilityTitle;
    command.title = discoverabilityTitle ? discoverabilityTitle : @"";
    return command;
}

- (NSString *)input
{
    return _input;
}

- (UIKeyModifierFlags)modifierFlags
{
    return _modifierFlags;
}

- (id)copyWithZone:(NSZone *)zone
{
    UIKeyCommand *copy = [super copyWithZone:zone];
    copy->_input = [_input copy];
    copy->_modifierFlags = _modifierFlags;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIKeyCommand class]])
        return NO;
    UIKeyCommand *command = other;
    return command->_modifierFlags == _modifierFlags && (command->_input == _input || [command->_input isEqual:_input]);
}

- (NSUInteger)hash
{
    return _input.hash ^ (NSUInteger)_modifierFlags;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p", [self class], self];
    if (self.title.length)
        [text appendFormat:@"; title = %@", self.title];
    if (self.action)
        [text appendFormat:@"; action: %@", NSStringFromSelector(self.action)];
    [text appendFormat:@"; input: %@", _input ? _input : @"<none>"];
    if (_modifierFlags)
        [text appendFormat:@"; modifierFlags: %@", charon_modifier_text(_modifierFlags)];
    [text appendString:@">"];
    return text;
}

@end
