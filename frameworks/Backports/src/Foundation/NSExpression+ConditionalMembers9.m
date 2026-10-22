#import <Foundation/Foundation.h>
#import "RevenantMethodProem.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSExpression (RevenantConditionalMembers9)

- (NSExpression *)trueExpression
{
    [NSException raise:NSInvalidArgumentException format:@"%@: only a conditional expression has a true expression", revenant_method_proem(self, _cmd)];
    return nil;
}

- (NSExpression *)falseExpression
{
    [NSException raise:NSInvalidArgumentException format:@"%@: only a conditional expression has a false expression", revenant_method_proem(self, _cmd)];
    return nil;
}

@end
