// hover16_scenario.h - what the host's own UIKit answers for the names of iOS 16.1 and 16.4 this band
// carries: the four members UIHoverGestureRecognizer gained, the `enabled` of UISearchBar, and the
// class UITextInputContext with the three flags it declares.
//
// One scenario, two sides. hover16_system.m runs it in a process with none of the port's code and
// records it; hover16_test.m runs it again in a process that links the port, with the port's CLASS
// names renamed, and compares the two lists line by line.
//
// This group is built by run.sh's `windowed`, not by `prefixed_windowed`, and that is what decides
// what the two sides share. `windowed` renames whole identifiers only - the classes the objects
// define - and leaves every selector alone, so the port's classes arrive as CharonHost<Name> and
// their methods keep their own names. Nothing here prefixes a selector: the port's hover recogniser
// is a different class from the system's, so -zOffset on one is not -zOffset on the other, and the
// search bar is the release's own class in both processes because this band carries nothing on it.
// The first run of this scenario prefixed the selectors on the strength of the other build path and
// died on `+[CharonHostUITextInputContext charonHostCurrent]`.
//
// The scenario is written the way the rest of this suite writes one: every read is guarded by
// respondsToSelector: or wrapped by ur_raised(), so a member that is not there is recorded as what a
// caller gets - the raise - instead of taking the process down.
#import "uirest.h"

// Which side is running. It decides the CLASS name only; see the note above.
static BOOL h16_port_mode;

// The port's classes reach this file under a CharonHost prefix, and the system's do not, so the two
// sides name one thing: the system side passes [UIHoverGestureRecognizer class] and this is off, the
// port side passes the renamed class and this is on.
static Class h16_class(Class theirs, const char *name)
{
    if (!h16_port_mode)
        return theirs;
    NSString *renamed = [@"CharonHost" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(renamed);
}

// Every read here has its own return type on purpose. A BOOL getter read through a function typed to
// return id reads the same register and hands a byte-wide 0 or 1 to %@ as a pointer, which is the
// segfault that stopped the first run of this recorder at exit 139: the raise was caught, the
// description send was not.
static BOOL h16_get_bool(id target, SEL selector)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
}

static CGFloat h16_get_float(id target, SEL selector)
{
    return ((CGFloat (*)(id, SEL))objc_msgSend)(target, selector);
}

static CGFloat h16_get_float_arg(id target, SEL selector, id view)
{
    return ((CGFloat (*)(id, SEL, id))objc_msgSend)(target, selector, view);
}

static CGVector h16_get_vector_arg(id target, SEL selector, id view)
{
    return ((CGVector (*)(id, SEL, id))objc_msgSend)(target, selector, view);
}

static void h16_set_bool(id target, SEL selector, BOOL value)
{
    ((void (*)(id, SEL, BOOL))objc_msgSend)(target, selector, value);
}

static id h16_call_class(Class cls, SEL selector)
{
    return ((id (*)(Class, SEL))objc_msgSend)(cls, selector);
}

// CGVector is not a Cocoa object, so it is printed here rather than through ur_norm's %@: a CGVector
// printed with %@ is a pointer to it, which is the one value in this scenario that must not move
// between the two runs and would otherwise look like it did.
static NSString *h16_vector(CGVector vector)
{
    return [NSString stringWithFormat:@"%.4f,%.4f", vector.dx, vector.dy];
}

// Whether UISearchBar declares setEnabled: of its own or inherits the one UIView has. This is what
// separates the search bar of this release, whose accessors are UIView's, from the search bar of
// 16.4, which has its own: the host's does not inherit it, and the release's does.
static BOOL h16_own_setter(Class searchbar, Class view)
{
    Method own = class_getInstanceMethod(searchbar, NSSelectorFromString(@"setEnabled:"));
    Method inherited = class_getInstanceMethod(view, NSSelectorFromString(@"setEnabled:"));
    return own != NULL && own == inherited;
}

