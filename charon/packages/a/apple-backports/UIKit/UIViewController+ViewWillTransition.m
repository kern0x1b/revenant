#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonTransitionCoordinator.h"

@interface CharonRotationCoordinator : CharonTransitionCoordinator
@property (nonatomic, assign) CGAffineTransform charon_transform;
@end

@implementation CharonRotationCoordinator

@synthesize charon_transform;

- (CGAffineTransform)targetTransform
{
    return self.charon_transform;
}

@end

static CGFloat charon_angle(UIInterfaceOrientation orientation)
{
    switch (orientation) {
    case UIInterfaceOrientationPortraitUpsideDown:
        return M_PI;
    case UIInterfaceOrientationLandscapeLeft:
        return M_PI_2;
    case UIInterfaceOrientationLandscapeRight:
        return -M_PI_2;
    default:
        return 0;
    }
}

static CGSize charon_forward_size(UIViewController *container, UIViewController *child, CGSize size)
{
    return [container sizeForChildContentContainer:child withParentContainerSize:size];
}

@implementation UIViewController (CharonViewWillTransition)

- (CGSize)sizeForChildContentContainer:(id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize
{
    return parentSize;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    for (UIViewController *child in self.childViewControllers) {
        CGSize childSize = charon_forward_size(self, child, size);
        CGSize current = child.isViewLoaded ? child.view.bounds.size : CGSizeZero;
        if (!CGSizeEqualToSize(childSize, current))
            [child viewWillTransitionToSize:childSize withTransitionCoordinator:coordinator];
    }
    UIViewController *presented = self.presentedViewController;
    if (presented && presented.presentingViewController == self && presented.modalPresentationStyle == UIModalPresentationFullScreen) {
        CGSize current = presented.isViewLoaded ? presented.view.bounds.size : CGSizeZero;
        if (!CGSizeEqualToSize(size, current))
            [presented viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    }
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    for (UIViewController *child in self.childViewControllers)
        [child willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
}

@end

@interface CharonRotationDriver : NSObject
@end

@implementation CharonRotationDriver

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        UIInterfaceOrientation next = (UIInterfaceOrientation)[note.userInfo[UIApplicationStatusBarOrientationUserInfoKey] integerValue];
        UIInterfaceOrientation current = [UIApplication sharedApplication].statusBarOrientation;
        if (next == current)
            return;
        NSTimeInterval duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            UIViewController *root = window.rootViewController;
            if (!root)
                continue;
            CGSize size = window.bounds.size;
            if ((size.width > size.height) != UIInterfaceOrientationIsLandscape(next))
                size = CGSizeMake(size.height, size.width);
            CharonRotationCoordinator *coordinator = [[CharonRotationCoordinator alloc] initWithFrom:nil to:nil container:window animated:duration > 0 duration:duration style:UIModalPresentationNone];
            coordinator.charon_transform = CGAffineTransformMakeRotation(charon_angle(next) - charon_angle(current));
            [root viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + 0.05) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [coordinator finish];
            });
        }
    }];
}

@end
