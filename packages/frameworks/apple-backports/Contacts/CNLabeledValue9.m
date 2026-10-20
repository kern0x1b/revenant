#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNLabeledValue {
    NSString *_revenantIdentifier;
    NSString *_revenantLabel;
    id _revenantValue;
    ABMultiValueIdentifier _revenantAddressBookIdentifier;
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
        _revenantIdentifier = [[NSUUID UUID] UUIDString];
        _revenantLabel = [label copy];
        _revenantValue = [value copyWithZone:NULL];
        _revenantAddressBookIdentifier = kABMultiValueInvalidIdentifier;
    }
    return self;
}

+ (instancetype)revenant_labeledValueWithLabel:(NSString *)label value:(id)value identifier:(ABMultiValueIdentifier)identifier
{
    CNLabeledValue *labeled = [[self alloc] initWithLabel:label value:value];
    labeled->_revenantAddressBookIdentifier = identifier;
    return labeled;
}

- (ABMultiValueIdentifier)revenant_addressBookIdentifier
{
    return _revenantAddressBookIdentifier;
}

- (NSString *)identifier
{
    return _revenantIdentifier;
}

- (NSString *)label
{
    return _revenantLabel;
}

- (id)value
{
    return _revenantValue;
}

- (instancetype)labeledValueBySettingLabel:(NSString *)label
{
    return [self labeledValueBySettingLabel:label value:_revenantValue];
}

- (instancetype)labeledValueBySettingValue:(id)value
{
    return [self labeledValueBySettingLabel:_revenantLabel value:value];
}

- (instancetype)labeledValueBySettingLabel:(NSString *)label value:(id)value
{
    CNLabeledValue *made = [[[self class] alloc] initWithLabel:label value:value];
    made->_revenantIdentifier = [_revenantIdentifier copy];
    made->_revenantAddressBookIdentifier = _revenantAddressBookIdentifier;
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
    CNLabeledValue *copied = [[[self class] allocWithZone:zone] initWithLabel:_revenantLabel value:[_revenantValue copyWithZone:zone]];
    copied->_revenantIdentifier = [_revenantIdentifier copy];
    copied->_revenantAddressBookIdentifier = _revenantAddressBookIdentifier;
    return copied;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantIdentifier forKey:@"identifier"];
    [coder encodeObject:_revenantLabel forKey:@"label"];
    [coder encodeObject:_revenantValue forKey:@"value"];
    [coder encodeInt:_revenantAddressBookIdentifier forKey:@"addressBookIdentifier"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy];
        _revenantLabel = [[coder decodeObjectOfClass:[NSString class] forKey:@"label"] copy];
        _revenantValue = [coder decodeObjectForKey:@"value"];
        _revenantAddressBookIdentifier = [coder decodeIntForKey:@"addressBookIdentifier"];
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
    return [_revenantIdentifier isEqualToString:other.identifier]
        && (_revenantLabel == other.label || [_revenantLabel isEqual:other.label])
        && (_revenantValue == other.value || [_revenantValue isEqual:other.value]);
}

- (NSUInteger)hash
{
    return _revenantIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p: label=%@, value=%@>", NSStringFromClass([self class]), self, _revenantLabel, _revenantValue];
}

@end
