#import "uirest.h"

static BOOL h16_port_mode;

static Class h16_class(Class theirs, const char *name)
{
    if (!h16_port_mode)
        return theirs;
    NSString *renamed = [@"CharonHost" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(renamed);
}

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

static NSString *h16_vector(CGVector vector)
{
    return [NSString stringWithFormat:@"%.4f,%.4f", vector.dx, vector.dy];
}

static BOOL h16_own_setter(Class searchbar, Class view)
{
    Method own = class_getInstanceMethod(searchbar, NSSelectorFromString(@"setEnabled:"));
    Method inherited = class_getInstanceMethod(view, NSSelectorFromString(@"setEnabled:"));
    return own != NULL && own == inherited;
}

static NSArray *hover16_scenario(Class hover, UIView *host, UISearchBar *bar, UITextField *field)
{
    NSMutableArray *lines = [NSMutableArray array];

    for (NSString *name in @[@"zOffset", @"altitudeAngle", @"azimuthAngleInView:", @"azimuthUnitVectorInView:"]) {
        [lines addObject:ur_line([@"responds" stringByAppendingString:name],
                                 @(class_getInstanceMethod(hover, NSSelectorFromString(name)) != NULL))];
    }
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

    if (host) {
        [host addGestureRecognizer:made];
        [lines addObject:ur_line(@"added has a view", ur_yes(made.view != nil))];
        [lines addObject:ur_line(@"zOffset added", ur_raised(^id { return @(h16_get_float(made, z_offset)); }))];
        [lines addObject:ur_line(@"altitudeAngle added", ur_raised(^id { return @(h16_get_float(made, altitude)); }))];
        [lines addObject:ur_line(@"azimuthAngleInView: added", ur_raised(^id { return @(h16_get_float_arg(made, azimuth, host)); }))];
        [lines addObject:ur_line(@"azimuthUnitVectorInView: added", ur_raised(^id { return h16_vector(h16_get_vector_arg(made, vector_in, host)); }))];
        [host removeGestureRecognizer:made];
    }

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
