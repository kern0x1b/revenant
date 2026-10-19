// CarPlayListTemplate184.m - the 18.4 member of CPListTemplate, in an 18.4 object of its own.
//
// CPListTemplate.h:226 declares `@property (nonatomic, assign) BOOL showsSpinnerWhileEmpty
// API_AVAILABLE(ios(18.4))` and it is the only 18.4 member of the class. The class is 12.0 and its
// @implementation is CarPlayTemplatesView12.m, so this is the same split CarPlayLane174.m and
// CarPlayLane18.m make for CPLane: an object holds API of exactly one release
// (modules/apple/backports.lua's releases_in, read by tools/release-split.lua).
//
// The value is read by the class's own drawing code - CarPlayTemplatesView12.m draws the spinner where it
// draws the empty view, because an empty template is where a spinner belongs - so the storage is the
// class's and this object reaches it through the charon_ accessors of CharonCarPlayTemplate.h, the same
// shape CarPlayNavigationSession154.m uses for _turnCardColor. Nothing here decides anything: the flag
// says whether an empty template shows a spinner, and the 12.0 object is what draws it.

#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPListTemplate (CharonListTemplate184)

// :226 `assign`, and the answer is NO to start: a template nobody asked a spinner of does not show one,
// which is the state the port's 12.0 drawing was in before this property existed.
- (BOOL)showsSpinnerWhileEmpty
{
    return [self charon_showsSpinnerWhileEmpty];
}

- (void)setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty
{
    [self charon_setShowsSpinnerWhileEmpty:showsSpinnerWhileEmpty];
}

@end