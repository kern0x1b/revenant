#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <stdlib.h>
#import <dlfcn.h>
#import "check.h"

static void *wifi_client;
static void (*wifi_set_power)(void *, Boolean);

static BOOL wifi_open(void)
{
    if (wifi_client)
        return YES;
    void *image = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    void *(*create)(CFAllocatorRef, int) = image ? dlsym(image, "WiFiManagerClientCreate") : NULL;
    wifi_set_power = image ? dlsym(image, "WiFiManagerClientSetPower") : NULL;
    wifi_client = create ? create(kCFAllocatorDefault, 0) : NULL;
    return wifi_client && wifi_set_power;
}

static void set_network(BOOL up)
{
    if (wifi_open())
        wifi_set_power(wifi_client, up);
}

static void restore_network(void)
{
    set_network(YES);
}

static BOOL reachable(void)
{
    struct sockaddr_in zero;
    memset(&zero, 0, sizeof zero);
    zero.sin_len = sizeof zero;
    zero.sin_family = AF_INET;
    SCNetworkReachabilityRef reference = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&zero);
    SCNetworkReachabilityFlags flags = 0;
    BOOL ok = SCNetworkReachabilityGetFlags(reference, &flags) && (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    CFRelease(reference);
    return ok;
}

static BOOL wait_until(BOOL (^condition)(void), NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!condition() && [until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    return condition();
}

@interface Watcher : NSObject <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@property (atomic) int waiting;
@property (atomic) int completed;
@property (atomic, strong) NSError *error;
@property (atomic) NSInteger status;
@property (atomic, strong) NSDate *completedAt;
@end

@implementation Watcher
- (void)URLSession:(NSURLSession *)session taskIsWaitingForConnectivity:(NSURLSessionTask *)task
{
    self.waiting++;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    self.error = error;
    self.status = [(NSHTTPURLResponse *)task.response statusCode];
    self.completedAt = [NSDate date];
    self.completed++;
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
}
@end

static Watcher *run(NSURLSessionConfiguration *configuration, NSString *url, BOOL download, NSURLSessionTask **taskOut)
{
    Watcher *watcher = [Watcher new];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:watcher delegateQueue:nil];
    NSURLSessionTask *task = download ? [session downloadTaskWithURL:[NSURL URLWithString:url]] : [session dataTaskWithURL:[NSURL URLWithString:url]];
    if (taskOut)
        *taskOut = task;
    [task resume];
    return watcher;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        if (argc < 3) {
            printf("usage: waitsconnectivity <log> <http://host:port> [on|off]\n");
            return 2;
        }
        NSString *base = @(argv[2]);
        if (argc > 3 && !strcmp(argv[3], "on")) {
            set_network(YES);
            printf("wifi on requested, client=%d\n", wifi_open());
            return 0;
        }
        CHECK(wifi_open(), "the Wi-Fi manager can be reached");
        atexit(restore_network);
        NSString *url = [base stringByAppendingString:@"/bytes?n=1000"];

        CHECK(wait_until(^BOOL { return reachable(); }, 30), "the network is reachable before the test");
        Watcher *before = run([NSURLSessionConfiguration defaultSessionConfiguration], url, NO, NULL);
        NSURLSessionConfiguration *waitsUp = [NSURLSessionConfiguration defaultSessionConfiguration];
        waitsUp.waitsForConnectivity = YES;
        Watcher *connected = run(waitsUp, url, NO, NULL);
        CHECK(wait_until(^BOOL { return before.completed && connected.completed; }, 30), "both complete while the network is up");
        CHECK(before.status == 200 && connected.status == 200 && !before.error && !connected.error, "with a 200");
        CHECK(connected.waiting == 0, "a session that waits does not say it is waiting while the network is there");

        set_network(NO);
        CHECK(wait_until(^BOOL { return !reachable(); }, 30), "the network is down");

        NSDate *started = [NSDate date];
        Watcher *fails = run([NSURLSessionConfiguration defaultSessionConfiguration], url, NO, NULL);
        CHECK(wait_until(^BOOL { return fails.completed > 0; }, 30), "without waiting a task ends");
        CHECK_EQUAL(([NSString stringWithFormat:@"%@ %ld %d", fails.error.domain, (long)fails.error.code, fails.waiting]), @"NSURLErrorDomain -1004 0", "with cannot connect to host, which is what iOS 6 says with the network down, and no call about waiting");
        CHECK(-[started timeIntervalSinceNow] < 15, "at once");

        NSURLSessionConfiguration *waitsDown = [NSURLSessionConfiguration defaultSessionConfiguration];
        waitsDown.waitsForConnectivity = YES;
        Watcher *waits = run(waitsDown, url, NO, NULL);
        NSURLSessionConfiguration *background = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"org.charon.waits.background"];
        Watcher *backgrounded = run(background, url, YES, NULL);
        NSURLSessionConfiguration *shortResource = [NSURLSessionConfiguration defaultSessionConfiguration];
        shortResource.waitsForConnectivity = YES;
        shortResource.timeoutIntervalForResource = 4;
        NSDate *shortStart = [NSDate date];
        Watcher *timesOut = run(shortResource, url, NO, NULL);
        NSURLSessionTask *cancelled = nil;
        Watcher *cancelWatcher = run(waitsDown, url, NO, &cancelled);
        CHECK(wait_until(^BOOL { return waits.waiting == 1 && backgrounded.waiting == 1 && cancelWatcher.waiting == 1; }, 30), "a task that waits says so once, the background one too");
        [cancelled cancel];
        CHECK(wait_until(^BOOL { return cancelWatcher.completed > 0; }, 15) && cancelWatcher.error.code == NSURLErrorCancelled, "a task cancelled while it waits ends cancelled");
        CHECK(wait_until(^BOOL { return timesOut.completed > 0; }, 30), "a task whose resource timeout passes while it waits ends");
        CHECK(timesOut.error.code == NSURLErrorTimedOut && -[shortStart timeIntervalSinceNow] >= 3.5, "timed out, after the resource timeout");
        wait_until(^BOOL { return NO; }, 3);
        CHECK(waits.completed == 0 && backgrounded.completed == 0, "the others are still waiting");
        CHECK(waits.waiting == 1 && backgrounded.waiting == 1, "and said so once");

        set_network(YES);
        CHECK(wait_until(^BOOL { return waits.completed > 0 && backgrounded.completed > 0; }, 120), "they go on when the network comes back");
        CHECK(waits.status == 200 && !waits.error, "the data task gets its 200");
        CHECK(backgrounded.status == 200 && !backgrounded.error, "and the background download");
        CHECK(waits.waiting == 1 && cancelWatcher.completed == 1, "nothing is called twice");
        int completedRaces = 0;
        for (NSNumber *delay in @[@0, @0.02, @0.05, @0.1, @0.2, @0.35]) {
            CHECK(wait_until(^BOOL { return reachable(); }, 60), "the network is back for a race");
            wait_until(^BOOL { return NO; }, 2);
            NSURLSessionConfiguration *racing = [NSURLSessionConfiguration defaultSessionConfiguration];
            racing.waitsForConnectivity = YES;
            Watcher *race = run(racing, [base stringByAppendingString:@"/delay?ms=1500"], NO, NULL);
            wait_until(^BOOL { return NO; }, delay.doubleValue);
            set_network(NO);
            wait_until(^BOOL { return !reachable(); }, 30);
            wait_until(^BOOL { return NO; }, 3);
            set_network(YES);
            if (wait_until(^BOOL { return race.completed > 0; }, 90) && race.status == 200 && !race.error)
                completedRaces++;
        }
        CHECK(completedRaces == 6, "a task that waits, and has the network taken away as it begins, ends with its answer once it is back");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