static NSArray *hover16_scenario(Class hover, UIView *host, UISearchBar *bar, UITextField *field)
{
    NSMutableArray *lines = [NSMutableArray array];

    // The four members of iOS 16.1 and 16.4. rollAngle is recorded beside them because it is the one
    // member of this class from a later release than this band carries, and a scenario that listed
    // only the four could not say which of them the port answers.
    for (NSString *name in @[@"zOffset", @"altitudeAngle", @"azimuthAngleInView:", @"azimuthUnitVectorInView:"]) {
        [lines addObject:ur_line([@"responds" stringByAppendingString:name],
                                 @(class_getInstanceMethod(hover, NSSelectorFromString(name)) != NULL))];
    }
    // rollAngle is 17.5 and this band does not carry it, so its two lines are marked and the test
    // holds them apart from the comparison: the release answers it, the port does not, and that is
    // the answer, not a difference to reconcile.
    [lines addObject:ur_line(@"release respondsrollAngle", @(class_getInstanceMethod(hover, NSSelectorFromString(@"rollAngle")) != NULL))];

    SEL z_offset = NSSelectorFromString(@"zOffset"), altitude = NSSelectorFromString(@"altitudeAngle");
    SEL azimuth = NSSelectorFromString(@"azimuthAngleInView:"), vector_in = NSSelectorFromString(@"azimuthUnitVectorInView:");
    UIGestureRecognizer *made = [[hover alloc] initWithTarget:nil action:NULL];
    [lines addObject:ur_line(@"fresh state", @(made.state))];
    [lines addObject:ur_line(@"zOffset", ur_raised(^id { return @(h16_get_float(made, z_offset)); }))];
    [lines addObject:ur_line(@"altitudeAngle", ur_raised(^id { return @(h16_get_float(made, altitude)); }))];
    [lines addObject:ur_line(@"azimuthAngleInView: nil", ur_raised(^id { return @(h16_get_float_arg(made, azimuth, nil)); }))];
    [lines addObject:ur_line(@"azimuthAngleInView: view", ur_raised(^id { return @(h16_get_float_arg(made, azimuth, host)); }))];
    [lines addObject:ur_line(@"azimuthUnitVectorInView: nil", ur_raised(^id { return h16_vector(h16_get_vector_arg(made, vector_in, nil)); }))];
    [lines addObject:ur_line(@"azimuthUnitVectorInView: view", ur_raised(^id { return h16_vector(h16_get_vector_arg(made, vector_in, host)); }))];
    [lines addObject:ur_line(@"release rollAngle", ur_raised(^id { return @(h16_get_float(made, NSSelectorFromString(@"rollAngle"))); }))];

    // The same four with the recogniser added to a view, because a hover is a pointer over a view and
    // an answer that depended on there being no view would be an answer about the test, not the class.
    if (host) {
        [host addGestureRecognizer:made];
        [lines addObject:ur_line(@"added has a view", ur_yes(made.view != nil))];
        [lines addObject:ur_line(@"zOffset added", ur_raised(^id { return @(h16_get_float(made, z_offset)); }))];
        [lines addObject:ur_line(@"altitudeAngle added", ur_raised(^id { return @(h16_get_float(made, altitude)); }))];
        [lines addObject:ur_line(@"azimuthAngleInView: added", ur_raised(^id { return @(h16_get_float_arg(made, azimuth, host)); }))];
        [lines addObject:ur_line(@"azimuthUnitVectorInView: added", ur_raised(^id { return h16_vector(h16_get_vector_arg(made, vector_in, host)); }))];
        [host removeGestureRecognizer:made];
    }

    // UISearchBar.enabled of iOS 16.4, which this band does not carry. The search bar is the release's
    // own class in both processes, so these reads are the release's answer in both and are here to
    // record it: what a caller that writes enabled gets on a release whose search bar has UIView's
    // accessors rather than the setter of 16.4.
    for (NSString *name in @[@"enabled", @"isEnabled", @"setEnabled:"]) {
        [lines addObject:ur_line([@"searchbar responds" stringByAppendingString:name],
                                 @(class_getInstanceMethod([UISearchBar class], NSSelectorFromString(name)) != NULL))];
    }
    [lines addObject:ur_line(@"searchbar inherits UIView's setter", ur_yes(h16_own_setter([UISearchBar class], [UIView class])))];
    if (bar) {
        SEL enabled = NSSelectorFromString(@"isEnabled"), set_enabled = NSSelectorFromString(@"setEnabled:");
        [lines addObject:ur_line(@"searchbar fresh", @[ur_raised(^id { return @(h16_get_bool(bar, enabled)); }), @(bar.alpha), ur_raised(^id { return @(bar.userInteractionEnabled); })])];
        h16_set_bool(bar, set_enabled, NO);
        [lines addObject:ur_line(@"searchbar disabled", @[ur_raised(^id { return @(h16_get_bool(bar, enabled)); }), @(bar.alpha), ur_raised(^id { return @(bar.userInteractionEnabled); })])];
        if (field)
            [lines addObject:ur_line(@"searchbar field while disabled", @[ur_raised(^id { return @(h16_get_bool(field, enabled)); }), ur_raised(^id { return @(field.userInteractionEnabled); }),
                                                                        ur_raised(^id { return @(field.editable); })])];
        h16_set_bool(bar, set_enabled, YES);
        [lines addObject:ur_line(@"searchbar enabled again", @[ur_raised(^id { return @(h16_get_bool(bar, enabled)); }), @(bar.alpha), ur_raised(^id { return @(bar.userInteractionEnabled); })])];
        if (field)
            [lines addObject:ur_line(@"searchbar field while enabled", @[ur_raised(^id { return @(h16_get_bool(field, enabled)); }), ur_raised(^id { return @(field.userInteractionEnabled); }),
                                                                       ur_raised(^id { return @(field.editable); })])];
    }

    // UITextInputContext of iOS 16.4: the one place an application says which input the user is about
    // to use - a pencil, dictation, or a hardware keyboard - so the keyboard can put up the right one.
    // The header marks -init and +new NS_UNAVAILABLE and gives +current as the only way to have one.
    Class context_class = h16_class([UITextInputContext class], "UITextInputContext");
    [lines addObject:ur_line(@"context class", context_class ? NSStringFromClass(context_class) : @"nil")];
    if (context_class) {
        [lines addObject:ur_line(@"context superclass", class_getSuperclass(context_class) ? NSStringFromClass(class_getSuperclass(context_class)) : @"nil")];
        SEL current = NSSelectorFromString(@"current");
        id one = h16_call_class(context_class, current);
        id two = h16_call_class(context_class, current);
        [lines addObject:ur_line(@"context +current is shared", ur_yes(one != nil && one == two))];
        [lines addObject:ur_line(@"context +new", ur_raised(^id { return h16_call_class(context_class, NSSelectorFromString(@"new")); }))];
        SEL pencil = NSSelectorFromString(@"isPencilInputExpected"), dictation = NSSelectorFromString(@"isDictationInputExpected"),
             keyboard = NSSelectorFromString(@"isHardwareKeyboardInputExpected");
        if (one) {
            [lines addObject:ur_line(@"context fresh", @[ur_raised(^id { return @(h16_get_bool(one, pencil)); }), ur_raised(^id { return @(h16_get_bool(one, dictation)); }),
                                                           ur_raised(^id { return @(h16_get_bool(one, keyboard)); })])];
            h16_set_bool(one, NSSelectorFromString(@"setPencilInputExpected:"), YES);
            h16_set_bool(one, NSSelectorFromString(@"setDictationInputExpected:"), YES);
            h16_set_bool(one, NSSelectorFromString(@"setHardwareKeyboardInputExpected:"), YES);
            [lines addObject:ur_line(@"context after setting", @[ur_raised(^id { return @(h16_get_bool(one, pencil)); }), ur_raised(^id { return @(h16_get_bool(one, dictation)); }),
                                                                  ur_raised(^id { return @(h16_get_bool(one, keyboard)); })])];
            id again = h16_call_class(context_class, current);
            [lines addObject:ur_line(@"context the setting is kept", @[ur_raised(^id { return @(h16_get_bool(again, pencil)); }), ur_raised(^id { return @(h16_get_bool(again, dictation)); }),
                                                                        ur_raised(^id { return @(h16_get_bool(again, keyboard)); })])];
            h16_set_bool(again, NSSelectorFromString(@"setPencilInputExpected:"), NO);
            h16_set_bool(again, NSSelectorFromString(@"setDictationInputExpected:"), NO);
            h16_set_bool(again, NSSelectorFromString(@"setHardwareKeyboardInputExpected:"), NO);
            [lines addObject:ur_line(@"context and taken back", @[ur_raised(^id { return @(h16_get_bool(again, pencil)); }), ur_raised(^id { return @(h16_get_bool(again, dictation)); }),
                                                                  ur_raised(^id { return @(h16_get_bool(again, keyboard)); })])];
        }
    }
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}
