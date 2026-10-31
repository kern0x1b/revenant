#import "RevenantUserNotifications.h"
#import <objc/runtime.h>

static const char revenant_placeholder_key;
static const char revenant_summary_key;

@implementation UNNotificationCategory (RevenantHiddenPreviews)

+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
              hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder options:(UNNotificationCategoryOptions)options
{
    return [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intentIdentifiers hiddenPreviewsBodyPlaceholder:hiddenPreviewsBodyPlaceholder categorySummaryFormat:@"" options:options];
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
              hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder categorySummaryFormat:(NSString *)categorySummaryFormat options:(UNNotificationCategoryOptions)options
{
    UNNotificationCategory *category = [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intentIdentifiers options:options];
    objc_setAssociatedObject(category, &revenant_placeholder_key, [hiddenPreviewsBodyPlaceholder copy] ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(category, &revenant_summary_key, [categorySummaryFormat copy] ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return category;
}

static NSString *revenant_held(id category, const void *key)
{
    id held = objc_getAssociatedObject(category, key);
    return held == [NSNull null] ? nil : (held ?: @"");
}

- (NSString *)hiddenPreviewsBodyPlaceholder
{
    return revenant_held(self, &revenant_placeholder_key);
}

- (NSString *)categorySummaryFormat
{
    return revenant_held(self, &revenant_summary_key);
}

@end
