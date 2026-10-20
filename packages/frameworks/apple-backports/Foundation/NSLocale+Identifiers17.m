#import <Foundation/Foundation.h>

@implementation NSLocale (RevenantIdentifiers17)

- (NSString *)languageIdentifier
{
    NSString *identifier = self.localeIdentifier;
    if (!identifier)
        return nil;
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
                return value.length < 2 ? (value.length ? [value uppercaseString] : nil) : [[value substringToIndex:2] uppercaseString];
            }
        }
    }
    return [self objectForKey:NSLocaleCountryCode];
}

@end
