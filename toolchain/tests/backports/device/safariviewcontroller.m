#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const results_folder = @"/private/var/backports";
static uint16_t server_port;

static void after(double seconds, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

static void serve_client(int client)
{
    char buffer[2048];
    ssize_t count = read(client, buffer, sizeof buffer - 1);
    if (count <= 0) {
        close(client);
        return;
    }
    buffer[count] = 0;
    char path[256] = "/";
    sscanf(buffer, "GET %255s", path);
    NSString *response;
    if (!strcmp(path, "/oauth"))
        response = @"HTTP/1.1 302 Found\r\nLocation: myapp://cb?code=42\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    else if (!strcmp(path, "/redirect"))
        response = @"HTTP/1.1 302 Found\r\nLocation: /page\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    else {
        NSString *body = !strcmp(path, "/second") ? @"<html><head><title>Second Page</title></head><body><h1>Second</h1></body></html>"
                                                  : @"<html><head><title>Hello Page</title><meta name=\"viewport\" content=\"width=device-width\"></head><body style=\"font-family:Helvetica\"><h1>Hello Page</h1><p><a href=\"/second\">second</a></p></body></html>";
        response = [NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n%@", (unsigned long)[body lengthOfBytesUsingEncoding:NSUTF8StringEncoding], body];
    }
    const char *bytes = response.UTF8String;
    write(client, bytes, strlen(bytes));
    close(client);
}

static void start_server(void)
{
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    int yes = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);
    struct sockaddr_in address = {0};
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    bind(listener, (struct sockaddr *)&address, sizeof address);
    socklen_t length = sizeof address;
    getsockname(listener, (struct sockaddr *)&address, &length);
    server_port = ntohs(address.sin_port);
    listen(listener, 8);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (;;) {
            int client = accept(listener, NULL, NULL);
            if (client >= 0)
                serve_client(client);
        }
    });
}

static NSURL *local(NSString *path)
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d%@", server_port, path]];
}

@interface SafariRecorder : NSObject <SFSafariViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic, weak) UIViewController *presenter;
@end

@implementation SafariRecorder
- (instancetype)init
{
    if ((self = [super init]))
        _log = [NSMutableArray array];
    return self;
}
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"finish presented=%d", controller.presentingViewController != nil]];
}
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)success
{
    [self.log addObject:[NSString stringWithFormat:@"initial %d", success]];
}
- (void)safariViewController:(SFSafariViewController *)controller initialLoadDidRedirectToURL:(NSURL *)URL
{
    [self.log addObject:[NSString stringWithFormat:@"redirect %@", URL.path]];
}
- (NSArray *)safariViewController:(SFSafariViewController *)controller activityItemsForURL:(NSURL *)URL title:(NSString *)title
{
    [self.log addObject:[NSString stringWithFormat:@"activities %@ %@", URL.path, title]];
    return nil;
}
- (NSArray *)safariViewController:(SFSafariViewController *)controller excludedActivityTypesForURL:(NSURL *)URL title:(NSString *)title
{
    [self.log addObject:@"excluded"];
    return @[UIActivityTypePostToWeibo];
}
@end

static UIWebView *find_web_view(UIView *view)
{
    if ([view isKindOfClass:[UIWebView class]])
        return (UIWebView *)view;
    for (UIView *child in view.subviews) {
        UIWebView *found = find_web_view(child);
        if (found)
            return found;
    }
    return nil;
}

static UINavigationBar *find_navigation_bar(UIView *view)
{
    if ([view isKindOfClass:[UINavigationBar class]])
        return (UINavigationBar *)view;
    for (UIView *child in view.subviews) {
        UINavigationBar *found = find_navigation_bar(child);
        if (found)
            return found;
    }
    return nil;
}

static UIBarButtonItem *left_item(UIViewController *controller)
{
    return find_navigation_bar(controller.view).topItem.leftBarButtonItem;
}

static void screenshot(UIWindow *window, NSString *name)
{
    UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 1);
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [UIImagePNGRepresentation(image) writeToFile:[results_folder stringByAppendingPathComponent:name] atomically:YES];
}

static UIViewController *topmost(UIViewController *controller)
{
    while (controller.presentedViewController)
        controller = controller.presentedViewController;
    return controller;
}

typedef void (^Step)(void (^done)(void));

@interface SafariTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *root;
@end

@implementation SafariTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"safariviewcontroller.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"safariviewcontroller.log"]);
    start_server();
    self.root = [[UIViewController alloc] init];
    self.root.view.backgroundColor = [UIColor lightGrayColor];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = self.root;
    [self.window makeKeyAndVisible];
    NSArray *steps = [self steps];
    after(1, ^{
        [self run:steps index:0];
    });
    return YES;
}

