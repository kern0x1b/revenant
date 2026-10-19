#import <Foundation/Foundation.h>

@implementation NSLocale (CharonComponents)

- (NSString *)languageCode
{
    return [self objectForKey:NSLocaleLanguageCode];
}

- (NSString *)countryCode
{
    return [self objectForKey:NSLocaleCountryCode];
}

- (NSString *)scriptCode
{
    return [self objectForKey:NSLocaleScriptCode];
}

- (NSString *)variantCode
{
    return [self objectForKey:NSLocaleVariantCode];
}

- (NSCharacterSet *)exemplarCharacterSet
{
    return [self objectForKey:NSLocaleExemplarCharacterSet];
}

- (NSString *)calendarIdentifier
{
    NSCalendar *calendar = [self objectForKey:NSLocaleCalendar];
    return calendar.calendarIdentifier;
}

- (NSString *)collationIdentifier
{
    return [self objectForKey:NSLocaleCollationIdentifier];
}

- (BOOL)usesMetricSystem
{
    return [[self objectForKey:NSLocaleUsesMetricSystem] boolValue];
}

- (NSString *)decimalSeparator
{
    return [self objectForKey:NSLocaleDecimalSeparator];
}

- (NSString *)groupingSeparator
{
    return [self objectForKey:NSLocaleGroupingSeparator];
}

- (NSString *)currencySymbol
{
    return [self objectForKey:NSLocaleCurrencySymbol];
}

- (NSString *)currencyCode
{
    return [self objectForKey:NSLocaleCurrencyCode];
}

- (NSString *)collatorIdentifier
{
    return [self objectForKey:NSLocaleCollatorIdentifier];
}

- (NSString *)quotationBeginDelimiter
{
    return [self objectForKey:NSLocaleQuotationBeginDelimiterKey];
}

- (NSString *)quotationEndDelimiter
{
    return [self objectForKey:NSLocaleQuotationEndDelimiterKey];
}

- (NSString *)alternateQuotationBeginDelimiter
{
    return [self objectForKey:NSLocaleAlternateQuotationBeginDelimiterKey];
}

- (NSString *)alternateQuotationEndDelimiter
{
    return [self objectForKey:NSLocaleAlternateQuotationEndDelimiterKey];
}

- (NSString *)localizedStringForLocaleIdentifier:(NSString *)localeIdentifier
{
    return [self displayNameForKey:NSLocaleIdentifier value:localeIdentifier];
}

- (NSString *)localizedStringForLanguageCode:(NSString *)languageCode
{
    return [self displayNameForKey:NSLocaleLanguageCode value:languageCode];
}

- (NSString *)localizedStringForCountryCode:(NSString *)countryCode
{
    return [self displayNameForKey:NSLocaleCountryCode value:countryCode];
}

- (NSString *)localizedStringForScriptCode:(NSString *)scriptCode
{
    return [self displayNameForKey:NSLocaleScriptCode value:scriptCode];
}

- (NSString *)localizedStringForVariantCode:(NSString *)variantCode
{
    return [self displayNameForKey:NSLocaleVariantCode value:variantCode];
}

- (NSString *)localizedStringForCalendarIdentifier:(NSString *)calendarIdentifier
{
    return [self displayNameForKey:NSLocaleCalendar value:calendarIdentifier];
}

- (NSString *)localizedStringForCollationIdentifier:(NSString *)collationIdentifier
{
    return [self displayNameForKey:NSLocaleCollationIdentifier value:collationIdentifier];
}

- (NSString *)localizedStringForCurrencyCode:(NSString *)currencyCode
{
    return [self displayNameForKey:NSLocaleCurrencyCode value:currencyCode];
}

- (NSString *)localizedStringForCollatorIdentifier:(NSString *)collatorIdentifier
{
    return [self displayNameForKey:NSLocaleCollatorIdentifier value:collatorIdentifier];
}

@end
