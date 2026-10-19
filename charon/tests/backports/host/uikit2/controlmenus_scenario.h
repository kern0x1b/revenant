#import "uirest.h"
#import <objc/message.h>
#import <stdio.h>

// A control made of actions, on whichever side this binary is.
//
// The port's -insertSegmentWithAction:atIndex:animated: is a carried selector on a host class, so the harness
// renames it and the port's side answers -charonHostInsertSegmentWithAction:atIndex:animated:. Calling the
// public one on the port's side would reach the **host's own** method, and a host method handing a port action
// to the host's label machinery is a mix no device ever has: on 6.x there is no host method of that name at
// all, so the port's own is what runs there. The recorder has no prefixed method and takes the public one,
// which is the host's own - the right answer on that side.
// Whether the class has a method of that name, asked through the class's method list and **not** through
// -respondsToSelector:. NSSelectorFromString on a name that exists nowhere produces a selector that is
// registered by no class and no category, and the runtime's optimised -respondsToSelector: traps on one - which
// is the `brk #0xc472` an lldb run of the recorder stopped in, with a one-frame backtrace because the trap is
// inside a tail call from the host's own -setAction:forSegmentAtIndex:. So the test asks the method list.
static BOOL charon_has_method(Class cls, const char *name)
{
    if (!cls)
        return NO;
    // `sel_registerName` first, and that is the whole of it: NSSelectorFromString on a name nobody registers
    // produces an **unregistered** selector, and the runtime's optimised -respondsToSelector: traps on one -
    // the recorder's exit 133, whose crash report put the trap under
    // _NSDescriptionWithStringProxyFunc and the frame in this file's own block. Registering is a no-op for a
    // name that is already registered, and it makes the question safe to ask for one that is not.
    // `sel_registerName` first, so the selector is **known** even on the side that has no such method, and the
    // runtime's optimised -respondsToSelector: cannot trap on it - the recorder's exit 133 was exactly that trap,
    // with the frame in this file's own block. Then the question is asked of an **object**, because
    // class_getInstanceMethod does not search a class's **categories**, and every method the port adds to a host
    // class is a category's: walking the method lists answered NO for all of them, so the scenario fell back to
    // the host's own method every time and compared the host's answers with themselves.
    SEL selector = sel_registerName(name);
    return [cls instancesRespondToSelector:selector];
}

static void charon_insert_action(UISegmentedControl *control, UIAction *action, NSUInteger index)
{
    const char *renamed = "charonHostInsertSegmentWithAction:atIndex:animated:";
    const char *published = "insertSegmentWithAction:atIndex:animated:";
    SEL chosen = NSSelectorFromString(@(charon_has_method([control class], renamed) ? renamed : published));
    ((void (*)(id, SEL, UIAction *, NSUInteger, BOOL))objc_msgSend)(control, chosen, action, index, NO);
}

// The port's own implementation of a control made of actions, as a value the caller passes. A symbol in the main
// image is only in what dlsym reads when the link exports it, which this harness does not do, and a symbol defined
// in this header would have to be defined once for two binaries that disagree about it; an argument has neither
// problem. The port side passes the port's own function - under its **harness** name, because the renamer
// renames every exported C symbol an object defines - and the recorder passes NULL and takes the public
// initializer, which there is the host's own and the right answer to record.
typedef UISegmentedControl *(*CharonControlWithActions)(UISegmentedControl *, CGRect, NSArray *);

static UISegmentedControl *charon_control_with_actions(CharonControlWithActions entry, CGRect frame, NSArray *actions)
{
    // The one line the coordinator asked for, printed once and on both sides: the port's side passes the port's own
    // function, the recorder's passes NULL. By construction, not by luck.
    static int reported = 0;
    if (!reported++) {
        fprintf(stderr, "[controlmenus] the port's own control-with-actions entry point %s\n",
                entry ? "was found" : "is NOT in this process");
    }
    if (entry)
        return entry([UISegmentedControl alloc], frame, actions);
    SEL published = NSSelectorFromString(@"initWithFrame:actions:");
    return ((id (*)(id, SEL, CGRect, NSArray *))objc_msgSend)([UISegmentedControl alloc], published, frame, actions);
}

