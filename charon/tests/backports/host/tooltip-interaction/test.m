#import <UIKit/UIKit.h>
#include <stdio.h>

// One body of checks, run on the host's own interaction (looked up by name, which run.sh's -D rename does not touch) and on the port's,
// which run.sh compiles under the same identifier. A line is "side<TAB>check<TAB>value". The views are attached and detached through the
// host's own UIView, so the port's interaction is moved by the same calls the release makes. No window is needed for any of this.

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *present(id object)
{
    return object ? @"set" : @"nil";
}

static void run(const char *side, Class cls)
{
    report(side, "interaction-superclass", NSStringFromClass([cls superclass]));
    report(side, "conforms-uiinteraction", yes_no([cls conformsToProtocol:@protocol(UIInteraction)]));

    id bare = [[cls alloc] init];
    report(side, "default-enabled", yes_no([bare isEnabled]));
    report(side, "default-tip-nil", present([bare defaultToolTip]));
    report(side, "default-delegate-nil", present([bare delegate]));
    report(side, "default-view-nil", present([bare view]));

    NSMutableString *tip = [NSMutableString stringWithString:@"Open"];
    id given = [[cls alloc] initWithDefaultToolTip:tip];
    report(side, "initial-tip-same-object", [given defaultToolTip] == tip ? @"yes" : @"no");
    [tip appendString:@"-changed"];
    report(side, "initial-tip-mutation-visible", [[given defaultToolTip] isEqualToString:@"Open-changed"] ? @"yes" : @"no");

    NSMutableString *later = [NSMutableString stringWithString:@"Save"];
    [bare setDefaultToolTip:later];
    report(side, "set-tip-same-object", [bare defaultToolTip] == later ? @"yes" : @"no");
    [bare setDefaultToolTip:nil];
    report(side, "set-tip-cleared", present([bare defaultToolTip]));

    [bare setEnabled:NO];
    report(side, "disabled-reads-back", yes_no([bare isEnabled]));
    [bare setEnabled:YES];
    report(side, "enabled-reads-back", yes_no([bare isEnabled]));

    id delegate = [[NSObject alloc] init];
    [bare setDelegate:(id)delegate];
    report(side, "delegate-reads-back", [bare delegate] == delegate ? @"yes" : @"no");

    UIView *first = [[UIView alloc] init];
    UIView *second = [[UIView alloc] init];

    [first addInteraction:bare];
    report(side, "attached-view-set", [bare view] == first ? @"yes" : @"no");
    report(side, "attached-count", [NSString stringWithFormat:@"%lu", (unsigned long)[[first interactions] count]]);

    [first addInteraction:bare];
    report(side, "re-add-keeps-one", [NSString stringWithFormat:@"%lu", (unsigned long)[[first interactions] count]]);

    [second addInteraction:bare];
    report(side, "moved-view", [bare view] == second ? @"yes" : @"no");
    report(side, "moved-old-count", [NSString stringWithFormat:@"%lu", (unsigned long)[[first interactions] count]]);

    [second removeInteraction:bare];
    report(side, "detached-view-nil", present([bare view]));
    report(side, "detached-count", [NSString stringWithFormat:@"%lu", (unsigned long)[[second interactions] count]]);

    report(side, "setView-absent", [cls instancesRespondToSelector:NSSelectorFromString(@"setView:")] ? @"no" : @"yes");
    report(side, "copy-absent", [cls instancesRespondToSelector:@selector(copyWithZone:)] ? @"no" : @"yes");
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UIToolTipInteraction"));
        run("port", [UIToolTipInteraction class]);
    }
    return 0;
}
