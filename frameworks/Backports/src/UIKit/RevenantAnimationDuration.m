#import "RevenantAnimationDuration.h"

const NSTimeInterval RevenantAnimationDurationDefault = 0.2;

static NSString *const RevenantAnimationDurationStackKey = @"space.kern0x1b.revenant.animation-duration";

static NSMutableArray<NSNumber *> *RevenantAnimationDurationStack(void)
{
    NSMutableDictionary *dictionary = [NSThread currentThread].threadDictionary;
    NSMutableArray<NSNumber *> *stack = dictionary[RevenantAnimationDurationStackKey];
    if (!stack) {
        stack = [NSMutableArray array];
        dictionary[RevenantAnimationDurationStackKey] = stack;
    }
    return stack;
}

NSTimeInterval RevenantAnimationDurationInherited(void)
{
    NSMutableArray<NSNumber *> *stack = RevenantAnimationDurationStack();
    return stack.count ? stack.lastObject.doubleValue : 0;
}

void RevenantAnimationDurationPush(NSTimeInterval duration)
{
    [RevenantAnimationDurationStack() addObject:@(duration)];
}

void RevenantAnimationDurationSetCurrent(NSTimeInterval duration)
{
    NSMutableArray<NSNumber *> *stack = RevenantAnimationDurationStack();
    if (stack.count)
        stack[stack.count - 1] = @(duration);
}

void RevenantAnimationDurationPop(void)
{
    NSMutableArray<NSNumber *> *stack = RevenantAnimationDurationStack();
    if (stack.count)
        [stack removeLastObject];
}