static NSString *charon_insert_action_name(UISegmentedControl *control)
{
    return charon_has_method([control class], "charonHostInsertSegmentWithAction:atIndex:animated:") ? @"the port's own"
                                                                                                   : @"the host's own";
}

@interface MenuTarget : NSObject
@end

@implementation MenuTarget
@end

static NSString *bar_line(UIBarButtonItem *item)
{
    return [NSString stringWithFormat:@"title=%@ image=%d menu=%d pa=%d width=%g style=%ld system=%@", item.title ?: @"nil", item.image != nil, item.menu != nil, item.primaryAction != nil, item.width, (long)item.style, @""];
}

// What the control is holding, slot by slot, after each step: the identifier of the action in each slot, or
// NSNull for a slot with none. Printed to stderr so it is not one of the compared lines, and printed on both
// sides so the two can be read against each other - the one disagreement in this group is an identifier the port
// can no longer resolve, and this is where it goes missing.
// A method the port carries, called under the harness's own name when the control has it. `prefixed` is the
// renamer's rule - the first **keyword** camel-cased with the prefix glued inside it - so
// `actionForSegmentAtIndex:` is `charonHostActionForSegmentAtIndex:` and
// `segmentIndexForActionIdentifier:` is `charonHostSegmentIndexForActionIdentifier:`.
static SEL charon_carried(Class cls, const char *published)
{
    // The renamer's rule is the prefix glued inside the first **keyword**, with that keyword's first letter
    // capitalised: `actionForSegmentAtIndex:` is `charonHostActionForSegmentAtIndex:`. Plain concatenation
    // gives `charonHostactionForSegmentAtIndex:`, which nothing defines, so the question answered NO and the
    // scenario fell back to the host's method - the very mix this whole line of work is about.
    char *name = malloc(strlen(published) + 16);
    strcpy(name, "charonHost");
    // Index **10**, not 9: "charonHost" is ten characters, so index 9 is its own `t` - writing the capitalised
    // letter there built `charonHosActionForSegmentAtIndex:`, which is why the port's method was never reached.
    name[10] = (char)(published[0] >= 'a' && published[0] <= 'z' ? published[0] - 'a' + 'A' : published[0]);
    strcat(name, published + 1);
    SEL prefixed = sel_registerName(name);
    // The question is asked **before** the name is freed. Asked after, it is about freed memory and answers
    // whatever that memory happens to say - which is why every version of this helper fell back to the host's
    // method and the compared line compared the host's answers with themselves.
    BOOL has = charon_has_method(cls, name);
    free(name);
    return has ? prefixed : sel_registerName(published);
}

// The two lookups, asked under the harness's own name when the control has them. On the port's side the
// public name is the **host's** method - the port's are carried selectors the harness renamed - and the host's
// reads the host's store, which the port never writes; so a line built from the public calls compares the
// host's answers with themselves. The recorder has neither prefixed method and takes the public one, which is
// the host's own and the right answer on that side.
static id charon_action_at(UISegmentedControl *control, NSUInteger index)
{
    SEL selector = charon_carried([UISegmentedControl class], "actionForSegmentAtIndex:");
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(control, selector, index);
}

static void charon_set_action(UISegmentedControl *control, UIAction *action, NSUInteger index)
{
    SEL selector = charon_carried([UISegmentedControl class], "setAction:forSegmentAtIndex:");
    ((void (*)(id, SEL, UIAction *, NSUInteger))objc_msgSend)(control, selector, action, index);
}

static NSInteger charon_index_of(UISegmentedControl *control, NSString *identifier)
{
    SEL selector = charon_carried([UISegmentedControl class], "segmentIndexForActionIdentifier:");
    return ((NSInteger (*)(id, SEL, NSString *))objc_msgSend)(control, selector, identifier);
}

