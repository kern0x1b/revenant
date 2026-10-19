#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantUserActivityKey = &RevenantUserActivityKey;

@implementation UIResponder (RevenantUserActivity)

- (NSUserActivity *)userActivity
{
    return objc_getAssociatedObject(self, RevenantUserActivityKey);
}

- (void)setUserActivity:(NSUserActivity *)activity
{
    objc_setAssociatedObject(self, RevenantUserActivityKey, activity, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
}

@end
