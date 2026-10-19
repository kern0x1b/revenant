#import <UIKit/UIKit.h>
#include <stdio.h>
#import "CharonMenus.h"

// The host's own menus and the port's, run on the same checks. A line is "side<TAB>check<TAB>value": "host" and "port" lines are compared.
// The port's classes are compiled with UIMenu and UIMenuElement renamed, so [UIMenu class] here is the port's; the host's are reached by name.
// The host's items are real actions; the port's are a subclass of the port's element that carries a state, because the port's selection
// asks an element for its state and the port's own action is not compiled into this check.

typedef id (*PlainFn)(id, SEL);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *number(NSInteger value)
{
    return [NSString stringWithFormat:@"%ld", (long)value];
}

static NSString *titles(NSArray *items)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (id item in items)
        [parts addObject:[item title] ?: @"(nil)"];
    return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@","]];
}

@interface CharonStateItem : UIMenuElement
@property (nonatomic) UIMenuElementState state;
@end

@implementation CharonStateItem
@end

static id make_item(BOOL portSide, NSString *title, UIMenuElementState state)
{
    if (portSide) {
        CharonStateItem *item = [[CharonStateItem alloc] initCharonWithTitle:title image:nil];
        item.state = state;
        return item;
    }
    Class actionClass = NSClassFromString(@"UIAction");
    UIAction *action = [actionClass actionWithTitle:title image:nil identifier:nil handler:^(UIAction *a) {}];
    action.state = state;
    return action;
}

static id make_base_element(BOOL portSide)
{
    Class elementClass = portSide ? [UIMenuElement class] : NSClassFromString(@"UIMenuElement");
    SEL initSelector = @selector(init);
    return ((PlainFn)[[elementClass alloc] methodForSelector:initSelector])([elementClass alloc], initSelector);
}

static void run(const char *side, BOOL portSide, Class menuClass)
{
    // The default and the set size, measured on the host: -1 until set, the value kept as given (even one the enum does not name),
    // a copy and a menu made with other children keeping the value.
    id menu = [menuClass menuWithTitle:@"root" children:@[]];
    report(side, "size-default", number([menu preferredElementSize]));
    [menu setPreferredElementSize:2];
    report(side, "size-set-large", number([menu preferredElementSize]));
    [menu setPreferredElementSize:7];
    report(side, "size-set-unnamed", number([menu preferredElementSize]));
    [menu setPreferredElementSize:0];
    report(side, "size-set-small", number([menu preferredElementSize]));
    report(side, "size-copy", number([[menu copy] preferredElementSize]));
    report(side, "size-replaced", number([[menu menuByReplacingChildren:@[]] preferredElementSize]));
    id fresh = [menuClass menuWithTitle:@"x" image:nil identifier:@"id.x" options:UIMenuOptionsDisplayInline children:@[]];
    report(side, "size-fresh-default", number([fresh preferredElementSize]));

    // The selected elements: the on ones of the menu and of its sub-menus, in order; a mixed one and an off one are not selected.
    id on = make_item(portSide, @"on", UIMenuElementStateOn);
    id off = make_item(portSide, @"off", UIMenuElementStateOff);
    id mixed = make_item(portSide, @"mixed", UIMenuElementStateMixed);
    id on2 = make_item(portSide, @"on2", UIMenuElementStateOn);
    id sub = [menuClass menuWithTitle:@"sub" children:@[on2, off]];
    id root = [menuClass menuWithTitle:@"root" children:@[on, off, sub, mixed]];
    report(side, "selected-root", titles([root selectedElements]));
    report(side, "selected-same-object", yes_no([root selectedElements].count == 2 && [root selectedElements][0] == on));
    report(side, "selected-sub", titles([sub selectedElements]));
    id onlySub = [menuClass menuWithTitle:@"r" children:@[sub]];
    report(side, "selected-only-sub", titles([onlySub selectedElements]));
    report(side, "selected-none", titles([fresh selectedElements]));
    report(side, "selected-nested-deep", titles([[menuClass menuWithTitle:@"r" children:@[onlySub, mixed]] selectedElements]));

    // The subtitle of an element: nil until set, a copy of the value given, and nil clears it. A menu keeps its subtitle through a copy
    // and through a menu made with other children.
    id base = make_base_element(portSide);
    report(side, "element-subtitle-default", [base subtitle]);
    NSMutableString *given = [NSMutableString stringWithString:@"sub"];
    [base setSubtitle:given];
    [given appendString:@"changed"];
    report(side, "element-subtitle-copied", [base subtitle]);
    [base setSubtitle:nil];
    report(side, "element-subtitle-cleared", [base subtitle]);
    id titled = [menuClass menuWithTitle:@"t" children:@[]];
    report(side, "menu-subtitle-default", [titled subtitle]);
    [titled setSubtitle:@"menu-sub"];
    report(side, "menu-subtitle-set", [titled subtitle]);
    report(side, "menu-subtitle-copy", [[titled copy] subtitle]);
    report(side, "menu-subtitle-replaced", [[titled menuByReplacingChildren:@[]] subtitle]);
    report(side, "menu-replaced-identifier", yes_no([[titled menuByReplacingChildren:@[]] identifier] && [[[titled menuByReplacingChildren:@[]] identifier] isEqualToString:[titled identifier]]));
}

// The port's own checks: a plain element, one that has no state, is never selected; a menu nothing has sized answers -1 through its archive.
static void runPortOnly(void)
{
    id plain = make_base_element(YES);
    id menu = [UIMenu menuWithTitle:@"r" children:@[plain]];
    report("only", "plain-element-not-selected", [menu selectedElements].count == 0 ? @"yes" : @"no");
    report("only", "menu-children-kept", [[menu children] count] == 1 ? @"yes" : @"no");
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NO, NSClassFromString(@"UIMenu"));
        run("port", YES, [UIMenu class]);
        runPortOnly();
    }
    return 0;
}
