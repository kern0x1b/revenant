#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <stdint.h>
#include <unistd.h>

extern int sandbox_init(const char *profile, uint64_t flags, char **errorbuf);

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;
static NSString *const REVENANT_RESULT = @"/var/revenant/reading-list-probe.txt";
static NSString *const REVENANT_FIRST = @"https://example.com/revenant-reading-list-probe";
static NSString *const REVENANT_SECOND = @"http://example.com/revenant-reading-list-probe-background";

static void revenant_line(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void revenant_line(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [REVENANT_LOG appendFormat:@"%@\n", [[NSString alloc] initWithFormat:format arguments:arguments]];
    va_end(arguments);
    [REVENANT_LOG writeToFile:REVENANT_RESULT atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    revenant_line(@"%@ %@", ok ? @"PASS" : @"FAIL", name);
}

static void revenant_wait(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static id revenant_collection(void)
{
    return ((id (*)(id, SEL, BOOL))objc_msgSend)([NSClassFromString(@"WebBookmarkCollection") alloc], NSSelectorFromString(@"initSafariBookmarkCollectionCheckingIntegrity:"), NO);
}

static id revenant_item(NSString *address)
{
    return ((id (*)(id, SEL, id, BOOL))objc_msgSend)(revenant_collection(), NSSelectorFromString(@"firstReadingListBookmarkWithURLMatchingString:prefixMatch:"), address, NO);
}

static NSUInteger revenant_remove(NSString *address)
{
    id collection = revenant_collection();
    SEL first = NSSelectorFromString(@"firstReadingListBookmarkWithURLMatchingString:prefixMatch:");
    NSUInteger removed = 0;
    for (id item = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(collection, first, address, NO); item && removed < 20;
         item = ((id (*)(id, SEL, id, BOOL))objc_msgSend)(collection, first, address, NO), removed++)
        ((BOOL (*)(id, SEL, id))objc_msgSend)(collection, NSSelectorFromString(@"deleteBookmark:"), item);
    return removed;
}

static id revenant_value(id object, NSString *key)
{
    SEL selector = NSSelectorFromString(key);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}

@interface RevenantReadingListDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantReadingListDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(revenantRun) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)revenantRun
{
    REVENANT_LOG = [NSMutableString string];
    revenant_line(@"INFO uid %d home %@", getuid(), NSHomeDirectory());
    revenant_check(dlopen("/System/Library/PrivateFrameworks/WebBookmarks.framework/WebBookmarks", RTLD_LAZY) != NULL, @"WebBookmarks loads");
    revenant_remove(REVENANT_FIRST);
    revenant_remove(REVENANT_SECOND);

    revenant_check([SSReadingList supportsURL:[NSURL URLWithString:@"http://example.com/a"]], @"http is supported");
    revenant_check([SSReadingList supportsURL:[NSURL URLWithString:@"HTTPS://EXAMPLE.COM/a"]], @"an upper case https is supported");
    revenant_check(![SSReadingList supportsURL:[NSURL URLWithString:@"ftp://example.com/a"]], @"ftp is not supported");
    revenant_check(![SSReadingList supportsURL:[NSURL URLWithString:@"mailto:a@example.com"]], @"mailto is not supported");
    revenant_check(![SSReadingList supportsURL:[NSURL URLWithString:@"example.com"]], @"a URL without a scheme is not supported");

    SSReadingList *list = [SSReadingList defaultReadingList];
    revenant_check(list != nil, @"defaultReadingList returns the list");
    revenant_check(list == [SSReadingList defaultReadingList], @"defaultReadingList returns one shared list");

    NSError *error = nil;
    BOOL added = [list addReadingListItemWithURL:[NSURL URLWithString:REVENANT_FIRST] title:@"Revenant probe" previewText:@"A preview" error:&error];
    revenant_check(added && error == nil, @"adding an https URL succeeds");
    revenant_wait(1.0);
    id item = revenant_item(REVENANT_FIRST);
    revenant_check(item != nil, @"the item reaches Safari's Reading List");
    revenant_check([[revenant_value(item, @"title") description] isEqualToString:@"Revenant probe"], @"the item keeps its title");
    revenant_check([[revenant_value(item, @"previewText") description] isEqualToString:@"A preview"], @"the item keeps its preview text");
    revenant_check([[revenant_value(item, @"address") description] isEqualToString:REVENANT_FIRST], @"the item keeps its address");

    added = [list addReadingListItemWithURL:[NSURL URLWithString:REVENANT_FIRST] title:@"Again" previewText:nil error:&error];
    revenant_check(added, @"adding the same URL again succeeds");
    revenant_wait(1.0);
    revenant_check(revenant_remove(REVENANT_FIRST) == 1, @"the same URL stays one item");

    error = nil;
    added = [list addReadingListItemWithURL:[NSURL URLWithString:@"mailto:a@example.com"] title:nil previewText:nil error:&error];
    revenant_check(!added && [error.domain isEqualToString:SSReadingListErrorDomain] && error.code == SSReadingListErrorURLSchemeNotAllowed, @"adding a mailto URL fails with the scheme error");
    revenant_check([SSReadingListErrorDomain isEqualToString:@"SSReadingListErrorDomain"], @"the error domain is SSReadingListErrorDomain");

    dispatch_semaphore_t returned = dispatch_semaphore_create(0);
    __block BOOL backgroundAdded = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        backgroundAdded = [list addReadingListItemWithURL:[NSURL URLWithString:REVENANT_SECOND] title:nil previewText:nil error:&failure];
        dispatch_semaphore_signal(returned);
    });
    revenant_wait(1.5);
    revenant_check(dispatch_semaphore_wait(returned, DISPATCH_TIME_NOW) == 0 && backgroundAdded, @"adding from a background thread returns YES");
    revenant_check(revenant_item(REVENANT_SECOND) != nil, @"an item added from a background thread reaches the list");
    revenant_remove(REVENANT_SECOND);

    char *failure = NULL;
    int applied = sandbox_init("(version 1)(allow default)(deny file-write* (subpath \"/private/var/mobile/Library/Safari\"))(deny file-read* (subpath \"/private/var/mobile/Library/Safari\"))", 0, &failure);
    revenant_line(@"INFO sandbox_init Safari folder denied %d %s", applied, failure ?: "");
    if (applied == 0) {
        revenant_check([SSReadingList defaultReadingList] == nil, @"with writes denied defaultReadingList returns nil");
        revenant_check([SSReadingList supportsURL:[NSURL URLWithString:@"https://example.com"]], @"supportsURL does not depend on access");
    }
    revenant_line(@"REVENANT-DONE failures %lu", (unsigned long)REVENANT_FAILURES);
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantReadingListDelegate class]));
    }
}
