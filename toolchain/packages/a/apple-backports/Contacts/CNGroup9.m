#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNGroup {
@protected
    NSString *_revenantIdentifier;
    NSString *_revenantName;
}

@dynamic identifier, name;

- (instancetype)init
{
    self = [super init];
    if (self)
        _revenantIdentifier = [[NSUUID UUID] UUIDString];
    return self;
}

- (NSString *)identifier { return _revenantIdentifier; }
- (NSString *)name { return _revenantName ?: @""; }

+ (instancetype)revenant_groupWithIdentifier:(NSString *)identifier name:(NSString *)name mutable:(BOOL)mutableObjects
{
    CNGroup *group = mutableObjects ? [[CNMutableGroup alloc] init] : [[CNGroup alloc] init];
    [group revenant_setIdentifier:identifier name:name];
    return group;
}

- (void)revenant_setIdentifier:(NSString *)identifier name:(NSString *)name
{
    if (identifier)
        _revenantIdentifier = [identifier copy];
    _revenantName = [name copy];
}

+ (NSPredicate *)predicateForGroupsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchGroupIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForGroupsInContainerWithIdentifier:(NSString *)containerIdentifier
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchGroupsInContainer value:[containerIdentifier copy]];
}

- (id)copyWithZone:(NSZone *)zone
{
    CNGroup *copied = [[CNGroup allocWithZone:zone] init];
    [copied revenant_setIdentifier:_revenantIdentifier name:_revenantName];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutableGroup *copied = [[CNMutableGroup allocWithZone:zone] init];
    [copied revenant_setIdentifier:_revenantIdentifier name:_revenantName];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantIdentifier forKey:@"identifier"];
    [coder encodeObject:_revenantName forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _revenantName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
        if (identifier)
            _revenantIdentifier = [identifier copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNGroup class]])
        return NO;
    return [_revenantIdentifier isEqualToString:[object identifier]];
}

- (NSUInteger)hash
{
    return _revenantIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@ name=%@>", NSStringFromClass([self class]), self, _revenantIdentifier, _revenantName];
}

@end
