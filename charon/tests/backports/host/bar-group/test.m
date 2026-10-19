#import <UIKit/UIKit.h>
#include <stdio.h>

// UIBarButtonItemGroup's storage for alwaysAvailable, menuRepresentation and hidden, checked on the same values in two processes: the
// host's classes in one, and the port's (renamed by run.sh, so this file's names mean the port's classes in that build) in the other. Each
// line is "check<TAB>value"; the two outputs must match line for line.

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

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        UIBarButtonItem *first = [[UIBarButtonItem alloc] initWithTitle:@"first" style:UIBarButtonItemStylePlain target:nil action:NULL];
        UIBarButtonItemGroup *group = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[first] representativeItem:nil];
        report("group-class", class_name(group));
        report("group-always-default", yes_no(group.alwaysAvailable));
        report("group-menu-default", group.menuRepresentation ? @"set" : @"nil");
        report("group-hidden-default", yes_no(group.isHidden));

        group.alwaysAvailable = YES;
        report("group-always-set", yes_no(group.alwaysAvailable));
        group.alwaysAvailable = NO;
        report("group-always-cleared", yes_no(group.alwaysAvailable));

        group.hidden = YES;
        report("group-hidden-set", yes_no(group.isHidden));
        group.hidden = NO;
        report("group-hidden-cleared", yes_no(group.isHidden));

        // The menu representation is copied on set, as the header says: a change to the menu afterwards does not reach the group.
        UIMenu *menu = [UIMenu menuWithTitle:@"menu" children:@[]];
        group.menuRepresentation = menu;
        report("group-menu-same-object", yes_no(group.menuRepresentation == menu));
        report("group-menu-copied-title", group.menuRepresentation.title);
        group.menuRepresentation = nil;
        report("group-menu-cleared", group.menuRepresentation ? @"set" : @"nil");

        // The three values are independent of the items and of each other.
        group.menuRepresentation = menu;
        group.alwaysAvailable = YES;
        group.hidden = YES;
        report("group-items-kept", [NSString stringWithFormat:@"%lu", (unsigned long)group.barButtonItems.count]);
        report("group-combined", [NSString stringWithFormat:@"%@/%@/%@", yes_no(group.alwaysAvailable), group.menuRepresentation.title, yes_no(group.isHidden)]);
    }
    return 0;
}
