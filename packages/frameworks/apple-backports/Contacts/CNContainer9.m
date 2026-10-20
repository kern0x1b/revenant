#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContainer {
    NSString *_revenantIdentifier;
    NSString *_revenantName;
    CNContainerType _revenantType;
}

@dynamic identifier, name, type;

- (NSString *)identifier { return _revenantIdentifier; }
- (NSString *)name { return _revenantName ?: @""; }
- (CNContainerType)type { return _revenantType; }

+ (instancetype)revenant_containerWithIdentifier:(NSString *)identifier name:(NSString *)name type:(CNContainerType)type
{
    CNContainer *container = [[self alloc] init];
    container->_revenantIdentifier = [identifier copy];
    container->_revenantName = [name copy];
    container->_revenantType = type;
    return container;
}

+ (NSPredicate *)predicateForContainersWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchContainerIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForContainerOfContactWithIdentifier:(NSString *)contactIdentifier
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchContainerOfContact value:[contactIdentifier copy]];
}

+ (NSPredicate *)predicateForContainerOfGroupWithIdentifier:(NSString *)groupIdentifier
{
    return [RevenantContactPredicate predicateWithMatch:RevenantContactMatchContainerOfGroup value:[groupIdentifier copy]];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [CNContainer revenant_containerWithIdentifier:_revenantIdentifier name:_revenantName type:_revenantType];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantIdentifier forKey:@"identifier"];
    [coder encodeObject:_revenantName forKey:@"name"];
    [coder encodeInteger:_revenantType forKey:@"type"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
        _revenantName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
        _revenantType = (CNContainerType)[coder decodeIntegerForKey:@"type"];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNContainer class]])
        return NO;
    return [_revenantIdentifier isEqualToString:[object identifier]];
}

- (NSUInteger)hash
{
    return _revenantIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@ name=%@ type=%ld>", NSStringFromClass([self class]), self, _revenantIdentifier, _revenantName, (long)_revenantType];
}

@end
