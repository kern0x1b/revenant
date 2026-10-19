#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <dlfcn.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import "check.h"


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

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static UIViewController *topmost(UIViewController *controller)
{
    while (controller.presentedViewController)
        controller = controller.presentedViewController;
    return controller;
}

typedef void (^Step)(void (^done)(void));

@interface AuthTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIViewController *root;
@end

@implementation AuthTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"aswebauth.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"aswebauth.log"]);
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
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"aswebauth.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
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
    return @[
        [^(void (^done)(void)) {
            CHECK_EQUAL(image_of((__bridge void *)[ASWebAuthenticationSession class]), @"libAuthenticationServicesBackports.dylib", "ASWebAuthenticationSession comes from the backports");
            CHECK_EQUAL(ASWebAuthenticationSessionErrorDomain, @"com.apple.AuthenticationServices.WebAuthenticationSession", "the error domain");
            CHECK_EQUAL(@(ASWebAuthenticationSessionErrorCodeCanceledLogin), @1, "the canceled login code");
            [[[ASWebAuthenticationSession alloc] initWithURL:local(@"/page") callbackURLScheme:@"myapp" completionHandler:nil] cancel];
            CHECK(YES, "cancel before start does nothing");
            done();
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc] initWithURL:local(@"/oauth") callbackURLScheme:@"myapp" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@ %@ presented=%d", URL.absoluteString ?: @"nil", error ? [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code] : @"noerror", root.presentedViewController != nil]];
            }];
            CHECK([session start], "a session starts");
            CHECK(![session start], "and does not start twice while it runs");
            after(5, ^{
                CHECK_EQUAL(log, (@[@"myapp://cb?code=42 noerror presented=0"]), "a redirect to the callback scheme ends the session with the callback URL and no error, once");
                after(2, ^{
                    CHECK(root.presentedViewController == nil, "and the page is gone");
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc] initWithURL:local(@"/page") callbackURLScheme:@"myapp" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@ %@/%ld", URL ? @"url" : @"nil", error.domain, (long)error.code]];
            }];
            [session start];
            after(4, ^{
                CHECK(log.count == 0 && root.presentedViewController != nil, "the login page is shown and the session waits");
                [session cancel];
                after(3, ^{
                    CHECK_EQUAL(log, (@[@"nil com.apple.AuthenticationServices.WebAuthenticationSession/1"]), "cancelling ends the session with the error of this domain and the canceled login code");
                    CHECK(root.presentedViewController == nil, "and the page is gone");
                    done();
                });
            });
        } copy],
        [^(void (^done)(void)) {
            NSMutableArray *log = [NSMutableArray array];
            ASWebAuthenticationSession *bad = [[ASWebAuthenticationSession alloc] initWithURL:[NSURL URLWithString:@"ftp://x"] callbackURLScheme:@"c" completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code]];
            }];
            CHECK([bad start], "a session for an address that is not a web address starts");
            after(2, ^{
                CHECK_EQUAL(log, (@[@"com.apple.AuthenticationServices.WebAuthenticationSession/1"]), "and ends at once with the canceled login error of this domain");
                ASWebAuthenticationSession *quiet = [[ASWebAuthenticationSession alloc] initWithURL:local(@"/oauth") callbackURLScheme:@"myapp" completionHandler:nil];
                CHECK([quiet start], "a session with no handler starts");
                after(5, ^{
                    CHECK(root.presentedViewController == nil, "and ends without one");
                    done();
                });
            });
        } copy],
    ];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AuthTestDelegate class]));
    }
}
