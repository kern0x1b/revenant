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
