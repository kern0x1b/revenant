#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"

@interface UIMenuController (CharonHostMenus)
- (void)charonHostShowMenuFromView:(UIView *)view rect:(CGRect)rect;
- (void)charonHostHideMenuFromView:(UIView *)view;
- (void)charonHostHideMenu;
@end

void charon_windowed_run(UIWindow *window);

static NSMutableArray *seen;
static UIView *expected;

static void seen_target(id self, SEL command, CGRect rect, UIView *view)
{
    [seen addObject:[NSString stringWithFormat:@"target %@ %d", NSStringFromCGRect(rect), view == expected]];
}

static void seen_visible(id self, SEL command, BOOL visible, BOOL animated)
{
    [seen addObject:[NSString stringWithFormat:@"visible %d animated %d", visible, animated]];
}

void charon_windowed_run(UIWindow *window)
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    [window addSubview:view];
    expected = view;
    seen = [NSMutableArray array];
    Method target = class_getInstanceMethod([UIMenuController class], @selector(setTargetRect:inView:));
    Method visible = class_getInstanceMethod([UIMenuController class], @selector(setMenuVisible:animated:));
    IMP originalTarget = method_setImplementation(target, (IMP)seen_target);
    IMP originalVisible = method_setImplementation(visible, (IMP)seen_visible);
    UIMenuController *controller = [UIMenuController sharedMenuController];
    [controller charonHostShowMenuFromView:view rect:CGRectMake(10, 10, 20, 20)];
    NSArray *shown = [seen copy];
    [seen removeAllObjects];
    [controller charonHostHideMenuFromView:view];
    NSArray *hiddenFrom = [seen copy];
    [seen removeAllObjects];
    [controller charonHostHideMenu];
    NSArray *hidden = [seen copy];
    method_setImplementation(target, originalTarget);
    method_setImplementation(visible, originalVisible);
    charon_check([shown isEqual:@[@"target {{10, 10}, {20, 20}} 1", @"visible 1 animated 1"]], "showing a menu sets the target rect in the view and shows the menu animated", shown.description);
    charon_check([hiddenFrom isEqual:@[@"visible 0 animated 1"]], "hiding from a view hides the menu animated", hiddenFrom.description);
    charon_check([hidden isEqual:@[@"visible 0 animated 1"]], "hiding hides the menu animated", hidden.description);
    
}
