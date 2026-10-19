#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNPhoneNumber {
    NSString *_charonStringValue;
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
        _charonStringValue = [string copy];
    return self;
}

- (NSString *)stringValue
{
    return _charonStringValue;
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
    [coder encodeObject:_charonStringValue forKey:@"stringValue"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _charonStringValue = [[coder decodeObjectOfClass:[NSString class] forKey:@"stringValue"] copy];
    return self;
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isKindOfClass:[CNPhoneNumber class]] && [_charonStringValue isEqualToString:[object stringValue]]);
}

- (NSUInteger)hash
{
    return _charonStringValue.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: stringValue=%@>", NSStringFromClass([self class]), self, _charonStringValue];
}

@end
