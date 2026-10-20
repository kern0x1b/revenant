#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantAllowsEvaluationKey;

static BOOL revenant_allows_evaluation(id object)
{
    NSNumber *stored = objc_getAssociatedObject(object, &RevenantAllowsEvaluationKey);
    return stored ? stored.boolValue : YES;
}

@implementation NSPredicate (RevenantAllowEvaluation)

- (void)allowEvaluation
{
    objc_setAssociatedObject(self, &RevenantAllowsEvaluationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsEvaluation
{
    return revenant_allows_evaluation(self);
}

@end

@implementation NSSortDescriptor (RevenantAllowEvaluation)

- (void)allowEvaluation
{
    objc_setAssociatedObject(self, &RevenantAllowsEvaluationKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsEvaluation
{
    return revenant_allows_evaluation(self);
}

@end
