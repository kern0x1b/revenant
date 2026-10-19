#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *CharonUserActivityKey = &CharonUserActivityKey;

@implementation UIResponder (CharonUserActivity)

- (NSUserActivity *)userActivity
{
    return objc_getAssociatedObject(self, CharonUserActivityKey);
}

- (void)setUserActivity:(NSUserActivity *)activity
{
    objc_setAssociatedObject(self, CharonUserActivityKey, activity, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
}

- (void)restoreUserActivityState:(NSUserActivity *)activity
{
}

@end
