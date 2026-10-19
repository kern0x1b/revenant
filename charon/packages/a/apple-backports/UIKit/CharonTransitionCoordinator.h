#import <UIKit/UIKit.h>

@interface CharonTransitionCoordinator : NSObject <UIViewControllerTransitionCoordinator>
- (instancetype)initWithFrom:(UIViewController *)from to:(UIViewController *)to container:(UIView *)container animated:(BOOL)animated duration:(NSTimeInterval)duration style:(UIModalPresentationStyle)style;
- (void)setContainer:(UIView *)container duration:(NSTimeInterval)duration;
- (void)charon_setInteractive:(BOOL)interactive;
- (void)charon_setCancelled:(BOOL)cancelled;
- (void)charon_setPercent:(CGFloat)percent;
- (void)charon_interactionEndedCancelled:(BOOL)cancelled;
- (void)begin;
- (void)finish;
@end

NSTimeInterval charon_default_duration(BOOL modal);
