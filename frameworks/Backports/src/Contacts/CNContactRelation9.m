#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContactRelation {
    NSString *_revenantName;
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
        _revenantName = [name copy];
    return self;
}

- (NSString *)name
{
    return _revenantName ?: @"";
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
    [coder encodeObject:_revenantName forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _revenantName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
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
    return [NSString stringWithFormat:@"<%@: %p: name=%@>", NSStringFromClass([self class]), self, _revenantName];
}

@end
