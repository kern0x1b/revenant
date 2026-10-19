#import <UIKit/UIKit.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";
static NSString *const fixture = @"/private/var/backports/docpick";
static UIWindow *the_window;

@interface PickLog : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) NSArray *urls;
@end

@implementation PickLog
- (instancetype)init
{
    if ((self = [super init]))
        _events = [NSMutableArray array];
    return self;
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    self.urls = urls;
    [_events addObject:@"picked"];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [_events addObject:@"cancelled"];
}
@end

@interface SingleLog : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSURL *url;
@end

@implementation SingleLog
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    self.url = url;
}
@end

@interface UIDocumentPickerViewController (CharonProbe)
- (void)charon_cancel;
@end

static UIDocumentPickerViewController *current;
static UIViewController *top_page(void)
{
    UINavigationController *navigation = current.childViewControllers.firstObject;
    return navigation.topViewController;
}

static UITableView *table(void)
{
    UIViewController *page = top_page();
    return [page isKindOfClass:[UITableViewController class]] ? [(UITableViewController *)page tableView] : nil;
}

static NSArray *row_titles(void)
{
    UITableView *view = table();
    [view layoutIfNeeded];
    NSMutableArray *titles = [NSMutableArray array];
    for (NSInteger row = 0; row < [view numberOfRowsInSection:0]; row++)
        [titles addObject:[view cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]].textLabel.text ?: @"?"];
    return titles;
}

static CGPoint row_point(NSString *title)
{
    UITableView *view = table();
    NSArray *titles = row_titles();
    NSUInteger row = [titles indexOfObject:title];
    if (row == NSNotFound)
        return CGPointMake(-1, -1);
    CGRect rect = [view convertRect:[view rectForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]] toView:nil];
    return CGPointMake(CGRectGetMidX(rect) - 40, CGRectGetMidY(rect));
}

