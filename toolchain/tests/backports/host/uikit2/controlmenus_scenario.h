#import "uirest.h"
#import <objc/message.h>
#import <stdio.h>

static BOOL revenant_has_method(Class cls, const char *name)
{
    if (!cls)
        return NO;
    SEL selector = sel_registerName(name);
    return [cls instancesRespondToSelector:selector];
}

static void revenant_insert_action(UISegmentedControl *control, UIAction *action, NSUInteger index)
{
    const char *renamed = "revenantHostInsertSegmentWithAction:atIndex:animated:";
    const char *published = "insertSegmentWithAction:atIndex:animated:";
    SEL chosen = NSSelectorFromString(@(revenant_has_method([control class], renamed) ? renamed : published));
    ((void (*)(id, SEL, UIAction *, NSUInteger, BOOL))objc_msgSend)(control, chosen, action, index, NO);
}

typedef UISegmentedControl *(*RevenantControlWithActions)(UISegmentedControl *, CGRect, NSArray *);

static UISegmentedControl *revenant_control_with_actions(RevenantControlWithActions entry, CGRect frame, NSArray *actions)
{
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

static NSString *revenant_insert_action_name(UISegmentedControl *control)
{
    return revenant_has_method([control class], "revenantHostInsertSegmentWithAction:atIndex:animated:") ? @"the port's own"
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

static SEL revenant_carried(Class cls, const char *published)
{
    char *name = malloc(strlen(published) + 16);
    strcpy(name, "revenantHost");
    name[12] = (char)(published[0] >= 'a' && published[0] <= 'z' ? published[0] - 'a' + 'A' : published[0]);
    strcat(name, published + 1);
    SEL prefixed = sel_registerName(name);
    BOOL has = revenant_has_method(cls, name);
    free(name);
    return has ? prefixed : sel_registerName(published);
}

static id revenant_action_at(UISegmentedControl *control, NSUInteger index)
{
    SEL selector = revenant_carried([UISegmentedControl class], "actionForSegmentAtIndex:");
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)(control, selector, index);
}

static void revenant_set_action(UISegmentedControl *control, UIAction *action, NSUInteger index)
{
    SEL selector = revenant_carried([UISegmentedControl class], "setAction:forSegmentAtIndex:");
    ((void (*)(id, SEL, UIAction *, NSUInteger))objc_msgSend)(control, selector, action, index);
}

static NSInteger revenant_index_of(UISegmentedControl *control, NSString *identifier)
{
    SEL selector = revenant_carried([UISegmentedControl class], "segmentIndexForActionIdentifier:");
    return ((NSInteger (*)(id, SEL, NSString *))objc_msgSend)(control, selector, identifier);
}

static void revenant_dump_slots(const char *tag, UISegmentedControl *control)
{
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < control.numberOfSegments; index++) {
        id held = revenant_action_at(control, index);
        if (index)
            [text appendString:@" | "];
        [text appendFormat:@"%lu=%@", (unsigned long)index,
                                 [held respondsToSelector:@selector(identifier)]
                                     ? ([held identifier] ?: @"nil")
                                     : ([held isKindOfClass:[NSNull class]] ? @"NSNull" : @"not an action")];
    }
    fprintf(stderr, "[controlmenus] %-22s %s\n", tag, [text UTF8String]);
}

static NSArray *menu_scenario(Class actionClass, Class menuClass, RevenantControlWithActions entry)
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
    UISegmentedControl *sg = revenant_control_with_actions(entry, CGRectMake(0, 0, 200, 30), @[ a, b1 ]);
    [lines addObject:ur_line(@"segments", @[@(sg.numberOfSegments), @(sg.selectedSegmentIndex), [sg titleForSegmentAtIndex:0] ?: @"nil", [sg titleForSegmentAtIndex:1] ?: @"nil", ur_yes([sg imageForSegmentAtIndex:0] != nil),
                                           ur_yes(revenant_action_at(sg, 0) != a), ur_yes([revenant_action_at(sg, 0) isEqual:a]), @(revenant_index_of(sg, @"idy")), @(revenant_index_of(sg, @"nope"))])];
    UIAction *cc = [actionClass actionWithTitle:@"C" image:nil identifier:@"idz" handler:^(id x) {}];
    revenant_dump_slots("built", sg);
    revenant_insert_action(sg, cc, 1);
    revenant_dump_slots("after the insert", sg);
    [lines addObject:ur_line(@"inserted", @[@(sg.numberOfSegments), [sg titleForSegmentAtIndex:1], @(revenant_index_of(sg, @"idz")), @(revenant_index_of(sg, @"idy"))])];
    [lines addObject:ur_line(@"set a taken identifier", ur_raised(^id { revenant_set_action(sg, a, 1); return @"no"; }))];
    UIAction *n9 = [actionClass actionWithTitle:@"N9" image:nil identifier:@"id9" handler:^(id x) {}];
    revenant_set_action(sg, n9, 1);
    revenant_dump_slots("after setAction", sg);
    [lines addObject:ur_line(@"set an action", @[[sg titleForSegmentAtIndex:1], ur_yes([sg imageForSegmentAtIndex:1] != nil)])];
    [sg insertSegmentWithTitle:@"plain" atIndex:0 animated:NO];
    revenant_dump_slots("after a plain insert", sg);
    [lines addObject:ur_line(@"a plain segment", @[revenant_action_at(sg, 0) ?: @"nil", @(revenant_index_of(sg, @"idx")), @(revenant_index_of(sg, @"id9"))])];
    [sg removeSegmentAtIndex:0 animated:NO];
    revenant_dump_slots("after the removal", sg);
    [lines addObject:ur_line(@"segment removed", @[@(revenant_index_of(sg, @"idx")), @(revenant_index_of(sg, @"id9"))])];
    [lines addObject:ur_line(@"no action", @[revenant_action_at(sg, 9) ?: @"nil", revenant_action_at([[UISegmentedControl alloc] initWithItems:@[@"q"]], 0) ?: @"nil"])];
    [lines addObject:ur_line(@"unique on insert", ur_raised(^id { revenant_insert_action(sg, cc, 0); return @"no"; }))];
    for (NSArray *pair in @[ @[ @"the host's", NSClassFromString(@"UIAction") ], @[ @"this binary's", actionClass ] ]) {
        UIAction *one = [pair[1] actionWithTitle:@"AT" image:nil
                                       identifier:[NSString stringWithFormat:@"id-%@", pair[0]]
                                          handler:^(id x) {}];
        UISegmentedControl *own = [[UISegmentedControl alloc] initWithItems:@[ @"seed" ]];
        NSString *outcome = ur_raised(^id {
            revenant_insert_action(own, one, 0);
            UIAction *back = revenant_action_at(own, 0);
            fprintf(stderr, "[controlmenus] %s took %s\n", [[pair[0] description] UTF8String],
                    [[revenant_insert_action_name(own) description] UTF8String]);
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
