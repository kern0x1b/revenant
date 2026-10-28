#import "RevenantAnimationDuration.h"

const NSTimeInterval RevenantAnimationDurationDefault = 0.2;

static NSString *const RevenantAnimationDurationStackKey = @"space.kern0x1b.revenant.animation-duration";

@interface RevenantAnimationGroup : NSObject
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) float repeatCount;
@property (nonatomic) BOOL autoreverses;
@end

@implementation RevenantAnimationGroup
@synthesize duration = _duration;
@synthesize repeatCount = _repeatCount;
@synthesize autoreverses = _autoreverses;
@end

static NSMutableArray<RevenantAnimationGroup *> *RevenantAnimationGroupStack(void)
{
    NSMutableDictionary *dictionary = [NSThread currentThread].threadDictionary;
    NSMutableArray<RevenantAnimationGroup *> *stack = dictionary[RevenantAnimationDurationStackKey];
    if (!stack) {
        stack = [NSMutableArray array];
        dictionary[RevenantAnimationDurationStackKey] = stack;
    }
    return stack;
}

static RevenantAnimationGroup *RevenantAnimationGroupCurrent(void)
{
    return RevenantAnimationGroupStack().lastObject;
}

NSTimeInterval RevenantAnimationDurationInherited(void)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    return group ? group.duration : 0;
}

void RevenantAnimationDurationPush(NSTimeInterval duration)
{
    RevenantAnimationGroup *group = [[RevenantAnimationGroup alloc] init];
    group.duration = duration;
    [RevenantAnimationGroupStack() addObject:group];
}

void RevenantAnimationDurationSetCurrent(NSTimeInterval duration)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    if (group)
        group.duration = duration;
}

void RevenantAnimationDurationPop(void)
{
    NSMutableArray<RevenantAnimationGroup *> *stack = RevenantAnimationGroupStack();
    if (stack.count)
        [stack removeLastObject];
}

float RevenantAnimationGroupRepeatCount(void)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    return group ? group.repeatCount : 0;
}

void RevenantAnimationGroupSetRepeatCount(float count)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    if (group)
        group.repeatCount = count;
}

BOOL RevenantAnimationGroupAutoreverses(void)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    return group ? group.autoreverses : NO;
}

void RevenantAnimationGroupSetAutoreverses(BOOL autoreverses)
{
    RevenantAnimationGroup *group = RevenantAnimationGroupCurrent();
    if (group)
        group.autoreverses = autoreverses;
}
