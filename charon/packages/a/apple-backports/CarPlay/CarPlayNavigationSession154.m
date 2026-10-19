// The 15.4 member of the navigation session: pausing with a card colour, in a 15.4 object of its own.
//
// CPMapTemplate.h... no: CPNavigationSession.h:44-49 is where it is declared, and it is
// `API_AVAILABLE(ios(15.4))` with its own rule: the turnCardColor parameter is optional, and when it is nil the
// guidanceBackgroundColor of CPMapTemplate is used; if that is unset as well, the system supplies a color. So this method is the 12.0 pause plus a
// colour, and the colour's own fallback chain is the template's -- which is why it lives in its own
// object and reaches the session's 12.0 method rather than replacing it.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

// What the 12.0 object asks of the 15.4 one, so the pause reason and its description are recorded once.
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
    // The colour is kept as it was given, nil included, because nil is what the header says falls back
    // to the template's own guidanceBackgroundColor -- and the guidance card asks for the colour it
    // wants and applies that chain itself, so a nil here is an answer and not a missing value.
    [self charon_pauseWithReason:reason description:description turnCardColor:turnCardColor];
}

@end
