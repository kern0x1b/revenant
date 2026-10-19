#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

@interface CPNavigationSession (CharonPause)
- (void)charon_pauseWithReason:(CPTripPauseReason)reason
                   description:(NSString *)description
                   turnCardColor:(UIColor *)turnCardColor;
@end

@implementation CPNavigationSession (CharonNavigationSession154)

- (void)pauseTripForReason:(CPTripPauseReason)reason
               description:(NSString *)description
            turnCardColor:(UIColor *)turnCardColor
{
    [self charon_pauseWithReason:reason description:description turnCardColor:turnCardColor];
}

@end
