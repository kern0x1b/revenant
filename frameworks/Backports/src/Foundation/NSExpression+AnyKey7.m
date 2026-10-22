#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSExpression (RevenantAnyKey7)

+ (NSExpression *)expressionForAnyKey
{
    Class anyKey = NSClassFromString(@"NSAnyKeyExpression");
    if (anyKey)
        return [[anyKey alloc] init];
    return [NSExpression expressionWithFormat:@"ANYKEY"];
}

@end
