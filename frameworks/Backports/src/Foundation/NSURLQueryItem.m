#import <Foundation/Foundation.h>
#import "../revenant_alias.h"

REVENANT_ALIAS_STATE(NSURLQueryItem, NSObject,
    NSString *_revenantName;
    NSString *_revenantValue;
)

@implementation REVENANT_ALIAS_CLASS(NSURLQueryItem) (RevenantQueryItem)

+ (instancetype)queryItemWithName:(NSString *)name value:(NSString *)value
{
    return [[self alloc] initWithName:name value:value];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init]))
        _revenantName = @"";
    return self;
}

- (instancetype)initWithName:(NSString *)name value:(NSString *)value
{
    if ((self = [super init])) {
        _revenantName = [name copy] ?: @"";
        _revenantValue = [value copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *name = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.name"];
    NSString *value = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.value"];
    return [self initWithName:name value:value];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantName forKey:@"NS.name"];
    [coder encodeObject:_revenantValue forKey:@"NS.value"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithName:_revenantName value:_revenantValue];
}

- (NSString *)name
{
    return _revenantName;
}

- (NSString *)value
{
    return _revenantValue;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSURLQueryItem class]])
        return NO;
    NSURLQueryItem *other = object;
    return (_revenantName == other.name || [_revenantName isEqualToString:other.name]) && (_revenantValue == other.value || [_revenantValue isEqualToString:other.value]);
}

- (NSUInteger)hash
{
    return _revenantName.hash ^ _revenantValue.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> {name = %@, value = %@}", [self class], self, _revenantName, _revenantValue];
}

@end
