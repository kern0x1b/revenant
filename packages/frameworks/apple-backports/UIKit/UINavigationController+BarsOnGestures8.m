#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantHidesOnSwipeKey;
static const char RevenantHidesOnTapKey;
static const char RevenantHidesOnKeyboardKey;
static const char RevenantHidesOnCompactKey;
static const char RevenantTapHideRecognizerKey;
static const char RevenantSwipeHideRecognizerKey;
static const char RevenantBarHiderKey;

@interface RevenantNavigationBarHider : NSObject
@property (nonatomic, weak) UINavigationController *navigation;
- (void)swipe:(UIScreenEdgePanGestureRecognizer *)recognizer;
- (void)tap:(UITapGestureRecognizer *)recognizer;
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;
@end

@implementation RevenantNavigationBarHider
@synthesize navigation = _navigation;

- (void)swipe:(UIScreenEdgePanGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    if (!navigation || ![objc_getAssociatedObject(navigation, &RevenantHidesOnSwipeKey) boolValue])
        return;
    if (recognizer.state == UIGestureRecognizerStateBegan)
        [navigation setNavigationBarHidden:YES animated:YES];
    else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)
        [navigation setNavigationBarHidden:NO animated:YES];
}

- (void)tap:(UITapGestureRecognizer *)recognizer
{
    UINavigationController *navigation = self.navigation;
    if (!navigation || ![objc_getAssociatedObject(navigation, &RevenantHidesOnTapKey) boolValue])
        return;
    if (recognizer.state == UIGestureRecognizerStateEnded)
        [navigation setNavigationBarHidden:YES animated:YES];
}

- (void)keyboardWillShow:(NSNotification *)note
{
    if ([objc_getAssociatedObject(self.navigation, &RevenantHidesOnKeyboardKey) boolValue])
        [self.navigation setNavigationBarHidden:YES animated:YES];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    if ([objc_getAssociatedObject(self.navigation, &RevenantHidesOnKeyboardKey) boolValue])
        [self.navigation setNavigationBarHidden:NO animated:YES];
}
@end

@interface UINavigationController (RevenantVerticalCompactness)
- (void)revenant_applyVerticalCompactness;
@end

@interface RevenantNavigationBarHiderInstaller : NSObject
@end

@implementation RevenantNavigationBarHiderInstaller

+ (void)load
{
    if ([UINavigationController instancesRespondToSelector:@selector(barHideOnSwipeGestureRecognizer)])
        return;
    Class controller = [UINavigationController class];
    Method traits = class_getInstanceMethod(controller, @selector(traitCollectionDidChange:));
    void (*originalTraits)(id, SEL) = (void (*)(id, SEL))method_getImplementation(traits);
    class_replaceMethod(controller, @selector(traitCollectionDidChange:), imp_implementationWithBlock(^(UINavigationController *self_) {
        originalTraits(self_, @selector(traitCollectionDidChange:));
        [self_ revenant_applyVerticalCompactness];
    }), method_getTypeEncoding(traits));
}
@end

@implementation UINavigationController (RevenantBarsOnGestures8)

- (RevenantNavigationBarHider *)revenant_barHider
{
    RevenantNavigationBarHider *hider = objc_getAssociatedObject(self, &RevenantBarHiderKey);
    if (hider)
        return hider;
    hider = [[RevenantNavigationBarHider alloc] init];
    hider.navigation = self;
    objc_setAssociatedObject(self, &RevenantBarHiderKey, hider, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return hider;
}

- (UIGestureRecognizer *)barHideOnSwipeGestureRecognizer
{
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &RevenantSwipeHideRecognizerKey);
    if (recognizer)
        return recognizer;
    UIScreenEdgePanGestureRecognizer *swipe = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:[self revenant_barHider]
                                                                                                action:@selector(swipe:)];
    swipe.edges = UIRectEdgeLeft;
    if (self.isViewLoaded)
        [self.view addGestureRecognizer:swipe];
    objc_setAssociatedObject(self, &RevenantSwipeHideRecognizerKey, swipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return swipe;
}

- (UIGestureRecognizer *)barHideOnTapGestureRecognizer
{
    UIGestureRecognizer *recognizer = objc_getAssociatedObject(self, &RevenantTapHideRecognizerKey);
    if (recognizer)
        return recognizer;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[self revenant_barHider]
                                                                          action:@selector(tap:)];
    if (self.isViewLoaded)
        [self.view addGestureRecognizer:tap];
    objc_setAssociatedObject(self, &RevenantTapHideRecognizerKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return tap;
}

- (BOOL)hidesBarsOnSwipe
{
    return [objc_getAssociatedObject(self, &RevenantHidesOnSwipeKey) boolValue];
}

- (void)setHidesBarsOnSwipe:(BOOL)hidesBarsOnSwipe
{
    objc_setAssociatedObject(self, &RevenantHidesOnSwipeKey, @(hidesBarsOnSwipe), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hidesBarsOnSwipe)
        [self barHideOnSwipeGestureRecognizer];
}

- (BOOL)hidesBarsOnTap
{
    return [objc_getAssociatedObject(self, &RevenantHidesOnTapKey) boolValue];
}

- (void)setHidesBarsOnTap:(BOOL)hidesBarsOnTap
{
    objc_setAssociatedObject(self, &RevenantHidesOnTapKey, @(hidesBarsOnTap), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hidesBarsOnTap)
        [self barHideOnTapGestureRecognizer];
}

- (BOOL)hidesBarsWhenKeyboardAppears
{
    return [objc_getAssociatedObject(self, &RevenantHidesOnKeyboardKey) boolValue];
}

- (void)setHidesBarsWhenKeyboardAppears:(BOOL)hides
{
    objc_setAssociatedObject(self, &RevenantHidesOnKeyboardKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    RevenantNavigationBarHider *hider = [self revenant_barHider];
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
    return [objc_getAssociatedObject(self, &RevenantHidesOnCompactKey) boolValue];
}

- (void)setHidesBarsWhenVerticallyCompact:(BOOL)hides
{
    objc_setAssociatedObject(self, &RevenantHidesOnCompactKey, @(hides), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (hides)
        [self revenant_applyVerticalCompactness];
}

- (void)revenant_applyVerticalCompactness
{
    if (![objc_getAssociatedObject(self, &RevenantHidesOnCompactKey) boolValue])
        return;
    [self setNavigationBarHidden:self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact animated:NO];
}

@end
