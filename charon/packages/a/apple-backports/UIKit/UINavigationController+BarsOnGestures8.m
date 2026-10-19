#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The navigation bar hiding on a swipe or a tap, which arrived with iOS 8. The release's navigation
// controller has no such gesture at all: the bar is there until a push or a pop changes it.
//
// The bar's swipe is its own gesture, not the interactive pop: measured on the host, asking a
// navigation controller for barHideOnSwipeGestureRecognizer and for interactivePopGestureRecognizer
// gives two different recognisers, the first an edge pan that hides the bar and the second the one
// that pops. So the bar gets its own edge pan, on the same edge, and the two coexist: a finger at
// the edge is offered to both and each decides for itself, which is what the host does with them.
//
// The trait path is the real one: -traitCollectionDidChange: is a method the release calls when the
// traits change, and it is wrapped in the same way UINavigationController+InteractivePop.m wraps
// -viewDidLoad, keeping the original implementation and calling it. Nothing here is driven by a
// notification standing in for a trait change.
static const char CharonHidesOnSwipeKey;
static const char CharonHidesOnTapKey;
static const char CharonHidesOnKeyboardKey;
static const char CharonHidesOnCompactKey;
static const char CharonTapHideRecognizerKey;
static const char CharonSwipeHideRecognizerKey;
static const char CharonBarHiderKey;

@interface CharonNavigationBarHider : NSObject
@property (nonatomic, weak) UINavigationController *navigation;
- (void)swipe:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)tap:(UITapGestureRecognizer *)recognizer;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;
@end

@implementation CharonNavigationBarHider
@synthesize navigation = _navigation;

// The bar goes when the swipe has actually committed to popping, not when the finger first touches
// the edge: a swipe that is cancelled puts it back, which is what a bar that hid on touch-down and
// stayed hidden would get wrong.
- (void)swipe:(UIScreenEdgePanGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    if (!navigation || ![objc_getAssociatedObject(navigation, &CharonHidesOnSwipeKey) boolValue])
        return;
    if (recognizer.state == UIGestureRecognizerStateBegan)
        [navigation setNavigationBarHidden:YES animated:YES];
    else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)
        [navigation setNavigationBarHidden:NO animated:YES];
}

- (void)tap:(UITapGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    if (!navigation || ![objc_getAssociatedObject(navigation, &CharonHidesOnTapKey) boolValue])
        return;
    if (recognizer.state == UIGestureRecognizerStateEnded)
        [navigation setNavigationBarHidden:YES animated:YES];
}

