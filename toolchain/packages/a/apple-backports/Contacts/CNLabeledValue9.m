#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNLabeledValue {
    NSString *_charonIdentifier;
    NSString *_charonLabel;
    id _charonValue;
    ABMultiValueIdentifier _charonAddressBookIdentifier;
}

@dynamic identifier, label, value;

+ (instancetype)labeledValueWithLabel:(NSString *)label value:(id)value
{
    return [[self alloc] initWithLabel:label value:value];
}

- (instancetype)initWithLabel:(NSString *)label value:(id)value
{
    self = [super init];
    if (self) {
        _charonIdentifier = [[NSUUID UUID] UUIDString];
        _charonLabel = [label copy];
        _charonValue = [value copyWithZone:NULL];
        _charonAddressBookIdentifier = kABMultiValueInvalidIdentifier;
    }
    return self;
}

+ (instancetype)charon_labeledValueWithLabel:(NSString *)label value:(id)value identifier:(ABMultiValueIdentifier)identifier
{
    CNLabeledValue *labeled = [[self alloc] initWithLabel:label value:value];
    labeled->_charonAddressBookIdentifier = identifier;
    return labeled;
}

- (ABMultiValueIdentifier)charon_addressBookIdentifier
{
    return _charonAddressBookIdentifier;
}

- (NSString *)identifier
{
    return _charonIdentifier;
}

- (NSString *)label
{
    return _charonLabel;
}

- (id)value
{
    return _charonValue;
}

- (instancetype)labeledValueBySettingLabel:(NSString *)label
{
    return [self labeledValueBySettingLabel:label value:_charonValue];
}

- (instancetype)labeledValueBySettingValue:(id)value
{
    return [self labeledValueBySettingLabel:_charonLabel value:value];
}

- (instancetype)labeledValueBySettingLabel:(NSString *)label value:(id)value
{
    CNLabeledValue *made = [[[self class] alloc] initWithLabel:label value:value];
    made->_charonIdentifier = [_charonIdentifier copy];
    made->_charonAddressBookIdentifier = _charonAddressBookIdentifier;
    return made;
}

+ (NSString *)localizedStringForLabel:(NSString *)label
{
    if (!label)
        return nil;
    CFStringRef localized = ABAddressBookCopyLocalizedLabel((__bridge CFStringRef)label);
    return localized ? (__bridge_transfer NSString *)localized : label;
}

- (id)copyWithZone:(NSZone *)zone
{
    CNLabeledValue *copied = [[[self class] allocWithZone:zone] initWithLabel:_charonLabel value:[_charonValue copyWithZone:zone]];
    copied->_charonIdentifier = [_charonIdentifier copy];
    copied->_charonAddressBookIdentifier = _charonAddressBookIdentifier;
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonIdentifier forKey:@"identifier"];
    [coder encodeObject:_charonLabel forKey:@"label"];
    [coder encodeObject:_charonValue forKey:@"value"];
    [coder encodeInt:_charonAddressBookIdentifier forKey:@"addressBookIdentifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
        _charonLabel = [[coder decodeObjectOfClass:[NSString class] forKey:@"label"] copy];
        _charonValue = [coder decodeObjectForKey:@"value"];
        _charonAddressBookIdentifier = [coder decodeIntForKey:@"addressBookIdentifier"];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    if (![object isKindOfClass:[CNLabeledValue class]])
        return NO;
    CNLabeledValue *other = object;
    return [_charonIdentifier isEqualToString:other.identifier]
        && (_charonLabel == other.label || [_charonLabel isEqual:other.label])
        && (_charonValue == other.value || [_charonValue isEqual:other.value]);
}

- (NSUInteger)hash
{
    return _charonIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: label=%@, value=%@>", NSStringFromClass([self class]), self, _charonLabel, _charonValue];
}

@end
