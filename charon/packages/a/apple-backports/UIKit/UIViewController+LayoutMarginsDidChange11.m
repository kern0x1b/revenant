#import <UIKit/UIKit.h>

// The message a controller is sent when the layout margins of its view change, arrived in iOS 11.0.
// Its own file, and not UIView+LayoutMargins.m's: that object carries the 8.0 property and is kept in
// every band from 6.0, so the member it delivers belongs to the release that introduced it, which is
// what tools/release-split.lua reads and what the respondsToSelector: in that file is for -- in a lower
// band the controller answers NO and the message is not sent at all.
//
// What it does is nothing, and that is the whole of the release's behaviour for a message it has no
// work of its own to do: an application overrides it and is called. The port's own base class has
// nothing to add, so it has nothing to write, and writing a log line here would be the opposite of
// what the header says. This is the shape facts/UIKit/UIViewSafeArea.md records for the two safe area
// callbacks too, except that those are not carried at all, which is the honest answer when nothing
// sends the message and this one is sent.
@implementation UIViewController (CharonLayoutMarginsDidChange11)

- (void)viewLayoutMarginsDidChange
{
}

@end
