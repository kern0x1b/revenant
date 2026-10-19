#import <UIKit/UIKit.h>
#include <stdio.h>

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

UIPresentationController *revenant_presentation_controller_of(UIViewController *controller)
{
    return nil;
}

@interface RevenantProbeDelegate : NSObject
@end
@implementation RevenantProbeDelegate
@end

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        UIViewController *presented = [[UIViewController alloc] init];
        UIViewController *presenting = [[UIViewController alloc] init];
        RevenantProbeDelegate *delegate = [[RevenantProbeDelegate alloc] init];

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
