#import "CharonCallKit.h"

@implementation CXHandle

@synthesize type = _type;
@synthesize value = _value;

- (instancetype)initWithType:(CXHandleType)type value:(NSString *)value
{
    if ((self = [super init])) {
        _type = type;
        _value = [value copy];
    }
    return self;
}

- (BOOL)isEqualToHandle:(CXHandle *)handle
{
    if (![handle isKindOfClass:[CXHandle class]])
        return NO;
    if (handle == self)
        return YES;
    return handle.type == _type && (handle.value == _value || [handle.value isEqualToString:_value]);
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[CXHandle class]] && [self isEqualToHandle:object];
}

- (NSUInteger)hash
{
    return (NSUInteger)_type ^ _value.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p type=%ld value=%@>", NSStringFromClass([self class]), self, (long)_type, _value];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[CXHandle allocWithZone:zone] initWithType:_type value:_value];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_type forKey:@"type"];
    [coder encodeObject:_value forKey:@"value"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *value = [coder decodeObjectOfClass:[NSString class] forKey:@"value"];
    if (!value)
        return nil;
    return [self initWithType:(CXHandleType)[coder decodeIntegerForKey:@"type"] value:value];
}

@end
