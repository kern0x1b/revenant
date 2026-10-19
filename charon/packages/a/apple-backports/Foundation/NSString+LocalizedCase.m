#import <Foundation/Foundation.h>

static NSRange charon_localized_standard_range(NSString *string, NSString *search)
{
    return [string rangeOfString:search options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, string.length) locale:[NSLocale currentLocale]];
}

@implementation NSString (CharonLocalizedCase)

- (NSString *)localizedUppercaseString
{
    return [self uppercaseStringWithLocale:[NSLocale currentLocale]];
}

- (NSString *)localizedLowercaseString
{
    return [self lowercaseStringWithLocale:[NSLocale currentLocale]];
}

- (NSString *)localizedCapitalizedString
{
    return [self capitalizedStringWithLocale:[NSLocale currentLocale]];
}

- (BOOL)localizedStandardContainsString:(NSString *)str
{
    return charon_localized_standard_range(self, str).location != NSNotFound;
}

- (NSRange)localizedStandardRangeOfString:(NSString *)str
{
    return charon_localized_standard_range(self, str);
}

@end
