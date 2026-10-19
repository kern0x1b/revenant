#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContactRelation {
    NSString *_charonName;
}

@dynamic name;

+ (instancetype)contactRelationWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
        _charonName = [name copy];
    return self;
}

- (NSString *)name
{
    return _charonName ?: @"";
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
    [coder encodeObject:_charonName forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _charonName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
    return self;
}

- (BOOL)isEqual:(id)object
{
    return self == object || ([object isKindOfClass:[CNContactRelation class]] && [self.name isEqualToString:[object name]]);
}

- (NSUInteger)hash
{
    return self.name.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: name=%@>", NSStringFromClass([self class]), self, _charonName];
}

@end
