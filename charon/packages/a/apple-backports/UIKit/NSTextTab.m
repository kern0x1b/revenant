#import <UIKit/UIKit.h>
#import "../charon_alias.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

CHARON_ALIAS(NSTextTab)

@implementation NSTextTab (CharonColumns)

+ (NSCharacterSet *)columnTerminatorsForLocale:(NSLocale *)locale
{
    NSString *separator = locale ? [locale objectForKey:NSLocaleDecimalSeparator] : @".";
    return [NSCharacterSet characterSetWithCharactersInString:separator.length ? separator : @"."];
}

@end
