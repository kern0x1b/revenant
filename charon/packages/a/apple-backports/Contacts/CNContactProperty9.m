#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNContactProperty {
    CNContact *_charonContact;
    NSString *_charonKey;
    id _charonValue;
    NSString *_charonIdentifier;
    NSString *_charonLabel;
}

@dynamic contact, key, value, identifier, label;

+ (instancetype)charon_propertyWithContact:(CNContact *)contact key:(NSString *)key value:(id)value
                                 identifier:(NSString *)identifier label:(NSString *)label
{
    CNContactProperty *property = [[self alloc] init];
    property->_charonContact = contact;
    property->_charonKey = [key copy];
    property->_charonValue = value;
    property->_charonIdentifier = [identifier copy];
    property->_charonLabel = [label copy];
    return property;
}

- (CNContact *)contact { return _charonContact; }
- (NSString *)key { return _charonKey; }
- (id)value { return _charonValue; }
- (NSString *)identifier { return _charonIdentifier; }
- (NSString *)label { return _charonLabel; }

- (id)copyWithZone:(NSZone *)zone
{
    return [CNContactProperty charon_propertyWithContact:_charonContact key:_charonKey value:_charonValue
                                                identifier:_charonIdentifier label:_charonLabel];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonContact forKey:@"contact"];
    [coder encodeObject:_charonKey forKey:@"key"];
    [coder encodeObject:_charonValue forKey:@"value"];
    [coder encodeObject:_charonIdentifier forKey:@"identifier"];
    [coder encodeObject:_charonLabel forKey:@"label"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonContact = [coder decodeObjectOfClass:[CNContact class] forKey:@"contact"];
        _charonKey = [coder decodeObjectOfClass:[NSString class] forKey:@"key"];
        _charonValue = [coder decodeObjectForKey:@"value"];
        _charonIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _charonLabel = [coder decodeObjectOfClass:[NSString class] forKey:@"label"];
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
    return [_charonContact isEqual:other.contact] && [_charonKey isEqualToString:other.key];
}

- (NSUInteger)hash
{
    return _charonKey.hash ^ _charonContact.hash;
}

@end
