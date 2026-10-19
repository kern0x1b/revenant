#import <Foundation/Foundation.h>
#import <objc/runtime.h>

const float NSURLSessionTaskPriorityDefault = 0.5f;
const float NSURLSessionTaskPriorityLow = 0.25f;
const float NSURLSessionTaskPriorityHigh = 0.75f;

static char RevenantPriorityKey;

@implementation NSURLSessionTask (RevenantPriority)

- (float)priority
{
    NSNumber *priority = objc_getAssociatedObject(self, &RevenantPriorityKey);
    return priority ? priority.floatValue : NSURLSessionTaskPriorityDefault;
}

- (void)setPriority:(float)priority
{
    if (priority < 0 || priority > 1)
        return;
    objc_setAssociatedObject(self, &RevenantPriorityKey, @(priority), OBJC_ASSOCIATION_RETAIN);
}

@end