- (void)run:(NSArray *)steps index:(NSUInteger)index
{
    if (index == steps.count) {
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        after(1, ^{
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"safariviewcontroller.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
        return;
    }
    printf("step %lu\n", (unsigned long)index + 1);
    __block BOOL finished = NO;
    void (^done)(void) = ^{
        if (finished)
            return;
        finished = YES;
        after(1, ^{
            [self run:steps index:index + 1];
        });
    };
    after(40, ^{
        if (!finished) {
            charon_check(NO, "step finishes in time", [NSString stringWithFormat:@"step %lu timed out", (unsigned long)index + 1]);
            done();
        }
    });
    Step step = [steps objectAtIndex:index];
    step(done);
}

- (NSArray *)steps
{
    UIViewController *root = self.root;
    UIWindow *window = self.window;
    return @[
        [^(void (^done)(void)) {
            SafariRecorder *recorder = [[SafariRecorder alloc] init];
            SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:local(@"/page")];
            controller.delegate = recorder;
            CHECK(!controller.isViewLoaded && recorder.log.count == 0, "nothing loads before the controller is shown");
            [root presentViewController:controller animated:NO completion:nil];
            after(4, ^{
                CHECK(controller.isViewLoaded && controller.presentingViewController == root, "the controller is presented");
                UIWebView *web = find_web_view(controller.view);
                CHECK_EQUAL([web stringByEvaluatingJavaScriptFromString:@"document.title"], @"Hello Page", "the page is shown");
                CHECK_EQUAL(recorder.log, (@[@"initial 1"]), "the initial load completes once, with success");
                screenshot(window, @"safari-page.png");
                CHECK(left_item(controller) != nil, "the bar has a button to dismiss with");
                [web stringByEvaluatingJavaScriptFromString:@"location.href='/second'"];
                after(3, ^{
                    CHECK_EQUAL([web stringByEvaluatingJavaScriptFromString:@"document.title"], @"Second Page", "a script can move the page on");
                    CHECK_EQUAL(recorder.log, (@[@"initial 1", @"redirect /second"]), "a move nobody asked for is reported as a redirect, and a completed load is not reported twice");
                    UIBarButtonItem *item = left_item(controller);
                    [item.target performSelector:item.action withObject:item];
                    after(2, ^{
                        CHECK(controller.presentingViewController == nil && root.presentedViewController == nil, "the done button dismisses the controller");
                        CHECK_EQUAL(recorder.log.lastObject, @"finish presented=0", "and then tells the delegate, once");
                        CHECK_EQUAL(@([recorder.log filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'finish'"]].count), @1, "only once");
                        done();
                    });
                });
            });
        } copy],
        [^(void (^done)(void)) {
            SafariRecorder *recorder = [[SafariRecorder alloc] init];
            SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:local(@"/redirect")];
            controller.delegate = recorder;
            [root presentViewController:controller animated:NO completion:nil];
            after(4, ^{
                CHECK_EQUAL(recorder.log, (@[@"redirect /page", @"initial 1"]), "a redirect of the initial load is reported before the load completes");
                UIWebView *web = find_web_view(controller.view);
                CHECK_EQUAL([web stringByEvaluatingJavaScriptFromString:@"document.title"], @"Hello Page", "and lands on the page");
                [controller dismissViewControllerAnimated:NO completion:nil];
                after(1, ^{
                    CHECK(recorder.log.count == 2, "dismissing it from the application does not tell the delegate it finished");
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            SafariRecorder *recorder = [[SafariRecorder alloc] init];
            SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/nothing"]];
            controller.delegate = recorder;
            controller.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleCancel;
            controller.preferredBarTintColor = [UIColor darkGrayColor];
            [root presentViewController:controller animated:NO completion:nil];
            after(5, ^{
                CHECK_EQUAL(recorder.log, (@[@"initial 0"]), "a page that cannot be reached completes the initial load with failure");
                CHECK(left_item(controller).style == UIBarButtonItemStyleBordered || left_item(controller) != nil, "the dismiss button follows the style asked for");
                screenshot(window, @"safari-failure.png");
                [controller dismissViewControllerAnimated:NO completion:nil];
                after(1, done);
            });
        } copy],
        [^(void (^done)(void)) {
            SafariRecorder *recorder = [[SafariRecorder alloc] init];
            SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:local(@"/page")];
            controller.delegate = recorder;
            [root presentViewController:controller animated:NO completion:nil];
            after(4, ^{
                [controller.childViewControllers.firstObject performSelector:NSSelectorFromString(@"charon_action:") withObject:nil];
                after(2, ^{
                    CHECK_EQUAL([recorder.log subarrayWithRange:NSMakeRange(1, recorder.log.count - 1)], (@[@"activities /page Hello Page", @"excluded"]), "the action button asks the delegate for activities and exclusions, with the page's URL and title");
                    CHECK(controller.presentedViewController != nil || UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad, "and shows the sheet");
                    screenshot(window, @"safari-action.png");
                    [controller dismissViewControllerAnimated:NO completion:nil];
                    after(1, ^{
                        [root dismissViewControllerAnimated:NO completion:nil];
                        after(1, done);
                    });
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            SFAuthenticationSession *session = [[SFAuthenticationSession alloc] initWithURL:local(@"/oauth") callbackURLScheme:@"myapp" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@ %@ presented=%d", URL.absoluteString ?: @"nil", error ? [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code] : @"noerror", root.presentedViewController != nil]];
            }];
            CHECK([session start], "a session starts");
            CHECK(![session start], "and does not start twice while it runs");
            after(5, ^{
                CHECK_EQUAL(log, (@[@"myapp://cb?code=42 noerror presented=0"]), "a redirect to the callback scheme ends the session with the callback URL, after the page is dismissed, once");
                after(2, ^{
                    CHECK(root.presentedViewController == nil, "and the page is gone");
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            SFAuthenticationSession *session = [[SFAuthenticationSession alloc] initWithURL:local(@"/page") callbackURLScheme:@"myapp" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@ %@/%ld", URL.absoluteString ?: @"nil", error.domain, (long)error.code]];
            }];
            [session start];
            after(4, ^{
                UIViewController *shown = topmost(root);
                CHECK(shown != root && find_web_view(shown.view) != nil && log.count == 0, "the login page is shown and the session waits");
                UIWebView *web = find_web_view(shown.view);
                [web stringByEvaluatingJavaScriptFromString:@"location.href='other://x'"];
                after(1, ^{
                    CHECK(log.count == 0, "a scheme that is not the callback's does not end it");
                    [web stringByEvaluatingJavaScriptFromString:@"location.href='MYAPP://Later?a=1'"];
                    after(3, ^{
                        CHECK_EQUAL(log, (@[@"myapp://Later?a=1 (null)/0"]), "a callback scheme in any case is taken, and the URL is handed over as the web view has it, with the scheme in lower case");
                        done();
                    });
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            SFAuthenticationSession *session = [[SFAuthenticationSession alloc] initWithURL:local(@"/page") callbackURLScheme:@"myapp" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@ %@/%ld presented=%d", URL ? @"url" : @"nil", error.domain, (long)error.code, root.presentedViewController != nil]];
            }];
            [session start];
            after(4, ^{
                UIViewController *shown = topmost(root);
                UIBarButtonItem *item = left_item(shown);
                CHECK(item != nil, "the cancel button is there");
                [item.target performSelector:item.action withObject:item];
                after(3, ^{
                    CHECK_EQUAL(log, (@[@"nil com.apple.SafariServices.Authentication/1 presented=0"]), "cancelling ends the session with the canceled-login error, after the page is dismissed");
                    CHECK([session start], "a session that has ended can be started again");
                    after(4, ^{
                        [session cancel];
                        after(3, ^{
                            CHECK_EQUAL(@(log.count), @2, "and cancel from the application ends it with the same error");
                            CHECK(root.presentedViewController == nil, "and dismisses the page");
                            done();
                        });
                    });
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            SFAuthenticationSession *first = [[SFAuthenticationSession alloc] initWithURL:local(@"/page") callbackURLScheme:@"a" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"first %ld", (long)error.code]];
            }];
            [first start];
            after(3, ^{
                SFAuthenticationSession *second = [[SFAuthenticationSession alloc] initWithURL:local(@"/second") callbackURLScheme:@"b" completionHandler:^(NSURL *URL, NSError *error) {
                    [log addObject:@"second"];
                }];
                [second start];
                after(4, ^{
                    CHECK_EQUAL(log, (@[@"first 1"]), "starting a session ends the one that was showing");
                    [second cancel];
                    after(3, ^{
                        CHECK_EQUAL(@(root.presentedViewController != nil), @NO, "and the last one can be cancelled");
                        SFAuthenticationSession *bad = [[SFAuthenticationSession alloc] initWithURL:[NSURL URLWithString:@"ftp://x"] callbackURLScheme:@"c" completionHandler:^(NSURL *URL, NSError *error) {
                            [log addObject:[NSString stringWithFormat:@"bad %ld", (long)error.code]];
                        }];
                        CHECK([bad start], "a session for an address that is not a web address starts");
                        after(2, ^{
                            CHECK_EQUAL(log.lastObject, @"bad 1", "and ends at once with the canceled-login error");
                            done();
                        });
                    });
                });
            });
        } copy],
    ];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SafariTestDelegate class]));
    }
}
