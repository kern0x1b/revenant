#import <UIKit/UIKit.h>
#import "check.h"
#import "documentmenu-cases.h"
#import "documentmenu-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface DocumentMenuDelegate : UIResponder <UIApplicationDelegate, UIDocumentMenuDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) UIDocumentPickerViewController *picked;
@property (nonatomic, strong) UIWindow *window;
@end

@implementation DocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    [self.events addObject:@"picked"];
    self.picked = documentPicker;
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu
{
    [self.events addObject:@"cancelled"];
}

static UIActionSheet *find_sheet(UIView *view)
{
    if ([view isKindOfClass:[UIActionSheet class]])
        return (UIActionSheet *)view;
    for (UIView *child in view.subviews) {
        UIActionSheet *found = find_sheet(child);
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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"documentmenu.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"documentmenu.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:documentmenu_expectations length:strlen(documentmenu_expectations)] options:0 error:NULL];
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        documentmenu_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("record %s: %s\n", name.UTF8String, value.UTF8String);
        });
        for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if ([expected[name] isEqualToString:records[name]] )
                charon_check(YES, name.UTF8String, nil);
            else
                charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    host   %@", records[name], expected[name]]);
        }
        self.events = [NSMutableArray array];
        UIViewController *root = self.window.rootViewController;
        UIView *anchor = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 100, 40)];
        [root.view addSubview:anchor];
        void (^show)(UIDocumentMenuViewController *) = ^(UIDocumentMenuViewController *menu) {
            menu.delegate = self;
            menu.popoverPresentationController.sourceView = anchor;
            [root presentViewController:menu animated:NO completion:nil];
        };
        NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-menu.txt"];
        [@"menu" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        __block BOOL first = NO, last = NO;
        UIDocumentMenuViewController *menu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
        [menu addOptionWithTitle:@"Last option" image:nil order:UIDocumentMenuOrderLast handler:^{ last = YES; }];
        [menu addOptionWithTitle:@"First option" image:nil order:UIDocumentMenuOrderFirst handler:^{ first = YES; }];
        show(menu);
        UIActionSheet *sheet = visible_sheet();
        CHECK(sheet != nil, "the menu is shown");
        NSMutableArray *titles = [NSMutableArray array];
        for (NSInteger index = 0; index < sheet.numberOfButtons; index++)
            [titles addObject:[sheet buttonTitleAtIndex:index]];
        charon_check([titles isEqual:@[@"First option", @"Browse", @"Last option", @"Cancel"]], "with the options the application added around the way to the picker, and Cancel last", titles.description);
        printf("titles %s\n", titles.description.UTF8String);
        [sheet dismissWithClickedButtonIndex:[titles indexOfObject:@"First option"] animated:NO];
        CHECK(first && !last && self.events.count == 0, "a chosen option of the application runs its handler and tells the delegate nothing");
        show(menu);
        sheet = visible_sheet();
        [sheet dismissWithClickedButtonIndex:[titles indexOfObject:@"Browse"] animated:NO];
        charon_check([self.events isEqual:@[@"picked"]], "the way to the picker answers the delegate with a picker", self.events.description);
        CHECK([self.picked isKindOfClass:[UIDocumentPickerViewController class]] && self.picked.documentPickerMode == UIDocumentPickerModeImport, "made for the mode of the menu");
        show(menu);
        sheet = visible_sheet();
        [sheet dismissWithClickedButtonIndex:sheet.cancelButtonIndex animated:NO];
        charon_check([self.events isEqual:@[@"picked", @"cancelled"]], "and Cancel tells the delegate that the menu was cancelled", self.events.description);
        UIDocumentMenuViewController *export = [[UIDocumentMenuViewController alloc] initWithURL:[NSURL fileURLWithPath:file] inMode:UIDocumentPickerModeExportToService];
        [self.events removeAllObjects];
        show(export);
        sheet = visible_sheet();
        [sheet dismissWithClickedButtonIndex:0 animated:NO];
        charon_check([self.events isEqual:@[@"picked"]] && self.picked.documentPickerMode == UIDocumentPickerModeExportToService, "a menu for export answers a picker for export", self.events.description);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"documentmenu.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DocumentMenuDelegate class]));
    }
}
