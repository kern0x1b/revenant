#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString * const CNPostalAddressPropertyAttribute = @"CNPostalAddressProperty";
NSString * const CNPostalAddressLocalizedPropertyNameAttribute = @"CNPostalAddressLocalizedPropertyName";

@implementation CNPostalAddressFormatter {
    CNPostalAddressFormatterStyle _charonStyle;
}

@dynamic style;

- (CNPostalAddressFormatterStyle)style { return _charonStyle; }
- (void)setStyle:(CNPostalAddressFormatterStyle)style { _charonStyle = style; }

+ (NSArray<NSArray *> *)charon_linesForAddress:(CNPostalAddress *)address
{
    NSMutableArray *lines = [NSMutableArray array];
    if (address.street.length > 0)
        [lines addObject:@[CNPostalAddressStreetKey, address.street]];
    NSMutableString *cityLine = [NSMutableString string];
    if (address.city.length > 0)
        [cityLine appendString:address.city];
    NSMutableString *stateZip = [NSMutableString string];
    if (address.state.length > 0)
        [stateZip appendString:address.state];
    if (address.postalCode.length > 0) {
        if (stateZip.length > 0)
            [stateZip appendString:@" "];
        [stateZip appendString:address.postalCode];
    }
    if (stateZip.length > 0) {
        if (cityLine.length > 0)
            [cityLine appendString:@" "];
        [cityLine appendString:stateZip];
    }
    if (cityLine.length > 0)
        [lines addObject:@[CNPostalAddressCityKey, cityLine]];
    if (address.country.length > 0)
        [lines addObject:@[CNPostalAddressCountryKey, address.country]];
    return lines;
}

+ (NSString *)stringFromPostalAddress:(CNPostalAddress *)postalAddress style:(CNPostalAddressFormatterStyle)style
{
    NSMutableArray *texts = [NSMutableArray array];
    for (NSArray *line in [self charon_linesForAddress:postalAddress])
        [texts addObject:line[1]];
    return [texts componentsJoinedByString:@"\n"];
}

+ (NSAttributedString *)attributedStringFromPostalAddress:(CNPostalAddress *)postalAddress style:(CNPostalAddressFormatterStyle)style
                                     withDefaultAttributes:(NSDictionary *)attributes
{
    NSMutableAttributedString *built = [[NSMutableAttributedString alloc] init];
    NSArray *lines = [self charon_linesForAddress:postalAddress];
    for (NSUInteger index = 0; index < lines.count; index++) {
        NSArray *line = lines[index];
        NSString *property = line[0];
        NSString *text = line[1];
        if (index > 0)
            [built appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:attributes]];
        NSMutableDictionary *runAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes ?: @{}];
        runAttributes[CNPostalAddressPropertyAttribute] = property;
        runAttributes[CNPostalAddressLocalizedPropertyNameAttribute] = [CNContact localizedStringForKey:property];
        [built appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:runAttributes]];
    }
    return built;
}

- (NSString *)stringFromPostalAddress:(CNPostalAddress *)postalAddress
{
    return [[self class] stringFromPostalAddress:postalAddress style:_charonStyle];
}

- (NSAttributedString *)attributedStringFromPostalAddress:(CNPostalAddress *)postalAddress withDefaultAttributes:(NSDictionary *)attributes
{
    return [[self class] attributedStringFromPostalAddress:postalAddress style:_charonStyle withDefaultAttributes:attributes];
}

- (NSString *)stringForObjectValue:(id)object
{
    return [object isKindOfClass:[CNPostalAddress class]] ? [self stringFromPostalAddress:object] : nil;
}

@end
