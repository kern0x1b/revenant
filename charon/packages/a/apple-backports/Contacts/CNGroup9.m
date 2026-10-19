#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNGroup {
@protected
    NSString *_charonIdentifier;
    NSString *_charonName;
}

@dynamic identifier, name;

- (instancetype)init
{
    self = [super init];
    if (self)
        _charonIdentifier = [[NSUUID UUID] UUIDString];
    return self;
}

- (NSString *)identifier { return _charonIdentifier; }
- (NSString *)name { return _charonName ?: @""; }

+ (instancetype)charon_groupWithIdentifier:(NSString *)identifier name:(NSString *)name mutable:(BOOL)mutableObjects
{
    CNGroup *group = mutableObjects ? [[CNMutableGroup alloc] init] : [[CNGroup alloc] init];
    [group charon_setIdentifier:identifier name:name];
    return group;
}

- (void)charon_setIdentifier:(NSString *)identifier name:(NSString *)name
{
    if (identifier)
        _charonIdentifier = [identifier copy];
    _charonName = [name copy];
}

+ (NSPredicate *)predicateForGroupsWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchGroupIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForGroupsInContainerWithIdentifier:(NSString *)containerIdentifier
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchGroupsInContainer value:[containerIdentifier copy]];
}

- (id)copyWithZone:(NSZone *)zone
{
    CNGroup *copied = [[CNGroup allocWithZone:zone] init];
    [copied charon_setIdentifier:_charonIdentifier name:_charonName];
    return copied;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    CNMutableGroup *copied = [[CNMutableGroup allocWithZone:zone] init];
    [copied charon_setIdentifier:_charonIdentifier name:_charonName];
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonIdentifier forKey:@"identifier"];
    [coder encodeObject:_charonName forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self) {
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _charonName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
        if (identifier)
            _charonIdentifier = [identifier copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNGroup class]])
        return NO;
    return [_charonIdentifier isEqualToString:[object identifier]];
}

- (NSUInteger)hash
{
    return _charonIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@ name=%@>", NSStringFromClass([self class]), self, _charonIdentifier, _charonName];
}

@end
