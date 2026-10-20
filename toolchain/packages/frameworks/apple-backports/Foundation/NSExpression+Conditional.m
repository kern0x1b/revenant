#import <Foundation/Foundation.h>

@interface NSExpression (RevenantTernary)
+ (NSExpression *)expressionForTernaryWithPredicate:(NSPredicate *)predicate trueExpression:(NSExpression *)trueExpression falseExpression:(NSExpression *)falseExpression;
@end

@implementation NSExpression (RevenantConditional)

+ (NSExpression *)expressionForConditional:(NSPredicate *)predicate trueExpression:(NSExpression *)trueExpression falseExpression:(NSExpression *)falseExpression
{
    return [NSExpression expressionForTernaryWithPredicate:predicate trueExpression:trueExpression falseExpression:falseExpression];
}

@end
