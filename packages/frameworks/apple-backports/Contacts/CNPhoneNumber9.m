#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNPhoneNumber {
    NSString *_revenantStringValue;
}

@dynamic stringValue;

+ (instancetype)phoneNumberWithStringValue:(NSString *)stringValue
{
    return [[self alloc] initWithStringValue:stringValue];
}

- (instancetype)initWithStringValue:(NSString *)string
{
    if (!string)
        return nil;
    self = [super init];
    if (self)
        _revenantStringValue = [string copy];
    return self;
}

- (NSString *)stringValue
{
    return _revenantStringValue;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantStringValue forKey:@"stringValue"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _revenantStringValue = [[coder decodeObjectOfClass:[NSString class] forKey:@"stringValue"] copy];
    return self;
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isKindOfClass:[CNPhoneNumber class]] && [_revenantStringValue isEqualToString:[object stringValue]]);
}

- (NSUInteger)hash
{
    return _revenantStringValue.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: stringValue=%@>", NSStringFromClass([self class]), self, _revenantStringValue];
}

@end
