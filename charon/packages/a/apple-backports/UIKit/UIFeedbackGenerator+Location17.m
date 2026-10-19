// UIFeedbackGenerator+Location17.m - the four view-bound and location-bound entry points iOS 17.5
// added: two factories that bind a generator to a view, and four methods that take a location.
//
// What the host answers was measured first (facts/UIKit/UIKit17Absence.md, M8):
//
//   * +feedbackGeneratorForView: returns a non-nil UIFeedbackGenerator, and it really is one
//     (isKindOfClass: answers YES). A nil view does NOT raise - it returns a usable generator - so this
//     file adds no precondition of its own.
//   * +feedbackGeneratorWithStyle:forView: returns a non-nil UIImpactFeedbackGenerator. So the factory
//     builds the class it is called on, which is what [self alloc] below does.
//   * -impactOccurredAtLocation: and -impactOccurredWithIntensity:atLocation: both return.
//
// WHAT THIS FILE DOES NOT DO, and it is the point of it: it does not pretend the location matters.
// Haptics on this release are the Taptic Engine's one motor, driven by the port's own
// charon_feedback_play(intensity, milliseconds, count) through AudioServicesPlaySystemSoundWithVibration
// (CharonFeedbackGenerator.h). That call takes an intensity and a duration and NOTHING ELSE - there is
// no position parameter to pass a point to, and no public mechanism on iOS 6.1.3 to say "vibrate
// harder on the left of the screen". A method that accepted the point and dropped it would be the port
// answering something the system cannot, and a method that raised would break a caller the host's own
// method serves fine.
//
// So the location is accepted, ignored, and SAID TO BE IGNORED here. The intensity argument IS honoured,
// because that one maps onto a real parameter: -impactOccurredWithIntensity:atLocation: scales the
// style's intensity by the value given, exactly as the port's existing -charon_impactScaledBy: does for
// -impactOccurred. What a caller gets is the haptic its style or intensity asks for, at the same
// strength wherever on the screen it happened.
//
// The bound view is stored, so a caller that binds a generator to a view and asks for it back gets the
// same one. Nothing in this release routes feedback by view, so the view is recorded rather than obeyed -
// and that is the honest limit of 17.5's location API on hardware whose motor takes no position.

#import <UIKit/UIKit.h>
#import "CharonFeedbackGenerator.h"
#import <objc/runtime.h>

static const char CharonBoundViewKey;

// The scaling seam UIImpactFeedbackGenerator+Intensity13.m already uses for the 13.0
// -impactOccurredWithIntensity:. Declared here rather than imported, because that file keeps the
// declaration to itself; this file needs it to honour the intensity argument of the 17.5 method.
@interface UIImpactFeedbackGenerator (CharonLocation17Scaling)
- (void)charon_impactScaledBy:(float)scale;
@end

@implementation UIFeedbackGenerator (CharonLocation17)

- (instancetype)initWithBoundView:(UIView *)view
{
    self = [self init];
    if (self)
        objc_setAssociatedObject(self, &CharonBoundViewKey, view, OBJC_ASSOCIATION_ASSIGN);
    return self;
}

// The view a generator was bound to, or nil. Not one of the 17.5 rows: it is the storage the two
// factories need in order to hand back what they were given, and it is named charon_ so it can never be
// mistaken for a release API.
- (UIView *)charon_boundView
{
    return objc_getAssociatedObject(self, &CharonBoundViewKey);
}

+ (instancetype)feedbackGeneratorForView:(UIView *)view
{
    // [self alloc] and not [[UIFeedbackGenerator alloc] init]: measured, the impact factory returns a
    // UIImpactFeedbackGenerator, so the class a factory builds is the one it was called on.
    return [[self alloc] initWithBoundView:view];
}

@end

@implementation UIImpactFeedbackGenerator (CharonLocation17)

+ (instancetype)feedbackGeneratorWithStyle:(UIImpactFeedbackStyle)style forView:(UIView *)view
{
    return [[self alloc] initWithStyle:style];
}

- (void)impactOccurredAtLocation:(CGPoint)location
{
    // The location is accepted and not used; see the file header for the measurement behind that. The
    // haptic is the style's own, which is what -impactOccurred produces.
    (void)location;
    [self impactOccurred];
}

- (void)impactOccurredWithIntensity:(CGFloat)intensity atLocation:(CGPoint)location
{
    (void)location;
    // The intensity IS honoured, because the port's own player takes one: the style's intensity scaled
    // by this value, clamped to at most the style's own strength. This is the same computation the 13.0
    // -impactOccurredWithIntensity: performs, so it calls that rather than repeating the arithmetic.
    [self impactOccurredWithIntensity:intensity];
}

@end

@implementation UISelectionFeedbackGenerator (CharonLocation17)

- (void)selectionChangedAtLocation:(CGPoint)location
{
    (void)location;
    [self selectionChanged];
}

@end

@implementation UINotificationFeedbackGenerator (CharonLocation17)

- (void)notificationOccurred:(UINotificationFeedbackType)type atLocation:(CGPoint)location
{
    (void)location;
    [self notificationOccurred:type];
}

@end