#import <Foundation/Foundation.h>

@implementation NSURLQueryItem {
@private
    NSString *_charonName;
    NSString *_charonValue;
}

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
    return [self initWithName:@"" value:nil];
}

- (instancetype)initWithName:(NSString *)name value:(NSString *)value
{
    if ((self = [super init])) {
        _charonName = [name copy] ?: @"";
        _charonValue = [value copy];
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
    [coder encodeObject:_charonName forKey:@"NS.name"];
    [coder encodeObject:_charonValue forKey:@"NS.value"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithName:_charonName value:_charonValue];
}

- (NSString *)name
{
    return _charonName;
}

- (NSString *)value
{
    return _charonValue;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSURLQueryItem class]])
        return NO;
    NSURLQueryItem *other = object;
    return (_charonName == other.name || [_charonName isEqualToString:other.name]) && (_charonValue == other.value || [_charonValue isEqualToString:other.value]);
}

- (NSUInteger)hash
{
    return _charonName.hash ^ _charonValue.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> {name = %@, value = %@}", [self class], self, _charonName, _charonValue];
}

@end
