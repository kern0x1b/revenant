#import <Foundation/Foundation.h>

@implementation NSURLQueryItem {
@private
    // 16.4/16.5's own header still declares an ivar block of its own for this class (@private NSString *_name;
    // NSString *_value;) that 26.2's does not; naming ours the same as the header's would collide there
    // ("instance variable is already declared"). Prefixed instead, so this compiles unchanged whichever the
    // SDK's own header carries.
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
