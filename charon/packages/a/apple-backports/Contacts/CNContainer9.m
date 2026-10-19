#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContainer {
    NSString *_charonIdentifier;
    NSString *_charonName;
    CNContainerType _charonType;
}

@dynamic identifier, name, type;

- (NSString *)identifier { return _charonIdentifier; }
- (NSString *)name { return _charonName ?: @""; }
- (CNContainerType)type { return _charonType; }

+ (instancetype)charon_containerWithIdentifier:(NSString *)identifier name:(NSString *)name type:(CNContainerType)type
{
    CNContainer *container = [[self alloc] init];
    container->_charonIdentifier = [identifier copy];
    container->_charonName = [name copy];
    container->_charonType = type;
    return container;
}

+ (NSPredicate *)predicateForContainersWithIdentifiers:(NSArray<NSString *> *)identifiers
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchContainerIdentifiers value:[identifiers copy]];
}

+ (NSPredicate *)predicateForContainerOfContactWithIdentifier:(NSString *)contactIdentifier
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchContainerOfContact value:[contactIdentifier copy]];
}

+ (NSPredicate *)predicateForContainerOfGroupWithIdentifier:(NSString *)groupIdentifier
{
    return [CharonContactPredicate predicateWithMatch:CharonContactMatchContainerOfGroup value:[groupIdentifier copy]];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [CNContainer charon_containerWithIdentifier:_charonIdentifier name:_charonName type:_charonType];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonIdentifier forKey:@"identifier"];
    [coder encodeObject:_charonName forKey:@"name"];
    [coder encodeInteger:_charonType forKey:@"type"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
        _charonName = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] copy];
        _charonType = (CNContainerType)[coder decodeIntegerForKey:@"type"];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNContainer class]])
        return NO;
    return [_charonIdentifier isEqualToString:[object identifier]];
}

- (NSUInteger)hash
{
    return _charonIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: identifier=%@ name=%@ type=%ld>", NSStringFromClass([self class]), self, _charonIdentifier, _charonName, (long)_charonType];
}

@end
