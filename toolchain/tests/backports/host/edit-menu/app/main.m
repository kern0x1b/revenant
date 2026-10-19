#import <UIKit/UIKit.h>
#include <stdio.h>

static FILE *out;
static const char *side;
static int sequence;

static void report(const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"RevenantPort"] ? [name substringFromIndex:12] : name;
}

static FILE *hostOnly;

static void report_host(const char *check, NSString *value)
{
    if (hostOnly)
        fprintf(hostOnly, "%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static void call(NSString *what)
{
    report("delegate-call", [NSString stringWithFormat:@"%d %@", ++sequence, what]);
}

@interface RevenantEditMenuDelegate : NSObject <UIEditMenuInteractionDelegate>
@property (nonatomic, strong) UIMenu *menu;
@end

@implementation RevenantEditMenuDelegate

- (UIMenu *)editMenuInteraction:(UIEditMenuInteraction *)interaction menuForConfiguration:(UIEditMenuConfiguration *)configuration suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions
{
    call([NSString stringWithFormat:@"menuForConfiguration suggested=%lu identifier=%@ sourceX=%g sourceY=%g", (unsigned long)suggestedActions.count,
          configuration.identifier, configuration.sourcePoint.x, configuration.sourcePoint.y]);
    return self.menu;
}

- (CGRect)editMenuInteraction:(UIEditMenuInteraction *)interaction targetRectForConfiguration:(UIEditMenuConfiguration *)configuration
{
    call(@"targetRectForConfiguration");
    return CGRectMake(5, 6, 7, 8);
}

- (void)editMenuInteraction:(UIEditMenuInteraction *)interaction willDismissMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator
{
    call(@"willDismissMenuForConfiguration");
}

@end

@interface RevenantSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantSceneDelegate

static void checks(UIView *view, UIEditMenuInteraction *(^make)(id<UIEditMenuInteractionDelegate>))
{
    RevenantEditMenuDelegate *delegate = [[RevenantEditMenuDelegate alloc] init];
    delegate.menu = [UIMenu menuWithTitle:@"menu" children:@[[UIAction actionWithTitle:@"first" image:nil identifier:nil handler:^(UIAction *action) {}]]];
    UIEditMenuInteraction *interaction = make(delegate);
    report("interaction-class", class_name(interaction));
    report("delegate-kept", yes_no(interaction.delegate == delegate));
    report("view-before-add", yes_no(interaction.view == nil));
    report("interactions-before-add", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
    [view addInteraction:interaction];
    report_host("interactions-after-add-classes", [[view.interactions valueForKey:@"description"] componentsJoinedByString:@"|"]);
    report("view-after-add", yes_no(interaction.view == view));
    report_host("interactions-after-add", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);

    UIEditMenuConfiguration *configuration = [UIEditMenuConfiguration configurationWithIdentifier:@"identifier" sourcePoint:CGPointMake(10, 11)];
    report("configuration-class", class_name(configuration));
    report("configuration-arrow-default", [NSString stringWithFormat:@"%ld", (long)configuration.preferredArrowDirection]);
    [interaction presentEditMenuWithConfiguration:configuration];
    CGPoint location = [interaction locationInView:view];
    report("location-in-view", NSStringFromCGPoint(location));
    report("location-in-nil", NSStringFromCGPoint([interaction locationInView:nil]));
    [interaction reloadVisibleMenu];
    [interaction updateVisibleMenuPositionAnimated:NO];
    [interaction dismissMenu];
    [view removeInteraction:interaction];
    report("view-after-remove", yes_no(interaction.view == nil));
    report_host("interactions-after-remove", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("REVENANT_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifndef REVENANT_PORT_SIDE
    const char *extra = getenv("REVENANT_HOST_ONLY_OUT");
    hostOnly = extra ? fopen(extra, "w") : NULL;
#endif
#ifdef REVENANT_PORT_SIDE
    side = "port";
#else
    side = "host";
#endif
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    UIViewController *root = [[UIViewController alloc] init];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    [root.view addSubview:view];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.window layoutIfNeeded];
        report("scene-activation-state", [NSString stringWithFormat:@"%ld", (long)self.window.windowScene.activationState]);
        report("window-key", yes_no(self.window.isKeyWindow));
        report("view-in-window", yes_no(view.window == self.window));
        {
            RevenantEditMenuDelegate *gone = [[RevenantEditMenuDelegate alloc] init];
            __weak id weakDelegate = gone;
            UIEditMenuInteraction *lone = [[UIEditMenuInteraction alloc] initWithDelegate:gone];
            gone = nil;
            report("delegate-weak-after-release", yes_no(lone.delegate == nil && weakDelegate == nil));
        }
        checks(view, ^UIEditMenuInteraction *(id<UIEditMenuInteractionDelegate> delegate) {
            return [[UIEditMenuInteraction alloc] initWithDelegate:delegate];
        });
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        fclose(out);
        if (hostOnly)
            fclose(hostOnly);
        exit(0);
    });
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantSceneDelegate class]));
    }
}
