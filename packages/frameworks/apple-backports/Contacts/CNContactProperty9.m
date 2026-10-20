#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContactProperty {
    CNContact *_revenantContact;
    NSString *_revenantKey;
    id _revenantValue;
    NSString *_revenantIdentifier;
    NSString *_revenantLabel;
}

@dynamic contact, key, value, identifier, label;

+ (instancetype)revenant_propertyWithContact:(CNContact *)contact key:(NSString *)key value:(id)value
                                 identifier:(NSString *)identifier label:(NSString *)label
{
    CNContactProperty *property = [[self alloc] init];
    property->_revenantContact = contact;
    property->_revenantKey = [key copy];
    property->_revenantValue = value;
    property->_revenantIdentifier = [identifier copy];
    property->_revenantLabel = [label copy];
    return property;
}

- (CNContact *)contact { return _revenantContact; }
- (NSString *)key { return _revenantKey; }
- (id)value { return _revenantValue; }
- (NSString *)identifier { return _revenantIdentifier; }
- (NSString *)label { return _revenantLabel; }

- (id)copyWithZone:(NSZone *)zone
{
    return [CNContactProperty revenant_propertyWithContact:_revenantContact key:_revenantKey value:_revenantValue
                                                identifier:_revenantIdentifier label:_revenantLabel];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantContact forKey:@"contact"];
    [coder encodeObject:_revenantKey forKey:@"key"];
    [coder encodeObject:_revenantValue forKey:@"value"];
    [coder encodeObject:_revenantIdentifier forKey:@"identifier"];
    [coder encodeObject:_revenantLabel forKey:@"label"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantContact = [coder decodeObjectOfClass:[CNContact class] forKey:@"contact"];
        _revenantKey = [coder decodeObjectOfClass:[NSString class] forKey:@"key"];
        _revenantValue = [coder decodeObjectForKey:@"value"];
        _revenantIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _revenantLabel = [coder decodeObjectOfClass:[NSString class] forKey:@"label"];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNContactProperty class]])
        return NO;
    CNContactProperty *other = object;
    return [_revenantContact isEqual:other.contact] && [_revenantKey isEqualToString:other.key];
}

- (NSUInteger)hash
{
    return _revenantKey.hash ^ _revenantContact.hash;
}

@end
