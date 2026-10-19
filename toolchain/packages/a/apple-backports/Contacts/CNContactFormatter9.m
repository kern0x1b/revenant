#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContactFormatter {
    CNContactFormatterStyle _charonStyle;
}

@dynamic style;

+ (id<CNKeyDescriptor>)descriptorForRequiredKeysForStyle:(CNContactFormatterStyle)style
{
    NSArray *keys = @[CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey,
                      CNContactNameSuffixKey, CNContactNicknameKey, CNContactOrganizationNameKey, CNContactTypeKey,
                      CNContactPhoneticGivenNameKey, CNContactPhoneticMiddleNameKey, CNContactPhoneticFamilyNameKey];
    return [CharonContactsKeyDescriptor descriptorWithKeys:keys];
}

+ (id<CNKeyDescriptor>)descriptorForRequiredKeysForNameOrder
{
    return [self descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName];
}

+ (id<CNKeyDescriptor>)descriptorForRequiredKeysForDelimiter
{
    return [self descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName];
}

+ (NSString *)stringFromContact:(CNContact *)contact style:(CNContactFormatterStyle)style
{
    if (!contact)
        return nil;
    if (style == CNContactFormatterStylePhoneticFullName) {
        NSString *given = contact.phoneticGivenName, *middle = contact.phoneticMiddleName, *family = contact.phoneticFamilyName;
        NSMutableArray *parts = [NSMutableArray array];
        BOOL familyFirst = [self nameOrderForContact:contact] == CNContactDisplayNameOrderFamilyNameFirst;
        for (NSString *part in familyFirst ? @[family, middle, given] : @[given, middle, family]) {
            if (part.length > 0)
                [parts addObject:part];
        }
        if (parts.count == 0)
            return nil;
        return [parts componentsJoinedByString:[self delimiterForContact:contact]];
    }
    NSString *composite = [CharonContactsBook compositeNameOfContact:contact];
    return composite.length > 0 ? composite : nil;
}

+ (NSAttributedString *)attributedStringFromContact:(CNContact *)contact style:(CNContactFormatterStyle)style defaultAttributes:(NSDictionary *)attributes
{
    NSString *name = [self stringFromContact:contact style:style];
    if (!name)
        return nil;
    NSMutableAttributedString *written = [[NSMutableAttributedString alloc] initWithString:name attributes:attributes];
    NSArray *parts = style == CNContactFormatterStylePhoneticFullName
        ? @[@[contact.phoneticGivenName, CNContactPhoneticGivenNameKey], @[contact.phoneticMiddleName, CNContactPhoneticMiddleNameKey],
            @[contact.phoneticFamilyName, CNContactPhoneticFamilyNameKey]]
        : @[@[contact.namePrefix, CNContactNamePrefixKey], @[contact.givenName, CNContactGivenNameKey],
            @[contact.middleName, CNContactMiddleNameKey], @[contact.familyName, CNContactFamilyNameKey],
            @[contact.nameSuffix, CNContactNameSuffixKey], @[contact.organizationName, CNContactOrganizationNameKey]];
    for (NSArray *part in parts) {
        NSString *text = part[0];
        if (text.length == 0)
            continue;
        NSRange range = [name rangeOfString:text];
        if (range.location != NSNotFound)
            [written addAttribute:CNContactPropertyAttribute value:part[1] range:range];
    }
    return written;
}

+ (CNContactDisplayNameOrder)nameOrderForContact:(CNContact *)contact
{
    return ABPersonGetCompositeNameFormat() == kABPersonCompositeNameFormatLastNameFirst
        ? CNContactDisplayNameOrderFamilyNameFirst : CNContactDisplayNameOrderGivenNameFirst;
}

+ (NSString *)delimiterForContact:(CNContact *)contact
{
    NSString *given = contact.givenName, *family = contact.familyName;
    NSString *composite = [CharonContactsBook compositeNameOfContact:contact];
    if (given.length > 0 && family.length > 0 && composite.length > 0) {
        NSRange first = [composite rangeOfString:given];
        NSRange second = [composite rangeOfString:family];
        if (first.location != NSNotFound && second.location != NSNotFound) {
            NSRange between = first.location < second.location
                ? NSMakeRange(NSMaxRange(first), second.location - NSMaxRange(first))
                : NSMakeRange(NSMaxRange(second), first.location - NSMaxRange(second));
            if (between.location <= composite.length && NSMaxRange(between) <= composite.length)
                return [composite substringWithRange:between];
        }
    }
    static NSString *usual;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ABRecordRef probe = ABPersonCreate();
        ABRecordSetValue(probe, kABPersonFirstNameProperty, CFSTR("A"), NULL);
        ABRecordSetValue(probe, kABPersonLastNameProperty, CFSTR("B"), NULL);
        CFStringRef name = ABRecordCopyCompositeName(probe);
        NSString *held = name ? (__bridge_transfer NSString *)name : nil;
        CFRelease(probe);
        usual = @" ";
        if (held.length >= 2) {
            NSRange left = [held rangeOfString:@"A"];
            NSRange right = [held rangeOfString:@"B"];
            if (left.location != NSNotFound && right.location != NSNotFound) {
                NSRange between = left.location < right.location
                    ? NSMakeRange(NSMaxRange(left), right.location - NSMaxRange(left))
                    : NSMakeRange(NSMaxRange(right), left.location - NSMaxRange(right));
                usual = [held substringWithRange:between];
            }
        }
    });
    return usual;
}

- (CNContactFormatterStyle)style
{
    return _charonStyle;
}

- (void)setStyle:(CNContactFormatterStyle)style
{
    _charonStyle = style;
}

- (NSString *)stringFromContact:(CNContact *)contact
{
    return [[self class] stringFromContact:contact style:_charonStyle];
}

- (NSAttributedString *)attributedStringFromContact:(CNContact *)contact defaultAttributes:(NSDictionary *)attributes
{
    return [[self class] attributedStringFromContact:contact style:_charonStyle defaultAttributes:attributes];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[CNContact class]] ? [self stringFromContact:object] : nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:_charonStyle forKey:@"style"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        _charonStyle = (CNContactFormatterStyle)[coder decodeIntegerForKey:@"style"];
    return self;
}

@end
