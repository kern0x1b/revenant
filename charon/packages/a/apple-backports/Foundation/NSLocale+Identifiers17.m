#import <Foundation/Foundation.h>

/* NSLocale's languageIdentifier and regionCode, iOS 17.0. One object for this release and
   no other: both accessors are 17.0 in the SDK's own NSLocale.h and neither exists in any
   release this port builds, so a 15.0 or 18.0 accessor cannot share the file.

   The semantics are the SDK header's, read there and not guessed:

     languageIdentifier  The identifier of the language part: for en_US@rg=gbzzzz it is en-US.
                          The header gives this as its example.
     regionCode          The region of the locale. When the rg subtag is present, its value is used:
                          for en_US@rg=gbzzzz that is GB. Without a region, the result is nil (the header).

   Both are computed from what the release itself carries, measured class-scoped on the 6.0
   armv7 cache (7187 and 11284 classes read in the same runs, so a zero on another rung is
   the release's and not the reader's): NSLocale answers -localeIdentifier,
   -objectForKey:, +componentsFromLocaleIdentifier: and +canonicalLanguageIdentifierFromString:.
   The rg subtag is a BCP-47 extension CoreFoundation on 6.0 does not know, so it is read
   out of the identifier here rather than asked of the dictionary; facts/Foundation/
   NSLocaleIdentifiers.md carries the ladder and the commands. */

@implementation NSLocale (CharonIdentifiers17)

- (NSString *)languageIdentifier
{
    NSString *identifier = self.localeIdentifier;
    if (!identifier)
        return nil;
    /* The language part is what stands before the extensions: "en_US@rg=gbzzzz" formats
       as "en-US", so the underscore of a POSIX-style identifier becomes the BCP-47 hyphen
       and everything from "@" on is dropped. */
    NSRange extensions = [identifier rangeOfString:@"@"];
    NSString *language = extensions.location == NSNotFound ? identifier : [identifier substringToIndex:extensions.location];
    return [language stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
}

- (NSString *)regionCode
{
    NSString *identifier = self.localeIdentifier;
    if (identifier) {
        NSRange extensions = [identifier rangeOfString:@"@"];
        if (extensions.location != NSNotFound) {
            NSString *subtags = [identifier substringFromIndex:NSMaxRange(extensions)];
            for (NSString *subtag in [subtags componentsSeparatedByString:@";"]) {
                NSRange assign = [subtag rangeOfString:@"="];
                if (assign.location == NSNotFound || ![[subtag substringToIndex:assign.location] isEqualToString:@"rg"])
                    continue;
                NSString *value = [subtag substringFromIndex:NSMaxRange(assign)];
                /* rg carries a region followed by an optional variant: "gbzzzz" is the
                   region "gb" with the variant "zzzz", and the region is what the property
                   returns. */
                return value.length < 2 ? (value.length ? [value uppercaseString] : nil) : [[value substringToIndex:2] uppercaseString];
            }
        }
    }
    /* No rg subtag: the region is the country the locale names, and a locale that names
       none answers nil, as the header says. NSLocaleCountryCode is the release's own key. */
    return [self objectForKey:NSLocaleCountryCode];
}

@end