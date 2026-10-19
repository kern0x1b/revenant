#import <UIKit/UIKit.h>
#include <stdio.h>

// One body of checks, run on the host's own class (looked up by name, which run.sh's -D rename does not touch) and on the port's,
// which run.sh compiles under the same identifier. A line is "side<TAB>check<TAB>value". Class names are not printed: the port's
// is renamed at compile time, so the checks name the superclass and behaviour instead. Messages are sent through typed function
// pointers, so a scalar or a struct return is read as its own type.

typedef NSUInteger (*UIntGetFn)(id, SEL);
typedef void (*UIntSetFn)(id, SEL, NSUInteger);
typedef NSInteger (*IntGetFn)(id, SEL);
typedef void (*IntSetFn)(id, SEL, NSInteger);
typedef CGFloat (*FloatGetFn)(id, SEL);
typedef void (*FloatSetFn)(id, SEL, CGFloat);
typedef id (*PlainFn)(id, SEL);
typedef BOOL (*BoolFn)(id, SEL);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *text(NSInteger n)
{
    return [NSString stringWithFormat:@"%ld", (long)n];
}

static NSString *text_float(CGFloat x)
{
    return [NSString stringWithFormat:@"%g", (double)x];
}

static id get(id object, NSString *name)
{
    return [object performSelector:NSSelectorFromString(name)];
}

static NSUInteger get_uint(id object, NSString *name)
{
    SEL sel = NSSelectorFromString(name);
    return ((UIntGetFn)[object methodForSelector:sel])(object, sel);
}

static NSInteger get_int(id object, NSString *name)
{
    SEL sel = NSSelectorFromString(name);
    return ((IntGetFn)[object methodForSelector:sel])(object, sel);
}

static CGFloat get_float(id object, NSString *name)
{
    SEL sel = NSSelectorFromString(name);
    return ((FloatGetFn)[object methodForSelector:sel])(object, sel);
}

static void set_uint(id object, NSString *name, NSUInteger value)
{
    SEL sel = NSSelectorFromString(name);
    ((UIntSetFn)[object methodForSelector:sel])(object, sel, value);
}

static void set_int(id object, NSString *name, NSInteger value)
{
    SEL sel = NSSelectorFromString(name);
    ((IntSetFn)[object methodForSelector:sel])(object, sel, value);
}

static void set_float(id object, NSString *name, CGFloat value)
{
    SEL sel = NSSelectorFromString(name);
    ((FloatSetFn)[object methodForSelector:sel])(object, sel, value);
}

static void set(id object, NSString *name, id value)
{
    [object performSelector:NSSelectorFromString(name) withObject:value];
}

static void report_defaults(const char *side, id config)
{
    report(side, "default-display-mode", text(get_uint(config, @"displayMode")));
    report(side, "default-corner-style", text(get_int(config, @"cornerStyle")));
    report(side, "default-corner-radius", text_float(get_float(config, @"cornerRadius")));
    report(side, "default-image-placement", text(get_uint(config, @"imagePlacement")));
    report(side, "default-foreground-nil", get(config, @"baseForegroundColor") ? @"no" : @"yes");
    report(side, "default-background-nil", get(config, @"baseBackgroundColor") ? @"no" : @"yes");
}

static void run(const char *side, Class cls)
{
    report(side, "paste-config-superclass", NSStringFromClass([cls superclass]));
    report(side, "paste-config-secure-coding", [cls supportsSecureCoding] ? @"yes" : @"no");

    SEL initSel = NSSelectorFromString(@"init");
    id allocated = [cls alloc];
    id bare = ((PlainFn)[allocated methodForSelector:initSel])(allocated, initSel);
    report_defaults(side, bare);

    id config = [[cls alloc] init];
    set_uint(config, @"setDisplayMode:", 2);
    report(side, "display-mode-kept", text(get_uint(config, @"displayMode")));
    set_int(config, @"setCornerStyle:", 3);
    report(side, "corner-style-kept", text(get_int(config, @"cornerStyle")));
    set_float(config, @"setCornerRadius:", 7.5);
    report(side, "corner-radius-kept", text_float(get_float(config, @"cornerRadius")));
    set_uint(config, @"setImagePlacement:", 2);
    report(side, "image-placement-kept", text(get_uint(config, @"imagePlacement")));
    set(config, @"setBaseForegroundColor:", [UIColor redColor]);
    report(side, "foreground-kept", [get(config, @"baseForegroundColor") isEqual:[UIColor redColor]] ? @"yes" : @"no");
    set(config, @"setBaseBackgroundColor:", [UIColor blueColor]);
    report(side, "background-kept", [get(config, @"baseBackgroundColor") isEqual:[UIColor blueColor]] ? @"yes" : @"no");
    set(config, @"setBaseBackgroundColor:", nil);
    report(side, "background-set-nil", get(config, @"baseBackgroundColor") ? @"no" : @"yes");

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:config];
    id decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    report(side, "round-trip-is-same-class", [decoded isKindOfClass:[cls class]] ? @"yes" : @"no");
    report(side, "round-trip-display-mode", text(get_uint(decoded, @"displayMode")));
    report(side, "round-trip-corner-style", text(get_int(decoded, @"cornerStyle")));
    report(side, "round-trip-corner-radius", text_float(get_float(decoded, @"cornerRadius")));
    report(side, "round-trip-image-placement", text(get_uint(decoded, @"imagePlacement")));
    report(side, "round-trip-foreground", [get(decoded, @"baseForegroundColor") isEqual:[UIColor redColor]] ? @"yes" : @"no");
    report(side, "round-trip-background-nil", get(decoded, @"baseBackgroundColor") ? @"no" : @"yes");
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UIPasteControlConfiguration"));
        run("port", [UIPasteControlConfiguration class]);
    }
    return 0;
}
