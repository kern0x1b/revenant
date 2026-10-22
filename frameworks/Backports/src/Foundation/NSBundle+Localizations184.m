#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSBundle (RevenantLocalizations184)

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName localizations:(NSArray<NSString *> *)localizations
{
    NSString *table = tableName.length ? tableName : @"Localizable";
    NSArray *chosen = localizations.count ? [NSBundle preferredLocalizationsFromArray:self.localizations forPreferences:localizations] : nil;
    if (!chosen.count && self.developmentLocalization)
        chosen = @[self.developmentLocalization];
    for (NSString *localization in chosen) {
        NSString *file = [self pathForResource:table ofType:@"strings" inDirectory:nil forLocalization:localization];
        NSDictionary *strings = file ? [NSDictionary dictionaryWithContentsOfFile:file] : nil;
        id found = strings[key];
        if ([found isKindOfClass:[NSString class]])
            return found;
    }
    return value ?: key;
}

@end
