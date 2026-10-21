#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char RevenantNotificationCategoryKey;
static const char RevenantNotificationAlertTitleKey;

@implementation UILocalNotification (RevenantCategory8)

- (NSString *)category
{
    return objc_getAssociatedObject(self, &RevenantNotificationCategoryKey);
}

- (void)setCategory:(NSString *)category
{
    objc_setAssociatedObject(self, &RevenantNotificationCategoryKey, category, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)alertTitle
{
    return objc_getAssociatedObject(self, &RevenantNotificationAlertTitleKey);
}

- (void)setAlertTitle:(NSString *)alertTitle
{
    objc_setAssociatedObject(self, &RevenantNotificationAlertTitleKey, alertTitle, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
