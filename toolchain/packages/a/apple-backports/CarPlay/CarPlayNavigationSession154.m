#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

@interface CPNavigationSession (RevenantPause)
- (void)revenant_pauseWithReason:(CPTripPauseReason)reason
                   description:(NSString *)description
                   turnCardColor:(UIColor *)turnCardColor;
@end

@implementation CPNavigationSession (RevenantNavigationSession154)

- (void)pauseTripForReason:(CPTripPauseReason)reason
               description:(NSString *)description
            turnCardColor:(UIColor *)turnCardColor
{
    [self revenant_pauseWithReason:reason description:description turnCardColor:turnCardColor];
}

@end
