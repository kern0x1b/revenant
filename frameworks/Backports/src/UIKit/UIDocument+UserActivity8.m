#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *RevenantDocumentActivityKey = &RevenantDocumentActivityKey;

@implementation UIDocument (RevenantUserActivity8)

- (NSUserActivity *)userActivity
{
    return objc_getAssociatedObject(self, RevenantDocumentActivityKey);
}

- (void)setUserActivity:(NSUserActivity *)userActivity
{
    objc_setAssociatedObject(self, RevenantDocumentActivityKey, userActivity, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)updateUserActivityState:(NSUserActivity *)userActivity
{
}

- (void)restoreUserActivityState:(NSUserActivity *)userActivity
{
}

@end
