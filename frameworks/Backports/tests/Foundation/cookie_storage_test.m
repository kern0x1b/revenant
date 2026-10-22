#import "check.h"
#import "RevenantCookieStorage.h"

@interface RevenantFakeTask : NSObject
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic, strong) NSURLRequest *originalRequest;
@end

@implementation RevenantFakeTask
@end

static NSURLSessionConfiguration *revenant_configuration;

NSURLSessionConfiguration *revenant_task_configuration(NSURLSessionTask *task);

NSURLSessionConfiguration *revenant_task_configuration(NSURLSessionTask *task)
{
    return revenant_configuration;
}

static NSHTTPCookie *revenant_cookie(NSString *name, NSString *domain)
{
    return [NSHTTPCookie cookieWithProperties:@{NSHTTPCookieName: name, NSHTTPCookieValue: @"v", NSHTTPCookieDomain: domain, NSHTTPCookiePath: @"/",
                                                NSHTTPCookieExpires: [NSDate dateWithTimeIntervalSinceNow:3600]}];
}

static void revenant_store(NSHTTPCookieStorage *storage, NSArray *cookies, id task)
{
    SEL selector = @selector(storeCookies:forTask:);
    REVENANT_IMP(NSHTTPCookieStorage, selector, void (*)(id, SEL, NSArray *, id))(storage, selector, cookies, task);
}

static NSArray *revenant_get(NSHTTPCookieStorage *storage, id task)
{
    SEL selector = @selector(getCookiesForTask:completionHandler:);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSArray *found = nil;
    __block BOOL called = NO;
    REVENANT_IMP(NSHTTPCookieStorage, selector, void (*)(id, SEL, id, void (^)(NSArray *)))(storage, selector, task, ^(NSArray *cookies) {
        found = cookies;
        called = YES;
        dispatch_semaphore_signal(done);
    });
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return called ? (found ?: @[]) : nil;
}

static void revenant_remove_since(NSHTTPCookieStorage *storage, NSDate *date)
{
    SEL selector = @selector(removeCookiesSinceDate:);
    REVENANT_IMP(NSHTTPCookieStorage, selector, void (*)(id, SEL, NSDate *))(storage, selector, date);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSHTTPCookieStorage *storage = revenant_ephemeral_cookie_storage();
    RevenantFakeTask *task = [[RevenantFakeTask alloc] init];
    task.currentRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/a"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];
    revenant_store(storage, @[revenant_cookie(@"session", @"example.com")], task);
    revenant_check(storage.cookies.count == 1, "a task stores its cookies", [NSString stringWithFormat:@"%lu", (unsigned long)storage.cookies.count]);
    NSArray *got = revenant_get(storage, task);
    revenant_check(got.count == (revenant_negative ? 2 : 1), "a task gets the cookies of its URL", [NSString stringWithFormat:@"%@", got]);
    revenant_configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    revenant_store(storage, @[revenant_cookie(@"never", @"example.com")], task);
    revenant_check(storage.cookies.count == 1, "a policy of never stores nothing", [NSString stringWithFormat:@"%lu", (unsigned long)storage.cookies.count]);
    revenant_check(revenant_get(storage, task).count == 0, "a policy of never gets nothing", @"got cookies");
    revenant_configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    revenant_configuration.HTTPShouldSetCookies = NO;
    revenant_check(revenant_get(storage, task).count == 0, "a configuration that sets no cookies gets nothing", @"got cookies");
    revenant_configuration.HTTPShouldSetCookies = YES;
    NSDate *cut = [NSDate date];
    usleep(1100000);
    [storage setCookie:revenant_cookie(@"late", @"example.com")];
    usleep(300000);
    revenant_remove_since(storage, cut);
    NSMutableArray *names = [NSMutableArray array];
    for (NSHTTPCookie *cookie in storage.cookies)
        [names addObject:cookie.name];
    revenant_check([names isEqualToArray:@[@"session"]], "removing since a date keeps the older cookies only", [NSString stringWithFormat:@"%@", names]);
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSURL *container = [NSURL fileURLWithPath:folder isDirectory:YES];
    NSHTTPCookieStorage *group = revenant_group_cookie_storage(@"group.test", container);
    revenant_check(group == revenant_group_cookie_storage(@"group.test", container), "one identifier has one storage", @"two storages");
    [group setCookie:revenant_cookie(@"shared", @"example.com")];
    NSURL *file = [container URLByAppendingPathComponent:@"Library/Cookies/Cookies.revenant.plist"];
    revenant_check([[NSFileManager defaultManager] fileExistsAtPath:file.path], "a group storage persists its cookies", file.path);
    RevenantEphemeralCookieStorage *reader = (RevenantEphemeralCookieStorage *)revenant_ephemeral_cookie_storage();
    reader->_persistentURL = file;
    revenant_check(reader.cookies.count == 1 && [reader.cookies.firstObject.name isEqualToString:@"shared"], "another reader of the file sees the cookie", [NSString stringWithFormat:@"%@", reader.cookies]);
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    return revenant_finish();
}
