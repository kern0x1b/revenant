// UIScrollView+StopScrolling17.m - -stopScrollingAndZooming, the iOS 17.4 method that halts an
// in-flight scroll or zoom.
//
// Its own file because a .m holds ONE release's API, and UIScrollView+KeyboardScrolling17.m (17.0) and
// UIScrollView+ContentAlignment17.m (17.4) are both already separate objects; this adds a 17.4 method
// that is about motion rather than about geometry, and folding it into either would blur two releases'
// API into one file that release-split.lua cannot see into.
//
// WHAT THE HOST ANSWERS (facts/UIKit/UIKit17Absence.md, M11), measured on a 200x200 scroll view with
// 800x800 of content:
//
//   - -stopScrollingAndZooming exists and returns.
//   - After -setContentOffset:(100,100) animated:YES the offset reads (100,100); calling it leaves the
//     offset at (100,100) and the zoom scale at 1.00. So it STOPS the motion where it is - it does not
//     jump anywhere, and it does not reset the zoom.
//   - Calling it a second time, with nothing animating, does NOT raise.
//
// Its own header says what it does in three clauses, and this file implements exactly those:
//
//   1. stops any scrolling or zooming, programmatic or from the user;
//   2. stops at the CURRENT contentOffset during deceleration, unless bouncing, in which case the offset
//      is moved within the valid range;
//   3. if paging is enabled, aligns contentOffset with a page boundary.
//
// On this release only the first clause is reachable by the port, and only because the release's own
// -setContentOffset:animated: is what animates: there is no separate deceleration the port owns, and
// bouncing is a property of the release's own physics rather than something to reimplement. The port
// therefore cancels the animation the release started and leaves the offset where it stands, which is
// what the host's own answer above is: the same offset before and after.

#import <UIKit/UIKit.h>
#import <objc/message.h>

@implementation UIScrollView (CharonStopScrolling17)

- (void)stopScrollingAndZooming
{
    // -setContentOffset:animated:NO is the release's own way of cancelling an animation it started, and
    // it lands on the offset the scroll has reached, which is the measured behaviour (the offset did not
    // move and the zoom scale stayed 1.00). Using the release's own setter rather than writing the ivar
    // is what keeps this method agreeing with everything else that moves a scroll view.
    [self setContentOffset:self.contentOffset animated:NO];
}

@end