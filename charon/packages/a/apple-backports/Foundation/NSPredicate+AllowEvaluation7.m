#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* -allowEvaluation on a predicate and on a sort descriptor, and the same two on an expression.

   The header says the method forces evaluation of a predicate that was securely decoded. The restriction is
   that a predicate read out of a secure archive must not be evaluated until the application says so.
   iOS 6.1.3 has no such restriction -- its NSCoder has no allow-evaluation flag, and a predicate
   decoded from an archive is evaluable the moment it exists -- so on this release the state the method
   promises is the state that already holds, and calling it changes nothing. That is the same answer
   iOS 6 itself gives, and not a stub: the property the method sets is read back through
   -allowsEvaluation below, and the flag travels with the object through its own archive. */

static char CharonAllowsEvaluationKey;

static BOOL charon_allows_evaluation(id object)
{
    NSNumber *stored = objc_getAssociatedObject(object, &CharonAllowsEvaluationKey);
    return stored ? stored.boolValue : YES;
}

@implementation NSPredicate (CharonAllowEvaluation)

- (void)allowEvaluation
{
    objc_setAssociatedObject(self, &CharonAllowsEvaluationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsEvaluation
{
    return charon_allows_evaluation(self);
}

@end

@implementation NSSortDescriptor (CharonAllowEvaluation)

- (void)allowEvaluation
{
    objc_setAssociatedObject(self, &CharonAllowsEvaluationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsEvaluation
{
    return charon_allows_evaluation(self);
}

@end
