#import <Foundation/Foundation.h>

@implementation NSBundle (CharonLocalizedAttributed15)

- (NSAttributedString *)localizedAttributedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName
{
    NSString *found = [self localizedStringForKey:key value:value table:tableName];
    NSString *language = [[self preferredLocalizations] firstObject] ?: [[NSLocale preferredLanguages] firstObject];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (language)
        attributes[NSLanguageIdentifierAttributeName] = language;
    return [[NSAttributedString alloc] initWithString:found ?: @"" attributes:attributes];
}

@end
