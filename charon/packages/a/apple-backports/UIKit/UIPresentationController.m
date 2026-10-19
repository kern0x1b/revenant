#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCustomTransition.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIPresentationController {
@private
    __weak UIViewController *_presentedViewController;
    UIViewController *_presentedOwner;
    UIViewController *_presentingViewController;
    __weak id<UIAdaptivePresentationControllerDelegate> _delegate;
    UITraitCollection *_overrideTraitCollection;
    UIView *_containerView;
}

- (instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController
{
    if ((self = [super init])) {
        _presentedViewController = presentedViewController;
        _presentedOwner = presentedViewController;
        _presentingViewController = presentingViewController;
    }
    return self;
}

- (UIViewController *)presentedViewController
{
    return _presentedViewController;
}

- (UIViewController *)presentingViewController
{
    return _presentingViewController;
}

- (id<UIAdaptivePresentationControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIAdaptivePresentationControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (UITraitCollection *)overrideTraitCollection
{
    return _overrideTraitCollection;
}

- (void)setOverrideTraitCollection:(UITraitCollection *)collection
{
    _overrideTraitCollection = collection;
}

- (UIModalPresentationStyle)presentationStyle
{
    return _presentedViewController.modalPresentationStyle;
}

- (UIView *)containerView
{
    return _containerView;
}

- (void)charon_setContainerView:(UIView *)view
{
    _containerView = view;
}

/* A controller the caller made holds its presented controller; once that controller owns it, it does not, so the two
   are freed together, as UIKit 16.0's are on the host (host/sheet, sheet.lifetime). */
- (void)charon_ownedByPresentedViewController
{
    _presentedOwner = nil;
}

- (id<UIViewControllerAnimatedTransitioning>)charon_transitionAnimator
{
    return nil;
}

- (BOOL)charon_containerIgnoresDirectTouches
{
    return NO;
}

- (UIView *)presentedView
{
    return _presentedViewController.view;
}

- (BOOL)shouldPresentInFullscreen
{
    return YES;
}

- (BOOL)shouldRemovePresentersView
{
    return NO;
}

- (UIModalPresentationStyle)adaptivePresentationStyle
{
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)adaptivePresentationStyleForTraitCollection:(UITraitCollection *)traitCollection
{
    return UIModalPresentationNone;
}

- (CGRect)frameOfPresentedViewInContainerView
{
    return _containerView ? _containerView.bounds : CGRectZero;
}

- (CGSize)sizeForChildContentContainer:(id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize
{
    return parentSize;
}

- (void)presentationTransitionWillBegin
{
}

- (void)presentationTransitionDidEnd:(BOOL)completed
{
}

- (void)dismissalTransitionWillBegin
{
}

- (void)dismissalTransitionDidEnd:(BOOL)completed
{
}

- (void)containerViewWillLayoutSubviews
{
}

- (void)containerViewDidLayoutSubviews
{
}

- (UITraitCollection *)traitCollection
{
    return [_presentedViewController traitCollection];
}

- (CGSize)preferredContentSize
{
    return _presentedViewController.preferredContentSize;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(id<UIContentContainer>)container
{
}

- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(id<UIContentContainer>)container
{
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
}

@end

@interface UIViewController (CharonPresentationController)
@end

@implementation UIViewController (CharonPresentationController)

/* A page or form sheet's controller is made when it is first asked for, as UIKit makes it, so a
   delegate set before the presentation hears of its dismissal; the sheet is asked by name, as this
   file is linked into releases that do not carry it (UISheetPresentationController.m). */
- (UIPresentationController *)presentationController
{
    UIPresentationController *current = charon_presentation_controller_of(self);
    if (!current && [self respondsToSelector:@selector(sheetPresentationController)])
        current = [self performSelector:@selector(sheetPresentationController)];
    return current;
}

@end
