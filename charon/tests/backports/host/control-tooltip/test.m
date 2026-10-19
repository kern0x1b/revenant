#import <UIKit/UIKit.h>
#include <stdio.h>

// A control's tool tip, run on the same checks in two processes: the host's own UIControl, and the port's category on it. Each line is
// "check<TAB>value"; run.sh runs this once without the port's source and once with it, and the two outputs must be the same.
// The port's interaction class is renamed in its build, so its name is stripped of the rename before it is printed.

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *count_text(NSArray *items)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)items.count];
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        UIControl *control = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
        report("fresh-tool-tip", control.toolTip);
        report("fresh-interaction", control.toolTipInteraction ? @"set" : @"nil");
        report("fresh-interactions", count_text(control.interactions));

        control.toolTip = @"hello";
        id first = control.toolTipInteraction;
        report("set-tool-tip", control.toolTip);
        report("interaction-class", first ? class_name(first) : @"nil");
        report("interaction-count", count_text(control.interactions));
        report("interaction-held", yes_no([control.interactions containsObject:first]));
        report("interaction-view-is-control", yes_no([first view] == control));
        report("interaction-default-tip", [first defaultToolTip]);
        report("interaction-enabled", yes_no([first isEnabled]));
        report("interaction-same-on-read", yes_no(control.toolTipInteraction == first));

        control.toolTip = @"second";
        report("second-same-interaction", yes_no(control.toolTipInteraction == first));
        report("second-default-tip", [first defaultToolTip]);
        report("second-count", count_text(control.interactions));

        NSMutableString *given = [NSMutableString stringWithString:@"ref"];
        control.toolTip = given;
        report("given-kept-by-reference", yes_no(control.toolTip == given));
        report("given-default-by-reference", yes_no([first defaultToolTip] == given));

        control.toolTip = nil;
        report("nil-tool-tip", control.toolTip);
        report("nil-interaction", control.toolTipInteraction ? @"set" : @"nil");
        report("nil-count", count_text(control.interactions));
        report("old-interaction-view", [first view] == control ? @"control" : @"nil");
        report("old-interaction-default-kept", [first defaultToolTip]);

        control.toolTip = @"again";
        report("again-new-interaction", yes_no(control.toolTipInteraction != first));
        report("again-count", count_text(control.interactions));

        UIControl *empty = [[UIControl alloc] initWithFrame:CGRectZero];
        empty.toolTip = @"";
        report("empty-tool-tip", empty.toolTip);
        report("empty-interaction-count", count_text(empty.interactions));
        report("empty-interaction-default", [empty.toolTipInteraction defaultToolTip]);
    }
    return 0;
}
