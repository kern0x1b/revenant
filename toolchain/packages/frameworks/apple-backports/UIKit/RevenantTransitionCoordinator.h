#import <UIKit/UIKit.h>

@interface RevenantTransitionCoordinator : NSObject <UIViewControllerTransitionCoordinator>
- (instancetype)initWithFrom:(UIViewController *)from to:(UIViewController *)to container:(UIView *)container animated:(BOOL)animated duration:(NSTimeInterval)duration style:(UIModalPresentationStyle)style;
- (void)setContainer:(UIView *)container duration:(NSTimeInterval)duration;
- (void)revenant_setInteractive:(BOOL)interactive;
- (void)revenant_setCancelled:(BOOL)cancelled;
- (void)revenant_setPercent:(CGFloat)percent;
- (void)revenant_interactionEndedCancelled:(BOOL)cancelled;
- (void)begin;
- (void)finish;
@end

NSTimeInterval revenant_default_duration(BOOL modal);
