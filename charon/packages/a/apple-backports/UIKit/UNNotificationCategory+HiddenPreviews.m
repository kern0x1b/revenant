#import "CharonUserNotifications.h"
#import <objc/runtime.h>

static const char charon_placeholder_key;
static const char charon_summary_key;

@implementation UNNotificationCategory (CharonHiddenPreviews)

+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
              hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder options:(UNNotificationCategoryOptions)options
{
    return [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intentIdentifiers hiddenPreviewsBodyPlaceholder:hiddenPreviewsBodyPlaceholder categorySummaryFormat:@"" options:options];
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray<UNNotificationAction *> *)actions intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
              hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder categorySummaryFormat:(NSString *)categorySummaryFormat options:(UNNotificationCategoryOptions)options
{
    UNNotificationCategory *category = [self categoryWithIdentifier:identifier actions:actions intentIdentifiers:intentIdentifiers options:options];
    objc_setAssociatedObject(category, &charon_placeholder_key, [hiddenPreviewsBodyPlaceholder copy] ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(category, &charon_summary_key, [categorySummaryFormat copy] ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return category;
}

static NSString *charon_held(id category, const void *key)
{
    id held = objc_getAssociatedObject(category, key);
    return held == [NSNull null] ? nil : (held ?: @"");
}

- (NSString *)hiddenPreviewsBodyPlaceholder
{
    return charon_held(self, &charon_placeholder_key);
}

- (NSString *)categorySummaryFormat
{
    return charon_held(self, &charon_summary_key);
}

@end
