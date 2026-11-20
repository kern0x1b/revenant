#import <AVFoundation/AVFoundation.h>

@implementation AVMediaSelectionOption (RevenantDisplayName7)

- (NSString *)displayName
{
    NSString *language = [self.locale objectForKey:NSLocaleLanguageCode];
    if (language.length) {
        NSString *name = [[NSLocale currentLocale] displayNameForKey:NSLocaleLanguageCode value:language];
        if (name.length)
            return name;
    }
    return @"";
}

@end
