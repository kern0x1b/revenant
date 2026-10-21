#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantAllowsFocusKey;
static const char RevenantAllowsFocusEditingKey;
static const char RevenantRoundsToIntervalKey;
static const char RevenantShowsOrientationKey;
static const char RevenantProminentActivityKey;
static const char RevenantChangesSelectionKey;

@implementation UITableView (RevenantFocusAllowance15)

- (BOOL)allowsFocus
{
    return [objc_getAssociatedObject(self, &RevenantAllowsFocusKey) boolValue];
}

- (void)setAllowsFocus:(BOOL)allowsFocus
{
    objc_setAssociatedObject(self, &RevenantAllowsFocusKey, @(allowsFocus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsFocusDuringEditing
{
    return [objc_getAssociatedObject(self, &RevenantAllowsFocusEditingKey) boolValue];
}

- (void)setAllowsFocusDuringEditing:(BOOL)allowsFocusDuringEditing
{
    objc_setAssociatedObject(self, &RevenantAllowsFocusEditingKey, @(allowsFocusDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionView (RevenantFocusAllowance15)

- (BOOL)allowsFocus
{
    return [objc_getAssociatedObject(self, &RevenantAllowsFocusKey) boolValue];
}

- (void)setAllowsFocus:(BOOL)allowsFocus
{
    objc_setAssociatedObject(self, &RevenantAllowsFocusKey, @(allowsFocus), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)allowsFocusDuringEditing
{
    return [objc_getAssociatedObject(self, &RevenantAllowsFocusEditingKey) boolValue];
}

- (void)setAllowsFocusDuringEditing:(BOOL)allowsFocusDuringEditing
{
    objc_setAssociatedObject(self, &RevenantAllowsFocusEditingKey, @(allowsFocusDuringEditing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIDatePicker (RevenantRounding15)

- (BOOL)roundsToMinuteInterval
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantRoundsToIntervalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setRoundsToMinuteInterval:(BOOL)roundsToMinuteInterval
{
    objc_setAssociatedObject(self, &RevenantRoundsToIntervalKey, @(roundsToMinuteInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIPrintInteractionController (RevenantOrientation15)

- (BOOL)showsPaperOrientation
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantShowsOrientationKey);
    return stored ? stored.boolValue : YES;
}

- (void)setShowsPaperOrientation:(BOOL)showsPaperOrientation
{
    objc_setAssociatedObject(self, &RevenantShowsOrientationKey, @(showsPaperOrientation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIActivityViewController (RevenantProminent15)

- (BOOL)allowsProminentActivity
{
    return [objc_getAssociatedObject(self, &RevenantProminentActivityKey) boolValue];
}

- (void)setAllowsProminentActivity:(BOOL)allowsProminentActivity
{
    objc_setAssociatedObject(self, &RevenantProminentActivityKey, @(allowsProminentActivity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIBarButtonItem (RevenantSelection15)

- (BOOL)changesSelectionAsPrimaryAction
{
    return [objc_getAssociatedObject(self, &RevenantChangesSelectionKey) boolValue];
}

- (void)setChangesSelectionAsPrimaryAction:(BOOL)changesSelectionAsPrimaryAction
{
    objc_setAssociatedObject(self, &RevenantChangesSelectionKey, @(changesSelectionAsPrimaryAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIWindow (RevenantKeyWindow15)

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

@end

@implementation UIWindowScene (RevenantFocus15)

- (UIFocusSystem *)focusSystem
{
    return nil;
}

@end
