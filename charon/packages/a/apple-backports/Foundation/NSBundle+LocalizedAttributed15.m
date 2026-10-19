#import <Foundation/Foundation.h>

/* The attributed string a bundle's table answers, of iOS 15.0.

   -localizedStringForKey:value:table: returns an NSString and this returns the same text with the
   language it was found in on it, so an application that lays the text out knows which localisation it
   is looking at. Measured against the system's own Foundation by tests/backports/host/attributed15/run.sh:
   a key the table does not carry answers the value the caller passed, tagged with
   NSLanguageIdentifierAttributeName and the bundle's own current localisation, and a key it does carry
   answers the table's text tagged the same way.

   The lookup itself is the release's own: -localizedStringForKey:value:table: is 6.1.3's, reads the same
   .strings and .stringsdict and answers the same string, and the only thing added here is the attribute.
   A second reader of the tables would answer differently from the release's on every rule the format has
   and none of them is written down. */

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
