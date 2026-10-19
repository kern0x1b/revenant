#import <UIKit/UIKit.h>

@implementation UITextInputPasswordRules {
    NSString *_passwordRulesDescriptor;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)passwordRulesWithDescriptor:(NSString *)passwordRulesDescriptor
{
    UITextInputPasswordRules *rules = [[self alloc] init];
    rules->_passwordRulesDescriptor = [passwordRulesDescriptor copy];
    return rules;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        _passwordRulesDescriptor = [coder decodeObjectOfClass:[NSString class] forKey:@"passwordRulesDescriptor"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_passwordRulesDescriptor)
        [coder encodeObject:_passwordRulesDescriptor forKey:@"passwordRulesDescriptor"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] passwordRulesWithDescriptor:_passwordRulesDescriptor];
}

- (NSString *)passwordRulesDescriptor
{
    return _passwordRulesDescriptor;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[UITextInputPasswordRules class]])
        return NO;
    NSString *other = [(UITextInputPasswordRules *)object passwordRulesDescriptor];
    return _passwordRulesDescriptor == other || [_passwordRulesDescriptor isEqual:other];
}

- (NSString *)description
{
    NSMutableString *description = [[NSMutableString alloc] initWithFormat:@"<%@: %p", [self class], self];
    if (_passwordRulesDescriptor)
        [description appendFormat:@"; passwordRulesDescriptor = %@", _passwordRulesDescriptor];
    [description appendString:@">"];
    return description;
}

@end
