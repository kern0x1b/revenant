//
//  app/main.m
//  The Bonjour printer picker (UIPrinterPickerController, libUIKitBackports) as an application on the emulated iPhone 4S at
//  6.1.3. The application starts a bare NSNetServiceBrowser as a control, then presents the picker over its key window. What
//  the emulator can show: the presentation, and the completion when the browse fails. What it cannot: a list. On this guest
//  the browse reports "did not search" (NSNetServicesErrorDomain -72004) for the bare browser as well as for the picker, so
//  the picker dismisses with userDidSelect NO before any list is shown, and the empty-list case is not measured here. The
//  application's standard output is the verdict; run-app.sh reads it.
//

#import <UIKit/UIKit.h>

static NSObject *charon_delegate;
static UIPrinterPickerController *charon_picker;
static int charon_completions;

// The delegate's calls are printed in the order the picker makes them, so the run's order can be read off the log.
@interface CharonPickerDelegate : NSObject <UIPrinterPickerControllerDelegate>
@end

@implementation CharonPickerDelegate

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

// A browse made with no picker: the control for the picker's own browse. If the release's Bonjour cannot browse in the
// guest, this one reports it too, and the picker's failure is the guest's and not the port's.
@interface CharonBareBrowser : NSObject <NSNetServiceBrowserDelegate>
@end

@implementation CharonBareBrowser

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

static CharonBareBrowser *charon_bare;
static NSNetServiceBrowser *charon_browser;

@interface CharonAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
- (void)charon_present;
- (void)charon_presentPicker;
- (void)charon_finish;
- (void)charon_deadline;
@end

@implementation CharonAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    printf("window: key %s, root %s\n", self.window.isKeyWindow ? "YES" : "NO", NSStringFromClass([root class]).UTF8String);
    fflush(stdout);
    [self performSelector:@selector(charon_present) withObject:nil afterDelay:2];
    return YES;
}

- (void)charon_present
{
    charon_bare = [[CharonBareBrowser alloc] init];
    charon_browser = [[NSNetServiceBrowser alloc] init];
    charon_browser.delegate = charon_bare;
    [charon_browser searchForServicesOfType:@"_universal._sub._ipp._tcp." inDomain:@"local."];
    [self performSelector:@selector(charon_presentPicker) withObject:nil afterDelay:3];
}

- (void)charon_presentPicker
{
    [charon_browser stop];
    charon_delegate = [[CharonPickerDelegate alloc] init];
    charon_picker = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:nil];
    charon_picker.delegate = (id<UIPrinterPickerControllerDelegate>)charon_delegate;
    printf("picker: class %s, selectedPrinter %s\n", NSStringFromClass([charon_picker class]).UTF8String,
           charon_picker.selectedPrinter ? "present" : "nil");
    fflush(stdout);
    BOOL presented = [charon_picker presentAnimated:YES completionHandler:^(UIPrinterPickerController *picker, BOOL userDidSelect, NSError *error) {
        charon_completions++;
        printf("completion %d: userDidSelect %s, error %s\n", charon_completions, userDidSelect ? "YES" : "NO",
               error ? error.description.UTF8String : "nil");
        fflush(stdout);
        [self performSelector:@selector(charon_finish) withObject:nil afterDelay:2];
    }];
    printf("present: %s\n", presented ? "YES" : "NO");
    fflush(stdout);
    if (!presented) {
        exit(2);
    }
    [self performSelector:@selector(charon_deadline) withObject:nil afterDelay:60];
}

- (void)charon_finish
{
    printf("finished: %d completion(s)\n", charon_completions);
    fflush(stdout);
    exit(charon_completions == 1 ? 0 : 1);
}

- (void)charon_deadline
{
    printf("deadline: the picker completed %d time(s) in 60 s; no tap reached Cancel\n", charon_completions);
    fflush(stdout);
    exit(3);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonAppDelegate class]));
    }
}
