#import <UIKit/UIKit.h>
#include <stdio.h>

// The popover and sheet presentation controllers' delegate, checked on the same values in two processes: the host's classes in one, and
// the port's (renamed by run.sh) in the other. Each line is "check<TAB>value"; the two outputs must match line for line. The popover redeclares
// the delegate and its accessors are the superclass's: the check is that they answer for the subclass, and that a set reads back. The sheet
// controller is not built here (its file needs the sheet shadow and layout code); it has the same superclass accessors, read statically.

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

// The port keeps the presenting controller helper with the transition code, which this test does not build. The delegate does not reach it, so
// the stub answers nil; the presentation controller it stands for is not measured here.
UIPresentationController *charon_presentation_controller_of(UIViewController *controller)
{
    return nil;
}

@interface CharonProbeDelegate : NSObject
@end
@implementation CharonProbeDelegate
@end

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        UIViewController *presented = [[UIViewController alloc] init];
        UIViewController *presenting = [[UIViewController alloc] init];
        CharonProbeDelegate *delegate = [[CharonProbeDelegate alloc] init];

        UIPopoverPresentationController *popover = [[UIPopoverPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
        report("popover-getter-answers", yes_no([UIPopoverPresentationController instancesRespondToSelector:@selector(delegate)]));
        report("popover-setter-answers", yes_no([UIPopoverPresentationController instancesRespondToSelector:@selector(setDelegate:)]));
        report("popover-delegate-default", popover.delegate ? @"set" : @"nil");
        popover.delegate = delegate;
        report("popover-delegate-set", yes_no(popover.delegate == delegate));
        popover.delegate = nil;
        report("popover-delegate-cleared", popover.delegate ? @"set" : @"nil");

    }
    return 0;
}
