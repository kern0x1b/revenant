#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_localization_key;
static const char charon_mirroring_key;
static const char charon_priority_key;

@implementation UIKeyCommand (CharonPriority)

- (BOOL)allowsAutomaticLocalization
{
    NSNumber *kept = objc_getAssociatedObject(self, &charon_localization_key);
    return kept ? kept.boolValue : YES;
}

- (void)setAllowsAutomaticLocalization:(BOOL)allowsAutomaticLocalization
{
    objc_setAssociatedObject(self, &charon_localization_key, @(allowsAutomaticLocalization), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsAutomaticMirroring
{
    NSNumber *kept = objc_getAssociatedObject(self, &charon_mirroring_key);
    return kept ? kept.boolValue : YES;
}

- (void)setAllowsAutomaticMirroring:(BOOL)allowsAutomaticMirroring
{
    objc_setAssociatedObject(self, &charon_mirroring_key, @(allowsAutomaticMirroring), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)wantsPriorityOverSystemBehavior
{
    return [objc_getAssociatedObject(self, &charon_priority_key) boolValue];
}

- (void)setWantsPriorityOverSystemBehavior:(BOOL)wantsPriorityOverSystemBehavior
{
    if (wantsPriorityOverSystemBehavior) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"UIKeyCommand.wantsPriorityOverSystemBehavior is kept and not applied on iOS 6: the system's own key shortcuts are handled before an application sees a key");
        });
    }
    objc_setAssociatedObject(self, &charon_priority_key, @(wantsPriorityOverSystemBehavior), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
