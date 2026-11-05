#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_priority_key;

@implementation UIKeyCommand (RevenantPriority)

- (BOOL)wantsPriorityOverSystemBehavior
{
    return [objc_getAssociatedObject(self, &revenant_priority_key) boolValue];
}

- (void)setWantsPriorityOverSystemBehavior:(BOOL)wantsPriorityOverSystemBehavior
{
    if (wantsPriorityOverSystemBehavior) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"UIKeyCommand.wantsPriorityOverSystemBehavior is kept and not applied on iOS 6: the system's own key shortcuts are handled before an application sees a key");
        });
    }
    objc_setAssociatedObject(self, &revenant_priority_key, @(wantsPriorityOverSystemBehavior), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
