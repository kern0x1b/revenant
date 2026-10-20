#import <UIKit/UIKit.h>
#import "../revenant_alias.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

REVENANT_ALIAS(NSTextTab)

@implementation NSTextTab (RevenantColumns)

+ (NSCharacterSet *)columnTerminatorsForLocale:(NSLocale *)locale
{
    NSString *separator = locale ? [locale objectForKey:NSLocaleDecimalSeparator] : @".";
    return [NSCharacterSet characterSetWithCharactersInString:separator.length ? separator : @"."];
}

@end
