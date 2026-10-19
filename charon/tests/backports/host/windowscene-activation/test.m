#import <UIKit/UIKit.h>
#include <stdio.h>

// One body of checks, run on the host's own classes (looked up by name, which run.sh's -D renames do not touch) and on the port's,
// which run.sh compiles under the same identifiers. A line is "side<TAB>check<TAB>value". Class names are not printed: the port's
// are renamed at compile time, so the checks name superclasses and behaviour instead. Messages are sent by selector name, since
// several SDK classes declare the same property names with other types.

typedef id (*InitWithFn)(id, SEL, id);
typedef id (*PlainFn)(id, SEL);
typedef id (*FactoryFn)(id, SEL, id, id, id);
typedef NSInteger (*IntFn)(id, SEL);
typedef void (*SetIntFn)(id, SEL, NSInteger);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, [value UTF8String]);
}

static NSString *text(NSInteger n)
{
    return [NSString stringWithFormat:@"%ld", (long)n];
}

static id get(id object, NSString *name)
{
    return [object performSelector:NSSelectorFromString(name)];
}

static void set(id object, NSString *name, id value)
{
    [object performSelector:NSSelectorFromString(name) withObject:value];
}

static void run_configuration(const char *side, Class cls)
{
    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"com.example.charon.scene"];
    SEL initWith = NSSelectorFromString(@"initWithUserActivity:");
    InitWithFn make = (InitWithFn)[cls instanceMethodForSelector:initWith];
    id kept = make([cls alloc], initWith, activity);
    report(side, "configuration-activity-kept-object", get(kept, @"userActivity") == activity ? @"yes" : @"no");
    report(side, "configuration-options-default", get(kept, @"options") ? @"set" : @"nil");
    report(side, "configuration-preview-default", get(kept, @"preview") ? @"set" : @"nil");
    report(side, "configuration-superclass", NSStringFromClass([cls superclass]));

    id none = make([cls alloc], initWith, nil);
    report(side, "configuration-nil-activity-kept-nil", get(none, @"userActivity") ? @"no" : @"yes");

    id options = [[NSClassFromString(@"UIWindowSceneActivationRequestOptions") alloc] init];
    set(kept, @"setOptions:", options);
    report(side, "configuration-options-kept-after-set", get(kept, @"options") == options ? @"yes" : @"no");
    set(kept, @"setPreview:", nil);
    report(side, "configuration-preview-set-nil", get(kept, @"preview") ? @"no" : @"yes");
    report(side, "configuration-activity-has-no-setter", [cls instancesRespondToSelector:NSSelectorFromString(@"setUserActivity:")] ? @"no" : @"yes");

    SEL initSel = NSSelectorFromString(@"init");
    id allocated = [cls alloc];
    id bare = ((PlainFn)[allocated methodForSelector:initSel])(allocated, initSel);
    report(side, "configuration-runtime-init-activity-nil", get(bare, @"userActivity") ? @"no" : @"yes");
    report(side, "configuration-runtime-init-options-nil", get(bare, @"options") ? @"no" : @"yes");
}

static void run_request_options(const char *side, Class cls)
{
    id options = [[cls alloc] init];
    report(side, "request-options-superclass", NSStringFromClass([cls superclass]));
    SEL get_style = NSSelectorFromString(@"preferredPresentationStyle");
    SEL set_style = NSSelectorFromString(@"setPreferredPresentationStyle:");
    report(side, "request-options-style-default", text(((IntFn)[options methodForSelector:get_style])(options, get_style)));
    ((SetIntFn)[options methodForSelector:set_style])(options, set_style, 1);
    report(side, "request-options-style-after-set", text(((IntFn)[options methodForSelector:get_style])(options, get_style)));
}

static void run_action(const char *side, Class cls)
{
    SEL factory = NSSelectorFromString(@"actionWithIdentifier:alternateAction:configurationProvider:");
    FactoryFn make = (FactoryFn)[cls methodForSelector:factory];
    id action = make(cls, factory, @"com.example.charon.open", nil, ^id(id sender) { return nil; });
    report(side, "action-superclass", NSStringFromClass([cls superclass]));
    report(side, "action-identifier-kept", get(action, @"identifier"));
    report(side, "action-title-default", get(action, @"title"));
    set(action, @"setTitle:", @"Open");
    report(side, "action-title-after-set", get(action, @"title"));
    report(side, "action-inherits-actionWithHandler", [cls respondsToSelector:NSSelectorFromString(@"actionWithHandler:")] ? @"yes" : @"no");
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run_configuration("host", NSClassFromString(@"UIWindowSceneActivationConfiguration"));
        run_configuration("port", [UIWindowSceneActivationConfiguration class]);
        run_request_options("host", NSClassFromString(@"UIWindowSceneActivationRequestOptions"));
        run_request_options("port", [UIWindowSceneActivationRequestOptions class]);
        run_action("host", NSClassFromString(@"UIWindowSceneActivationAction"));
        run_action("port", [UIWindowSceneActivationAction class]);
    }
    return 0;
}
