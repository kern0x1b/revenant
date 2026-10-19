#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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
