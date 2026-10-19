#import <UIKit/UIKit.h>
#include <stdio.h>

// UICollectionLayoutListConfiguration's separatorConfiguration, itemSeparatorHandler and headerTopPadding, checked on the same values in
// two processes: the host's classes in one, and the port's (renamed by run.sh, so this file's names mean the port's classes in that build)
// in the other. Each line is "check<TAB>value"; the two outputs must match line for line.

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *number(double value)
{
    return [NSString stringWithFormat:@"%g", value];
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

// A setter may raise. The outcome is "ok", or the exception's name and reason.
static NSString *outcome(void (^change)(void))
{
    @try {
        change();
        return @"ok";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

static NSString *separator_text(UIListSeparatorConfiguration *c)
{
    if (!c)
        return @"nil";
    return [NSString stringWithFormat:@"top=%ld bottom=%ld topInsets=%@ bottomInsets=%@", (long)c.topSeparatorVisibility, (long)c.bottomSeparatorVisibility,
            NSStringFromDirectionalEdgeInsets(c.topSeparatorInsets), NSStringFromDirectionalEdgeInsets(c.bottomSeparatorInsets)];
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        // The defaults: a separator configuration that is automatic on both edges, a nil handler and a header padding of the sentinel.
        UICollectionLayoutListConfiguration *config = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
        report("config-class", class_name(config));
        report("separator-default-class", class_name(config.separatorConfiguration));
        report("separator-default", separator_text(config.separatorConfiguration));
        report("separator-default-same-on-read", yes_no(config.separatorConfiguration == config.separatorConfiguration));
        report("handler-default", config.itemSeparatorHandler ? @"set" : @"nil");
        report("header-top-default", number(config.headerTopPadding));

        // A separator configuration is kept as a copy: a change to the one given afterwards does not reach the configuration.
        UIListSeparatorConfiguration *given = [[UIListSeparatorConfiguration alloc] initWithListAppearance:UICollectionLayoutListAppearancePlain];
        given.topSeparatorVisibility = UIListSeparatorVisibilityHidden;
        config.separatorConfiguration = given;
        report("separator-set-same-object", yes_no(config.separatorConfiguration == given));
        report("separator-set", separator_text(config.separatorConfiguration));
        given.topSeparatorVisibility = UIListSeparatorVisibilityVisible;
        report("separator-copied-after-change", separator_text(config.separatorConfiguration));

        // The host refuses nil, with NSInvalidArgumentException; the port refuses it the same way, and keeps what it held.
        report("separator-nil-set", outcome(^{ config.separatorConfiguration = nil; }));
        report("separator-after-nil", separator_text(config.separatorConfiguration));

        // The item separator handler is kept as a block; a block is copied on set, so the read-back is a different object.
        UIListSeparatorConfiguration *(^handler)(NSIndexPath *, UIListSeparatorConfiguration *) = ^UIListSeparatorConfiguration *(NSIndexPath *path, UIListSeparatorConfiguration *section) {
            return section;
        };
        config.itemSeparatorHandler = handler;
        report("handler-set", config.itemSeparatorHandler ? @"set" : @"nil");
        report("handler-same-object", yes_no(config.itemSeparatorHandler == handler));
        config.itemSeparatorHandler = nil;
        report("handler-cleared", config.itemSeparatorHandler ? @"set" : @"nil");

        // The header padding is kept as the value set, including zero.
        config.headerTopPadding = 12.5;
        report("header-top-set", number(config.headerTopPadding));
        config.headerTopPadding = 0;
        report("header-top-zero", number(config.headerTopPadding));

        // A copy keeps all three.
        config.separatorConfiguration = given;
        config.itemSeparatorHandler = handler;
        config.headerTopPadding = 7;
        UICollectionLayoutListConfiguration *copied = [config copy];
        report("copy-separator", separator_text(copied.separatorConfiguration));
        report("copy-handler", copied.itemSeparatorHandler ? @"set" : @"nil");
        report("copy-header-top", number(copied.headerTopPadding));
        report("copy-separator-same-object", yes_no(copied.separatorConfiguration == config.separatorConfiguration));
    }
    return 0;
}
