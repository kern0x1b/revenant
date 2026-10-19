#import <UIKit/UIKit.h>

static NSObject *revenant_delegate;
static UIPrinterPickerController *revenant_picker;
static int revenant_completions;

@interface RevenantPickerDelegate : NSObject <UIPrinterPickerControllerDelegate>
@end

@implementation RevenantPickerDelegate

- (void)printerPickerControllerWillPresent:(UIPrinterPickerController *)picker
{
    printf("delegate: will present\n");
    fflush(stdout);
}

- (void)printerPickerControllerDidPresent:(UIPrinterPickerController *)picker
{
    printf("delegate: did present\n");
    fflush(stdout);
}

- (void)printerPickerControllerWillDismiss:(UIPrinterPickerController *)picker
{
    printf("delegate: will dismiss\n");
    fflush(stdout);
}

- (void)printerPickerControllerDidDismiss:(UIPrinterPickerController *)picker
{
    printf("delegate: did dismiss\n");
    fflush(stdout);
}

- (void)printerPickerControllerDidSelectPrinter:(UIPrinterPickerController *)picker
{
    printf("delegate: did select printer\n");
    fflush(stdout);
}

@end

@interface RevenantBareBrowser : NSObject <NSNetServiceBrowserDelegate>
@end

@implementation RevenantBareBrowser

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    printf("bare browse: will search\n");
    fflush(stdout);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict
{
    printf("bare browse: did not search, %s\n", [[errorDict description] UTF8String]);
    fflush(stdout);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)more
{
    printf("bare browse: found %s\n", service.name.UTF8String);
    fflush(stdout);
}

@end

static RevenantBareBrowser *revenant_bare;
static NSNetServiceBrowser *revenant_browser;

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
- (void)revenant_present;
- (void)revenant_presentPicker;
- (void)revenant_finish;
- (void)revenant_deadline;
@end

@implementation RevenantAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    printf("window: key %s, root %s\n", self.window.isKeyWindow ? "YES" : "NO", NSStringFromClass([root class]).UTF8String);
    fflush(stdout);
    [self performSelector:@selector(revenant_present) withObject:nil afterDelay:2];
    return YES;
}

- (void)revenant_present
{
    revenant_bare = [[RevenantBareBrowser alloc] init];
    revenant_browser = [[NSNetServiceBrowser alloc] init];
    revenant_browser.delegate = revenant_bare;
    [revenant_browser searchForServicesOfType:@"_universal._sub._ipp._tcp." inDomain:@"local."];
    [self performSelector:@selector(revenant_presentPicker) withObject:nil afterDelay:3];
}

- (void)revenant_presentPicker
{
    [revenant_browser stop];
    revenant_delegate = [[RevenantPickerDelegate alloc] init];
    revenant_picker = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:nil];
    revenant_picker.delegate = (id<UIPrinterPickerControllerDelegate>)revenant_delegate;
    printf("picker: class %s, selectedPrinter %s\n", NSStringFromClass([revenant_picker class]).UTF8String,
           revenant_picker.selectedPrinter ? "present" : "nil");
    fflush(stdout);
    BOOL presented = [revenant_picker presentAnimated:YES completionHandler:^(UIPrinterPickerController *picker, BOOL userDidSelect, NSError *error) {
        revenant_completions++;
        printf("completion %d: userDidSelect %s, error %s\n", revenant_completions, userDidSelect ? "YES" : "NO",
               error ? error.description.UTF8String : "nil");
        fflush(stdout);
        [self performSelector:@selector(revenant_finish) withObject:nil afterDelay:2];
    }];
    printf("present: %s\n", presented ? "YES" : "NO");
    fflush(stdout);
    if (!presented) {
        exit(2);
    }
    [self performSelector:@selector(revenant_deadline) withObject:nil afterDelay:60];
}

- (void)revenant_finish
{
    printf("finished: %d completion(s)\n", revenant_completions);
    fflush(stdout);
    exit(revenant_completions == 1 ? 0 : 1);
}

- (void)revenant_deadline
{
    printf("deadline: the picker completed %d time(s) in 60 s; no tap reached Cancel\n", revenant_completions);
    fflush(stdout);
    exit(3);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantAppDelegate class]));
    }
}
