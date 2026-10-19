#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

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

- (void)charon_applyVerticalCompactness
{
    if (![objc_getAssociatedObject(self, &CharonHidesOnCompactKey) boolValue])
        return;
    [self setNavigationBarHidden:self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact animated:NO];
}

@end
