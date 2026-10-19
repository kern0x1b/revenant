// The stand-in for the header the SDK declares the transitioning protocol in. The port's class
// conforms to it, so this file has to exist and has to declare the protocol with the two required
// methods -- the SDK's real header is <UIKit/UIViewControllerTransitioning.h>, and a stub named
// after the protocol rather than after the header it lives in is a file no build will ever find.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView : NSObject
@property (nonatomic) CGFloat alpha;
@end

@protocol UIViewControllerContextTransitioning <NSObject>
- (void)completeTransition:(BOOL)completed;
@end

@protocol UIViewControllerAnimatedTransitioning <NSObject>
- (NSTimeInterval)transitionDuration:(nullable id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
@end

void CharonAnimate(NSTimeInterval duration, void (^animations)(void), void (^completion)(BOOL));
NSTimeInterval CharonLastAnimationDuration(void);

NS_ASSUME_NONNULL_END
