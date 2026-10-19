#import <Foundation/Foundation.h>

@interface NSExpression (CharonTernary)
+ (NSExpression *)expressionForTernaryWithPredicate:(NSPredicate *)predicate trueExpression:(NSExpression *)trueExpression falseExpression:(NSExpression *)falseExpression;
@end

@implementation NSExpression (CharonConditional)

+ (NSExpression *)expressionForConditional:(NSPredicate *)predicate trueExpression:(NSExpression *)trueExpression falseExpression:(NSExpression *)falseExpression
{
    return [NSExpression expressionForTernaryWithPredicate:predicate trueExpression:trueExpression falseExpression:falseExpression];
}

@end