- (void)keyboardWillShow:(NSNotification *)note
{
    if ([objc_getAssociatedObject(self.navigation, &CharonHidesOnKeyboardKey) boolValue])
        [self.navigation setNavigationBarHidden:YES animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    if ([objc_getAssociatedObject(self.navigation, &CharonHidesOnKeyboardKey) boolValue])
        [self.navigation setNavigationBarHidden:NO animated:YES];
}
@end

// Declared here because the installer's +load runs before this category is attached, and it calls
// this on the controller.
@interface UINavigationController (CharonVerticalCompactness)
- (void)charon_applyVerticalCompactness;
@end

@interface CharonNavigationBarHiderInstaller : NSObject
@end

@implementation CharonNavigationBarHiderInstaller

+ (void)load
{
    if ([UINavigationController instancesRespondToSelector:@selector(barHideOnSwipeGestureRecognizer)])
        return;
    // Wrapped with the original kept and called, the way the interactive pop wraps -viewDidLoad: a
    // block needs no category to be attached, so there is nothing here that +load can run too early
    // for. A vertical size class change arrives through this method, so it is where the bar follows
    // the environment.
    Class controller = [UINavigationController class];
    Method traits = class_getInstanceMethod(controller, @selector(traitCollectionDidChange:));
    void (*originalTraits)(id, SEL) = (void (*)(id, SEL))method_getImplementation(traits);
    class_replaceMethod(controller, @selector(traitCollectionDidChange:), imp_implementationWithBlock(^(UINavigationController *self_) {
        originalTraits(self_, @selector(traitCollectionDidChange:));
        [self_ charon_applyVerticalCompactness];
    }), method_getTypeEncoding(traits));
}
@end

@implementation UINavigationController (CharonBarsOnGestures8)

- (CharonNavigationBarHider *)charon_barHider
{
    CharonNavigationBarHider *hider = objc_getAssociatedObject(self, &CharonBarHiderKey);
    if (hider)
        return hider;
    hider = [[CharonNavigationBarHider alloc] init];
    hider.navigation = self;
    objc_setAssociatedObject(self, &CharonBarHiderKey, hider, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hider;
}

// The bar's own edge pan, made once per controller and installed on its view. It is a public
// UIScreenEdgePanGestureRecognizer: the host's is a private class (_UIBarPanGestureRecognizer, which
// this port may not name), and that is the one place this family's answers differ from the host's for
// a reason that is recorded rather than papered over.
- (UIGestureRecognizer *)barHideOnSwipeGestureRecognizer
{
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &CharonSwipeHideRecognizerKey);
    if (recognizer)
        return recognizer;
    UIScreenEdgePanGestureRecognizer *swipe = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:[self charon_barHider]
                                                                                                action:@selector(swipe:)];
    swipe.edges = UIRectEdgeLeft;
    if (self.isViewLoaded)
        [self.view addGestureRecognizer:swipe];
    objc_setAssociatedObject(self, &CharonSwipeHideRecognizerKey, swipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return swipe;
}

- (UIGestureRecognizer *)barHideOnTapGestureRecognizer
{
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &CharonTapHideRecognizerKey);
    if (recognizer)
        return recognizer;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[self charon_barHider]
                                                                          action:@selector(tap:)];
    if (self.isViewLoaded)
        [self.view addGestureRecognizer:tap];
    objc_setAssociatedObject(self, &CharonTapHideRecognizerKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return tap;
}

- (BOOL)hidesBarsOnSwipe
{
    return [objc_getAssociatedObject(self, &CharonHidesOnSwipeKey) boolValue];
}

- (void)setHidesBarsOnSwipe:(BOOL)hidesBarsOnSwipe
{
    objc_setAssociatedObject(self, &CharonHidesOnSwipeKey, @(hidesBarsOnSwipe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hidesBarsOnSwipe)
        [self barHideOnSwipeGestureRecognizer];
}

- (BOOL)hidesBarsOnTap
{
    return [objc_getAssociatedObject(self, &CharonHidesOnTapKey) boolValue];
}

- (void)setHidesBarsOnTap:(BOOL)hidesBarsOnTap
{
    objc_setAssociatedObject(self, &CharonHidesOnTapKey, @(hidesBarsOnTap), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hidesBarsOnTap)
        [self barHideOnTapGestureRecognizer];
}

- (BOOL)hidesBarsWhenKeyboardAppears
{
    return [objc_getAssociatedObject(self, &CharonHidesOnKeyboardKey) boolValue];
}

- (void)setHidesBarsWhenKeyboardAppears:(BOOL)hides
{
    objc_setAssociatedObject(self, &CharonHidesOnKeyboardKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CharonNavigationBarHider *hider = [self charon_barHider];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    // Observed and unobserved the way UISheetPresentationController.m does it, so turning the flag
    // off again really stops the bar moving and the controller is not held by the observer.
    [center removeObserver:hider name:UIKeyboardWillShowNotification object:nil];
    [center removeObserver:hider name:UIKeyboardWillHideNotification object:nil];
    if (!hides)
        return;
    [center addObserver:hider selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:hider selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL)hidesBarsWhenVerticallyCompact
{
    return [objc_getAssociatedObject(self, &CharonHidesOnCompactKey) boolValue];
}

- (void)setHidesBarsWhenVerticallyCompact:(BOOL)hides
{
    objc_setAssociatedObject(self, &CharonHidesOnCompactKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hides)
        [self charon_applyVerticalCompactness];
}

// The bar follows the environment, and the environment is read from the trait collection the release
// itself maintains, so this cannot drift from what the view is actually laid out for.
- (void)charon_applyVerticalCompactness
{
    if (![objc_getAssociatedObject(self, &CharonHidesOnCompactKey) boolValue])
        return;
    [self setNavigationBarHidden:self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact animated:NO];
}

@end
