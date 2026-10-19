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

static NSString *number(double value)
{
    return [NSString stringWithFormat:@"%g", value];
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

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

        UICollectionLayoutListConfiguration *config = [[UICollectionLayoutListConfiguration alloc] initWithAppearance:UICollectionLayoutListAppearancePlain];
        report("config-class", class_name(config));
        report("separator-default-class", class_name(config.separatorConfiguration));
        report("separator-default", separator_text(config.separatorConfiguration));
        report("separator-default-same-on-read", yes_no(config.separatorConfiguration == config.separatorConfiguration));
        report("handler-default", config.itemSeparatorHandler ? @"set" : @"nil");
        report("header-top-default", number(config.headerTopPadding));

        UIListSeparatorConfiguration *given = [[UIListSeparatorConfiguration alloc] initWithListAppearance:UICollectionLayoutListAppearancePlain];
        given.topSeparatorVisibility = UIListSeparatorVisibilityHidden;
        config.separatorConfiguration = given;
        report("separator-set-same-object", yes_no(config.separatorConfiguration == given));
        report("separator-set", separator_text(config.separatorConfiguration));
        given.topSeparatorVisibility = UIListSeparatorVisibilityVisible;
        report("separator-copied-after-change", separator_text(config.separatorConfiguration));

        report("separator-nil-set", outcome(^{ config.separatorConfiguration = nil; }));
        report("separator-after-nil", separator_text(config.separatorConfiguration));

        UIListSeparatorConfiguration *(^handler)(NSIndexPath *, UIListSeparatorConfiguration *) = ^UIListSeparatorConfiguration *(NSIndexPath *path, UIListSeparatorConfiguration *section) {
            return section;
        };
        config.itemSeparatorHandler = handler;
        report("handler-set", config.itemSeparatorHandler ? @"set" : @"nil");
        report("handler-same-object", yes_no(config.itemSeparatorHandler == handler));
        config.itemSeparatorHandler = nil;
        report("handler-cleared", config.itemSeparatorHandler ? @"set" : @"nil");

        config.headerTopPadding = 12.5;
        report("header-top-set", number(config.headerTopPadding));
        config.headerTopPadding = 0;
        report("header-top-zero", number(config.headerTopPadding));

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
