#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void Mark(NSString *event)
{
    NSString *line = [NSString stringWithFormat:@"REFREPRO %@\n", event];
    fputs(line.UTF8String, stdout);
    fflush(stdout);
    NSString *path = @"/private/var/charon/refrepro.log";
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

// Exact shape of OBAReferencesV2: five NSMutableDictionary object ivars.
// Under ARC, -init's ivar stores become objc_storeStrong, which reads the OLD ivar
// value (an 8-byte slot on the arm64 layout) before releasing it -- exactly the site
// that faulted in OneBusAway (-[OBAReferencesV2 init] -> objc_release of a mis-sized
// tail slot).
@interface Refs : NSObject
@end

@implementation Refs {
    NSMutableDictionary *_agencies;
    NSMutableDictionary *_routes;
    NSMutableDictionary *_stops;
    NSMutableDictionary *_trips;
    NSMutableDictionary *_situations;
}

- (id)init
{
    self = [super init];
    if (self) {
        _agencies = [[NSMutableDictionary alloc] init];
        _routes = [[NSMutableDictionary alloc] init];
        _stops = [[NSMutableDictionary alloc] init];
        _trips = [[NSMutableDictionary alloc] init];
        _situations = [[NSMutableDictionary alloc] init];
    }
    return self;
}

@end

// Dirty the small-object heap so a freshly allocated instance's out-of-bounds tail
// slot (bytes past the shrunk instance size) contains garbage instead of zero.
static void PoisonHeap(void)
{
    enum { N = 4096 };
    void *blocks[N];
    for (int i = 0; i < N; i++) {
        blocks[i] = malloc(48);
        memset(blocks[i], 0xAA, 48);
    }
    for (int i = 0; i < N; i++)
        free(blocks[i]);
}

static void DumpObject(const char *tag, Refs *obj)
{
    size_t size = class_getInstanceSize([Refs class]);
    NSMutableString *words = [NSMutableString string];
    unsigned char *bytes = (unsigned char *)(__bridge void *)obj;
    for (size_t off = 0; off + 4 <= size; off += 4) {
        unsigned int w;
        __builtin_memcpy(&w, bytes + off, 4);
        [words appendFormat:@"[%zu]=0x%x ", off, w];
    }
    Mark([NSString stringWithFormat:@"%s obj=%p instanceSize=%zu %@", tag, (void *)obj, size, words]);
}

static void RunRepro(void)
{
    // The guest arm64 layout is: 8-byte isa + five 8-byte object ivars = 48 bytes.
    // If the runtime allocates fewer bytes (e.g. 44), the last ivar's 8-byte slot spills
    // past the allocation and the release-of-old-ivar in -init reads an out-of-bounds
    // high half -> objc_release(garbage<<32). Regression assertion: size must be 48.
    size_t size = class_getInstanceSize([Refs class]);
    Mark([NSString stringWithFormat:@"start instanceSize=%zu expected=48 -> %s",
                                     size, size == 48 ? "PASS" : "FAIL"]);
    for (int i = 0; i < 128; i++) {
        PoisonHeap();
        Refs *r = [[Refs alloc] init];
        if (i < 3)
            DumpObject("post-init", r);
        r = nil;
    }
    Mark(@"done");
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    Mark(@"didFinishLaunching");
    RunRepro();
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor greenColor];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    Mark(@"window shown");
    return YES;
}
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
