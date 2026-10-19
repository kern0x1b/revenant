// UIControl+PerformPrimaryAction17.m - -performPrimaryAction, the one UIControl method iOS 17.4 added.
//
// A separate file from UIControl+Actions14.m because that one is 14.0 API
// (addAction:forControlEvents:, initWithFrame:primaryAction:), and a .m holds ONE release's API:
// release-split.lua reads band points only, so one file holding both passes it and only a reader catches
// it. What this file adds is one method over machinery the 14.0 file already built.
//
// WHAT THE HOST ANSWERS, measured (facts/UIKit/UIKit17Absence.md, M10), and it is narrower than the
// method's name suggests:
//
//   UIControlEventPrimaryActionTriggered = 0x2000, UIControlEventTouchUpInside = 0x40
//
//   1. a target/action registered ONLY for the primary event   -> ran 0 times
//   2. an addAction:forControlEvents: for the primary event    -> ran 1 time
//   3. a target/action registered for touch-up-inside only     -> ran 0 times
//   4. a UIAction on touch-up-inside                           -> ran 0 times
//   5. a UIAction on the primary event, then sendActionsForControlEvents: with the same event -> ran 2
//
// So -performPrimaryAction fires the 14.0 **UIAction** list for
// UIControlEventPrimaryActionTriggered and NOTHING else: not the target/action list, and never
// touch-up-inside. Case 5 is the decisive one - the same UIAction ran once for -performPrimaryAction and
// again for -sendActionsForControlEvents:UIControlEventPrimaryActionTriggered - which makes the two calls
// the same call. That is what this file is: one line over the release's own dispatch, with the event
// value this release's own header already defines.
//
// A control with no primary action at all does NOT raise - measured, the host returns quietly - so this
// file adds no precondition of its own.

#import <UIKit/UIKit.h>
#import "CharonMenus.h"

@implementation UIControl (CharonPerformPrimaryAction17)

- (void)performPrimaryAction
{
    // Exactly -sendActionsForControlEvents:UIControlEventPrimaryActionTriggered, and measured to be
    // exactly that (M10 case 5: the same UIAction fires once per call, from either entry point).
    // UIControlEventPrimaryActionTriggered is not spelled as a literal here on purpose - the release's
    // own header defines it, and its value (0x2000) is Apple's, not this file's.
    [self sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
}

@end