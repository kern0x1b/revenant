#import <UIKit/UIKit.h>
#include <stdio.h>

// One body of checks, run on the host's own class (looked up by name, which run.sh's -D rename does not touch) and on the port's,
// which run.sh compiles under the same identifier. A line is "side<TAB>check<TAB>value". Class names are not printed: the port's
// is renamed at compile time, so the checks name the superclass and behaviour instead. Messages are sent by selector name, since
// several SDK classes declare the same property names with other types.

typedef id (*FactoryFn)(id, SEL, id);
typedef id (*FactoryRectFn)(id, SEL, id, CGRect);
typedef id (*PlainFn)(id, SEL);
typedef void (*SetRectFn)(id, SEL, CGRect);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static id get(id object, NSString *name)
{
    return [object performSelector:NSSelectorFromString(name)];
}

static CGRect rect_of(id object)
{
    return [[object valueForKey:@"sourceRect"] CGRectValue];
}

static NSString *rect_text(CGRect rect)
{
    if (CGRectIsNull(rect)) {
        return @"null";
    }
    if (CGRectEqualToRect(rect, CGRectZero)) {
        return @"zero";
    }
    return NSStringFromCGRect(rect);
}

static void run(const char *side, Class cls)
{
    report(side, "tooltip-superclass", NSStringFromClass([cls superclass]));

    SEL with_tip = NSSelectorFromString(@"configurationWithToolTip:");
    id whole = ((FactoryFn)[cls methodForSelector:with_tip])(cls, with_tip, @"Whole view");
    report(side, "whole-tooltip-kept", get(whole, @"toolTip"));
    report(side, "whole-rect-is-null", CGRectIsNull(rect_of(whole)) ? @"yes" : @"no");
    report(side, "whole-rect", rect_text(rect_of(whole)));

    SEL with_rect = NSSelectorFromString(@"configurationWithToolTip:inRect:");
    id region = ((FactoryRectFn)[cls methodForSelector:with_rect])(cls, with_rect, @"Region", CGRectMake(1, 2, 3, 4));
    report(side, "region-tooltip-kept", get(region, @"toolTip"));
    report(side, "region-rect-as-given", NSStringFromCGRect(rect_of(region)));

    id zero = ((FactoryRectFn)[cls methodForSelector:with_rect])(cls, with_rect, @"Zero", CGRectZero);
    report(side, "zero-rect-kept-as-zero", rect_text(rect_of(zero)));

    NSMutableString *mutable = [NSMutableString stringWithString:@"Before"];
    id copied = ((FactoryFn)[cls methodForSelector:with_tip])(cls, with_tip, mutable);
    [mutable appendString:@" and after"];
    report(side, "tooltip-copied-from-mutable", [get(copied, @"toolTip") isEqualToString:@"Before"] ? @"yes" : @"no");
    report(side, "tooltip-copy-is-immutable", [get(copied, @"toolTip") isKindOfClass:[NSMutableString class]] ? @"no" : @"yes");

    id none = ((FactoryFn)[cls methodForSelector:with_tip])(cls, with_tip, nil);
    report(side, "nil-tooltip-factory", none ? (get(none, @"toolTip") ? @"object-with-tip" : @"object-nil-tip") : @"nil-object");


    SEL initSel = NSSelectorFromString(@"init");
    id allocated = [cls alloc];
    id bare = ((PlainFn)[allocated methodForSelector:initSel])(allocated, initSel);
    SEL set_tip = NSSelectorFromString(@"setToolTip:");
    id settable = whole;
    if ([settable respondsToSelector:set_tip]) {
        [settable performSelector:set_tip withObject:@"Changed"];
        report(side, "tooltip-setter-stores", get(settable, @"toolTip"));
    } else {
        report(side, "tooltip-setter-stores", @"no setter");
    }
    SEL set_rect = NSSelectorFromString(@"setSourceRect:");
    if ([settable respondsToSelector:set_rect]) {
        ((SetRectFn)[settable methodForSelector:set_rect])(settable, set_rect, CGRectMake(9, 9, 9, 9));
        report(side, "rect-setter-stores", rect_text(rect_of(settable)));
    } else {
        report(side, "rect-setter-stores", @"no setter");
    }
    report(side, "runtime-init-tooltip-nil", get(bare, @"toolTip") ? @"no" : @"yes");
    report(side, "runtime-init-rect", rect_text(rect_of(bare)));
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UIToolTipConfiguration"));
        run("port", [UIToolTipConfiguration class]);
    }
    return 0;
}
