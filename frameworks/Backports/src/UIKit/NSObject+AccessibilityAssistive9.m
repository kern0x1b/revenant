#import <UIKit/UIKit.h>

@implementation NSObject (RevenantAccessibilityAssistive9)

- (NSSet<UIAccessibilityAssistiveTechnologyIdentifier> *)accessibilityAssistiveTechnologyFocusedIdentifiers
{
    if (UIAccessibilityIsVoiceOverRunning() && [self accessibilityElementIsFocused])
        return [NSSet setWithObject:UIAccessibilityNotificationVoiceOverIdentifier];
    return [NSSet set];
}

@end
