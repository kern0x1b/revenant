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