static CGPoint item_point(UIBarButtonItem *item)
{
    UIView *view = [item valueForKey:@"view"];
    CGRect rect = [view convertRect:view.bounds toView:nil];
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static NSString *checked_title(void)
{
    return top_page().title ?: @"";
}

static void present(UIDocumentPickerViewController *picker, id delegate)
{
    picker.delegate = delegate;
    gesture_step(0.1, ^{ current = picker; [the_window.rootViewController presentViewController:picker animated:NO completion:nil]; });
    gesture_step(2.0, ^{});
}

static void reset_fixture(void)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtPath:fixture error:NULL];
    [manager createDirectoryAtPath:[fixture stringByAppendingPathComponent:@"sub"] withIntermediateDirectories:YES attributes:nil error:NULL];
    [manager createDirectoryAtPath:[fixture stringByAppendingPathComponent:@"dest"] withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"alpha" writeToFile:[fixture stringByAppendingPathComponent:@"a.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"charlie" writeToFile:[fixture stringByAppendingPathComponent:@"c.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"beta" writeToFile:[fixture stringByAppendingPathComponent:@"b.png"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"hidden" writeToFile:[fixture stringByAppendingPathComponent:@".secret"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"inner" writeToFile:[fixture stringByAppendingPathComponent:@"sub/inner.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static PickLog *open_log;
static PickLog *import_log;
static PickLog *cancel_log;
static PickLog *export_log;
static PickLog *move_log;
static SingleLog *single_log;

static void open_scenario(void)
{
    open_log = [[PickLog alloc] init];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.text"] inMode:UIDocumentPickerModeOpen];
    picker.directoryURL = [NSURL fileURLWithPath:fixture];
    present(picker, open_log);
    gesture_step(0.1, ^{
        CHECK(current.presentingViewController != nil && current.childViewControllers.count == 1, "the picker is presented with a navigation controller inside");
        CHECK([top_page() isKindOfClass:[UITableViewController class]], "it opens on a folder listing");
        CHECK_EQUAL(checked_title(), @"docpick", "the folder's name is the title");
        CHECK_EQUAL(row_titles(), (@[@"dest", @"sub", @"a", @"b", @"c"]), "folders come first, then files by name, hidden files left out, extensions hidden");
        CHECK(((UINavigationController *)current.childViewControllers.firstObject).viewControllers.count >= 2, "the way back to the locations is on the navigation stack");
    });
    gesture_tap(^{ return row_point(@"b"); }, 0.5);
    gesture_step(0.1, ^{
        CHECK(open_log.events.count == 0 && current.presentingViewController != nil, "tapping a file of another type does nothing");
    });
    gesture_tap(^{ return row_point(@"sub"); }, 1.0);
    gesture_step(0.1, ^{
        CHECK_EQUAL(checked_title(), @"sub", "tapping a folder goes into it");
        CHECK_EQUAL(row_titles(), (@[@"inner"]), "and lists what is in it");
    });
    gesture_tap(^{ return row_point(@"inner"); }, 1.2);
    gesture_step(0.1, ^{
        CHECK_EQUAL(open_log.events, (@[@"picked"]), "choosing a file tells the delegate once");
        CHECK(open_log.urls.count == 1 && [[open_log.urls[0] path] isEqualToString:[fixture stringByAppendingPathComponent:@"sub/inner.txt"]], "with the file's own URL");
        CHECK(current.presentingViewController == nil, "and the picker is gone");
        CHECK([open_log.urls[0] startAccessingSecurityScopedResource], "the URL can be accessed as a scoped one");
        [open_log.urls[0] stopAccessingSecurityScopedResource];
    });
}

static void locations_scenario(void)
{
    single_log = [[SingleLog alloc] init];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
    present(picker, single_log);
    gesture_step(0.1, ^{
        CHECK_EQUAL(checked_title(), @"Locations", "without a directory the picker opens on the locations");
        CHECK_EQUAL(row_titles().firstObject, @"On My Device", "the first is the application's own home");
    });
    gesture_tap(^{ return row_point(@"On My Device"); }, 1.0);
    gesture_step(0.1, ^{
        CHECK([top_page() isKindOfClass:[UITableViewController class]] && ![checked_title() isEqual:@"Locations"] && row_titles().count > 0, "a location opens on its folders");
        UINavigationController *navigation = current.childViewControllers.firstObject;
        [navigation popToRootViewControllerAnimated:NO];
    });
    gesture_step(0.5, ^{ [current charon_cancel]; });
    gesture_step(1.0, ^{
        CHECK(current.presentingViewController == nil, "cancelling from the locations dismisses it");
    });
}

static void multiple_scenario(void)
{
    import_log = [[PickLog alloc] init];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.text"] inMode:UIDocumentPickerModeImport];
    picker.directoryURL = [NSURL fileURLWithPath:fixture];
    picker.allowsMultipleSelection = YES;
    picker.shouldShowFileExtensions = YES;
    present(picker, import_log);
    gesture_step(0.1, ^{
        CHECK_EQUAL(row_titles(), (@[@"dest", @"sub", @"a.txt", @"b.png", @"c.txt"]), "extensions show when asked for");
        CHECK(top_page().navigationItem.rightBarButtonItem.enabled == NO, "Done waits for a selection");
    });
    gesture_tap(^{ return row_point(@"c.txt"); }, 0.5);
    gesture_step(0.1, ^{
        CHECK(top_page().navigationItem.rightBarButtonItem.enabled, "a chosen file enables Done");
        UITableViewCell *cell = [table() cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:0]];
        CHECK(cell.accessoryType == UITableViewCellAccessoryCheckmark, "and is ticked");
    });
    gesture_tap(^{ return row_point(@"a.txt"); }, 0.5);
    gesture_tap(^{ return item_point(top_page().navigationItem.rightBarButtonItem); }, 1.2);
    gesture_step(0.1, ^{
        CHECK_EQUAL(import_log.events, (@[@"picked"]), "Done tells the delegate once");
        NSArray *names = [import_log.urls valueForKey:@"lastPathComponent"];
        CHECK_EQUAL(names, (@[@"c.txt", @"a.txt"]), "with both files in the order chosen");
        NSURL *copy = import_log.urls.firstObject;
        CHECK(![copy.path hasPrefix:fixture] && [[NSString stringWithContentsOfURL:copy encoding:NSUTF8StringEncoding error:NULL] isEqualToString:@"charlie"], "import gives copies with the content");
        CHECK(current.presentingViewController == nil, "and the picker is gone");
    });
}

static void cancel_scenario(void)
{
    cancel_log = [[PickLog alloc] init];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
    picker.directoryURL = [NSURL fileURLWithPath:fixture];
    present(picker, cancel_log);
    gesture_tap(^{ return item_point(top_page().navigationItem.rightBarButtonItem); }, 1.2);
    gesture_step(0.1, ^{
        CHECK_EQUAL(cancel_log.events, (@[@"cancelled"]), "Cancel tells the delegate it was cancelled");
        CHECK(current.presentingViewController == nil, "and the picker is gone");
    });
}

static void export_scenario(void)
{
    export_log = [[PickLog alloc] init];
    NSURL *source = [NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:@"a.txt"]];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithURL:source inMode:UIDocumentPickerModeExportToService];
    picker.directoryURL = [NSURL fileURLWithPath:fixture];
    present(picker, export_log);
    gesture_step(0.1, ^{
        CHECK_EQUAL(row_titles(), (@[@"dest", @"sub", @"a", @"b", @"c"]), "a folder browser for export lists every file");
        CHECK_EQUAL(top_page().navigationItem.rightBarButtonItem.title, @"Copy", "and offers Copy");
    });
    gesture_tap(^{ return row_point(@"dest"); }, 1.0);
    gesture_tap(^{ return item_point(top_page().navigationItem.rightBarButtonItem); }, 1.2);
    gesture_step(0.1, ^{
        NSString *placed = [fixture stringByAppendingPathComponent:@"dest/a.txt"];
        CHECK_EQUAL(export_log.events, (@[@"picked"]), "Copy tells the delegate");
        CHECK([[export_log.urls.firstObject path] isEqualToString:placed], "with the URL of the copy");
        CHECK([[NSFileManager defaultManager] fileExistsAtPath:placed] && [[NSFileManager defaultManager] fileExistsAtPath:source.path], "the copy is there and the original stays");
    });
}

static void move_scenario(void)
{
    move_log = [[PickLog alloc] init];
    NSURL *source = [NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:@"b.png"]];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithURL:source inMode:UIDocumentPickerModeMoveToService];
    picker.directoryURL = [NSURL fileURLWithPath:[fixture stringByAppendingPathComponent:@"sub"]];
    present(picker, move_log);
    gesture_step(0.1, ^{
        CHECK_EQUAL(top_page().navigationItem.rightBarButtonItem.title, @"Move", "move offers Move");
    });
    gesture_tap(^{ return item_point(top_page().navigationItem.rightBarButtonItem); }, 1.2);
    gesture_step(0.1, ^{
        NSString *placed = [fixture stringByAppendingPathComponent:@"sub/b.png"];
        CHECK([[move_log.urls.firstObject path] isEqualToString:placed], "Move answers the new URL");
        CHECK([[NSFileManager defaultManager] fileExistsAtPath:placed] && ![[NSFileManager defaultManager] fileExistsAtPath:source.path], "and the file has left where it was");
    });
}

static void single_scenario(void)
{
    single_log = [[SingleLog alloc] init];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
    picker.directoryURL = [NSURL fileURLWithPath:fixture];
    present(picker, single_log);
    gesture_tap(^{ return row_point(@"c"); }, 1.2);
    gesture_step(0.1, ^{
        CHECK([single_log.url.path isEqualToString:[fixture stringByAppendingPathComponent:@"c.txt"]], "a delegate with only the singular method gets the singular callback");
    });
}

@interface DocDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation DocDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"documentpicker.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"documentpicker.log"]);
    reset_fixture();
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    the_window = self.window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent to the application through the HID event system"); });
        open_scenario();
        locations_scenario();
        multiple_scenario();
        cancel_scenario();
        export_scenario();
        move_scenario();
        single_scenario();
        gesture_run(^{
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"documentpicker.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DocDelegate class]));
    }
}