static void charon_dump_slots(const char *tag, UISegmentedControl *control)
{
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < control.numberOfSegments; index++) {
        id held = charon_action_at(control, index);
        if (index)
            [text appendString:@" | "];
        [text appendFormat:@"%lu=%@", (unsigned long)index,
                                 [held respondsToSelector:@selector(identifier)]
                                     ? ([held identifier] ?: @"nil")
                                     : ([held isKindOfClass:[NSNull class]] ? @"NSNull" : @"not an action")];
    }
    fprintf(stderr, "[controlmenus] %-22s %s\n", tag, [text UTF8String]);
}

static NSArray *menu_scenario(Class actionClass, Class menuClass, CharonControlWithActions entry)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIImage *image = [[UIImage alloc] init];
    __block int fired = 0;
    UIAction *a = [actionClass actionWithTitle:@"AT" image:image identifier:@"idx" handler:^(id x) { fired++; }];
    UIMenu *m = [menuClass menuWithTitle:@"M" children:@[a]];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [lines addObject:ur_line(@"button", @[b.menu ?: @"nil", ur_yes(b.showsMenuAsPrimaryAction), ur_yes(b.contextMenuInteractionEnabled), @(b.role)])];
    b.menu = m;
    [lines addObject:ur_line(@"menu set", @[ur_yes([b.menu isEqual:m]), ur_yes(b.menu != m), ur_yes(b.showsMenuAsPrimaryAction), ur_yes(b.contextMenuInteractionEnabled), ur_yes(b.contextMenuInteraction != nil)])];
    b.showsMenuAsPrimaryAction = YES;
    [lines addObject:ur_line(@"primary", @[ur_yes(b.showsMenuAsPrimaryAction), ur_yes(b.contextMenuInteractionEnabled)])];
    b.menu = nil;
    [lines addObject:ur_line(@"menu nil", @[ur_yes(b.contextMenuInteractionEnabled), ur_yes(b.showsMenuAsPrimaryAction), b.menu ?: @"nil"])];
    UIButton *c = [UIButton buttonWithType:UIButtonTypeCustom];
    c.contextMenuInteractionEnabled = YES;
    [lines addObject:ur_line(@"enabled", @[ur_yes(c.contextMenuInteractionEnabled), ur_yes(c.contextMenuInteraction != nil), ur_yes(c.contextMenuInteraction.delegate == c)])];
    UIContextMenuConfiguration *cf = [c contextMenuInteraction:c.contextMenuInteraction configurationForMenuAtLocation:CGPointZero];
    [lines addObject:ur_line(@"configuration without a menu", @[ur_yes(cf != nil), cf.identifier ? @"identifier" : @"nil"])];
    c.menu = m;
    cf = [c contextMenuInteraction:c.contextMenuInteraction configurationForMenuAtLocation:CGPointZero];
    [lines addObject:ur_line(@"configuration with a menu", @[ur_yes(cf != nil)])];
    [lines addObject:ur_line(@"previews", @[[c contextMenuInteraction:nil previewForHighlightingMenuWithConfiguration:cf] ?: @"nil", [c contextMenuInteraction:nil previewForDismissingMenuWithConfiguration:cf] ?: @"nil"])];
    [lines addObject:ur_line(@"answers", @[ur_yes([c respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)]), ur_yes([c respondsToSelector:@selector(contextMenuInteraction:willEndForConfiguration:animator:)]),
                                           ur_yes([c respondsToSelector:@selector(contextMenuInteraction:willPerformPreviewActionForMenuWithConfiguration:animator:)]), ur_yes([c respondsToSelector:@selector(contextMenuInteraction:previewForHighlightingMenuWithConfiguration:)])])];
    b.role = UIButtonRoleDestructive;
    [lines addObject:ur_line(@"role", @(b.role))];

    UIButton *d2 = [UIButton buttonWithType:UIButtonTypeSystem primaryAction:a];
    [lines addObject:ur_line(@"button with type and action", @[[d2 titleForState:UIControlStateNormal] ?: @"nil", ur_yes([d2 imageForState:UIControlStateNormal] != nil), @(d2.buttonType)])];
    UIButton *d3 = [UIButton systemButtonWithPrimaryAction:a];
    [lines addObject:ur_line(@"system button", @[@(d3.buttonType), [d3 titleForState:UIControlStateNormal] ?: @"nil"])];
    UIButton *d4 = [UIButton systemButtonWithImage:image target:nil action:NULL];
    [lines addObject:ur_line(@"system button with image", @[@(d4.buttonType), ur_yes([d4 imageForState:UIControlStateNormal] != nil)])];
    UIButton *d5 = [UIButton buttonWithType:UIButtonTypeCustom primaryAction:nil];
    [lines addObject:ur_line(@"button with no action", @[@(d5.buttonType), [d5 titleForState:UIControlStateNormal] ?: @"nil"])];

    UIBarButtonItem *i1 = [[UIBarButtonItem alloc] initWithPrimaryAction:a];
    [lines addObject:ur_line(@"item with an action", @[bar_line(i1), ur_yes(i1.primaryAction != a), ur_yes([i1.primaryAction isEqual:a])])];
    UIBarButtonItem *i2 = [[UIBarButtonItem alloc] initWithTitle:@"T" menu:m];
    [lines addObject:ur_line(@"item with a menu", @[bar_line(i2), ur_yes([i2.menu isEqual:m])])];
    UIBarButtonItem *i3 = [[UIBarButtonItem alloc] initWithImage:image menu:m];
    [lines addObject:ur_line(@"item with an image and a menu", @[bar_line(i3)])];
    UIBarButtonItem *i4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd menu:m];
    [lines addObject:ur_line(@"item with a system item and a menu", @[ur_yes(i4.menu != nil), ur_yes(i4.primaryAction == nil)])];
    UIBarButtonItem *i5 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd primaryAction:a];
    [lines addObject:ur_line(@"item with a system item and an action", @[ur_yes(i5.primaryAction != nil), i5.title ?: @"nil", ur_yes(i5.image != nil)])];
    i2.menu = nil;
    [lines addObject:ur_line(@"item without a menu", i2.menu ?: @"nil")];
    i2.primaryAction = a;
    [lines addObject:ur_line(@"item given an action", @[i2.title ?: @"nil", ur_yes(i2.image != nil)])];
    i2.primaryAction = nil;
    [lines addObject:ur_line(@"item without an action", @[i2.title ?: @"nil", ur_yes(i2.image != nil), i2.primaryAction ?: @"nil"])];
    i1.title = @"changed";
    [lines addObject:ur_line(@"item title changed", @[i1.title, i1.primaryAction.title])];
    [lines addObject:ur_line(@"item with nil", ur_raised(^id { return [[UIBarButtonItem alloc] initWithPrimaryAction:nil]; }))];
    UIBarButtonItem *fixed = [UIBarButtonItem fixedSpaceItemOfWidth:10], *flexible = [UIBarButtonItem flexibleSpaceItem];
    [lines addObject:ur_line(@"spaces", @[@(fixed.width), fixed.menu ?: @"nil", flexible.primaryAction ?: @"nil", ur_yes(fixed != flexible)])];

    UIAction *b1 = [actionClass actionWithTitle:@"B" image:nil identifier:@"idy" handler:^(id x) {}];
    UISegmentedControl *sg = charon_control_with_actions(entry, CGRectMake(0, 0, 200, 30), @[ a, b1 ]);
    [lines addObject:ur_line(@"segments", @[@(sg.numberOfSegments), @(sg.selectedSegmentIndex), [sg titleForSegmentAtIndex:0] ?: @"nil", [sg titleForSegmentAtIndex:1] ?: @"nil", ur_yes([sg imageForSegmentAtIndex:0] != nil),
                                           ur_yes(charon_action_at(sg, 0) != a), ur_yes([charon_action_at(sg, 0) isEqual:a]), @(charon_index_of(sg, @"idy")), @(charon_index_of(sg, @"nope"))])];
    UIAction *cc = [actionClass actionWithTitle:@"C" image:nil identifier:@"idz" handler:^(id x) {}];
    charon_dump_slots("built", sg);
    charon_insert_action(sg, cc, 1);
    charon_dump_slots("after the insert", sg);
    [lines addObject:ur_line(@"inserted", @[@(sg.numberOfSegments), [sg titleForSegmentAtIndex:1], @(charon_index_of(sg, @"idz")), @(charon_index_of(sg, @"idy"))])];
    [lines addObject:ur_line(@"set a taken identifier", ur_raised(^id { charon_set_action(sg, a, 1); return @"no"; }))];
    UIAction *n9 = [actionClass actionWithTitle:@"N9" image:nil identifier:@"id9" handler:^(id x) {}];
    charon_set_action(sg, n9, 1);
    charon_dump_slots("after setAction", sg);
    [lines addObject:ur_line(@"set an action", @[[sg titleForSegmentAtIndex:1], ur_yes([sg imageForSegmentAtIndex:1] != nil)])];
    [sg insertSegmentWithTitle:@"plain" atIndex:0 animated:NO];
    charon_dump_slots("after a plain insert", sg);
    [lines addObject:ur_line(@"a plain segment", @[charon_action_at(sg, 0) ?: @"nil", @(charon_index_of(sg, @"idx")), @(charon_index_of(sg, @"id9"))])];
    [sg removeSegmentAtIndex:0 animated:NO];
    charon_dump_slots("after the removal", sg);
    [lines addObject:ur_line(@"segment removed", @[@(charon_index_of(sg, @"idx")), @(charon_index_of(sg, @"id9"))])];
    [lines addObject:ur_line(@"no action", @[charon_action_at(sg, 9) ?: @"nil", charon_action_at([[UISegmentedControl alloc] initWithItems:@[@"q"]], 0) ?: @"nil"])];
    [lines addObject:ur_line(@"unique on insert", ur_raised(^id { charon_insert_action(sg, cc, 0); return @"no"; }))];
    // The two action classes side by side in one window. `UIAction` is the host's own on both sides of a
    // differential - the port's is renamed to CharonHostUIAction - so the first pair is the same class in both
    // binaries and the second is the one this binary carries, and the host's comes first so that a side which
    // cannot take the second one has printed the first one's answer before it stops. Which of the two the
    // segment takes is the whole of the difference the -[CharonHostUIAction length] fault turns on.
    for (NSArray *pair in @[ @[ @"the host's", NSClassFromString(@"UIAction") ], @[ @"this binary's", actionClass ] ]) {
        UIAction *one = [pair[1] actionWithTitle:@"AT" image:nil
                                       identifier:[NSString stringWithFormat:@"id-%@", pair[0]]
                                          handler:^(id x) {}];
        UISegmentedControl *own = [[UISegmentedControl alloc] initWithItems:@[ @"seed" ]];
        NSString *outcome = ur_raised(^id {
            charon_insert_action(own, one, 0);
            UIAction *back = charon_action_at(own, 0);
            // **Which** path each side took is printed to stderr, not put in the compared line: it differs by
            // construction - the port's side runs the port's own insert, the recorder's the host's - and a field
            // that is meant to differ cannot be inside a line that is compared for equality.
            fprintf(stderr, "[controlmenus] %s took %s\n", [[pair[0] description] UTF8String],
                    [[charon_insert_action_name(own) description] UTF8String]);
            return [NSString stringWithFormat:@"segments=%ld title=%@ back=%@", (long)own.numberOfSegments,
                                              [own titleForSegmentAtIndex:0] ?: @"nil", back.title ?: @"nil"];
        });
        [lines addObject:ur_line([@"an action from " stringByAppendingString:pair[0]], @[outcome])];
    }
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}
