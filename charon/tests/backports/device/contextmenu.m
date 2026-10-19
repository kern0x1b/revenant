#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const results_folder = @"/private/var/backports";

static BOOL wait_until(BOOL (^done)(void), NSTimeInterval seconds)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static UIActionSheet *find_sheet(UIView *view)
{
    if ([view isKindOfClass:[UIActionSheet class]])
        return (UIActionSheet *)view;
    for (UIView *sub in view.subviews) {
        UIActionSheet *found = find_sheet(sub);
        if (found)
            return found;
    }
    return nil;
}

static UIActionSheet *visible_sheet(void)
{
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIActionSheet *sheet = find_sheet(window);
        if (sheet)
            return sheet;
    }
    return nil;
}

@interface CharonMenuHost : UIViewController <UIContextMenuInteractionDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic, strong) UIContextMenuInteraction *interaction;
@end

@implementation CharonMenuHost

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    [self.log addObject:@"configuration"];
    return [UIContextMenuConfiguration configurationWithIdentifier:@"menu" previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *copy = [UIAction actionWithTitle:@"Copy" image:nil identifier:nil handler:^(UIAction *action) { [self.log addObject:@"copy"]; }];
        UIAction *remove = [UIAction actionWithTitle:@"Delete" image:nil identifier:nil handler:^(UIAction *action) { [self.log addObject:@"delete"]; }];
        remove.attributes = UIMenuElementAttributesDestructive;
        UIAction *hidden = [UIAction actionWithTitle:@"Hidden" image:nil identifier:nil handler:^(UIAction *action) { [self.log addObject:@"hidden"]; }];
        hidden.attributes = UIMenuElementAttributesHidden;
        return [UIMenu menuWithTitle:@"Actions" children:@[copy, hidden, remove]];
    }];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.log addObject:@"willDisplay"];
    [animator addAnimations:^{ [self.log addObject:@"animations"]; }];
    [animator addCompletion:^{ [self.log addObject:@"displayed"]; }];
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator
{
    [self.log addObject:@"willEnd"];
}

@end

@interface CharonContextMenuDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) CharonMenuHost *host;
@end

@implementation CharonContextMenuDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"contextmenu.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.host = [[CharonMenuHost alloc] init];
    self.host.log = [NSMutableArray array];
    self.window.rootViewController = self.host;
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"contextmenu.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)run
{
    Dl_info info;
    CHECK(dladdr((__bridge const void *)[UIContextMenuInteraction class], &info) && !strcmp(strrchr(info.dli_fname, '/') + 1, "libUIKitBackports.dylib"), "UIContextMenuInteraction comes from the backports library");
    UIView *view = self.host.view;
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:self.host];
    self.host.interaction = interaction;
    [view addInteraction:interaction];
    CHECK(interaction.view == view && interaction.delegate == self.host, "an interaction added to a view knows its view and delegate");
    CHECK([interaction locationInView:view].x >= 0, "and can answer a location");
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(interaction, NSSelectorFromString(@"charon_beginAtLocation:"), CGPointMake(50, 50));
    CHECK(wait_until(^BOOL { return visible_sheet() != nil; }, 10), "a menu is shown as an action sheet");
    UIActionSheet *sheet = visible_sheet();
    NSMutableArray *titles = [NSMutableArray array];
    for (NSInteger i = 0; i < sheet.numberOfButtons; i++)
        [titles addObject:[sheet buttonTitleAtIndex:i]];
    CHECK([titles containsObject:@"Copy"] && [titles containsObject:@"Delete"] && ![titles containsObject:@"Hidden"], "it holds the visible actions and omits the hidden one");
    CHECK(sheet.destructiveButtonIndex >= 0 && [[sheet buttonTitleAtIndex:sheet.destructiveButtonIndex] isEqual:@"Delete"], "the destructive action is the destructive button");
    CHECK([self.host.log containsObject:@"configuration"] && [self.host.log containsObject:@"willDisplay"], "the delegate was asked for the configuration and told the menu will display");
    CHECK(wait_until(^BOOL { return [self.host.log containsObject:@"displayed"]; }, 5) && [self.host.log containsObject:@"animations"], "the animator ran its animations and completions");
    NSInteger copyIndex = [titles indexOfObject:@"Copy"];
    [sheet dismissWithClickedButtonIndex:copyIndex animated:NO];
    CHECK(wait_until(^BOOL { return [self.host.log containsObject:@"copy"]; }, 5), "choosing a button runs the action's handler");
    CHECK(wait_until(^BOOL { return [self.host.log containsObject:@"willEnd"]; }, 5), "and the delegate is told the menu ends");
    CHECK(wait_until(^BOOL { return visible_sheet() == nil; }, 5), "the sheet is gone");
    CHECK(![self.host.log containsObject:@"delete"] && ![self.host.log containsObject:@"hidden"], "no other handler ran");
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonContextMenuDelegate");
    }
}
