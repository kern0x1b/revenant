#import "RNHostAppDelegate.h"
#import <objc/runtime.h>
#import "RNHostRuntime.h"
#import "RNHostFiles.h"
#import "RNHostViewController.h"

#import <RCTDefaultReactNativeFactoryDelegate.h>
#import <RCTReactNativeFactory.h>
#import <RCTAppDependencyProvider.h>
#import <React/RCTLog.h>
#import <react/runtime/JSRuntimeFactoryCAPI.h>
#import <react/runtime/platform/ios/ReactCommon/RCTJscInstance.h>

#ifdef RN_HERMES
#import <react/runtime/platform/ios/ReactCommon/RCTHermesInstance.h>
#import <cxxreact/MessageQueueThread.h>
#import <malloc/malloc.h>
#include <algorithm>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>
#include <jsi/instrumentation.h>
#endif

#ifdef RN_HERMES
// The Hermes runtime is created by RCTHermesInstance; this subclass keeps the runtime and the queue it runs on
// so that the heartbeat can read the JS heap on the JS thread, where the runtime may be used.
namespace {

std::mutex RNHostProbeMutex;
std::shared_ptr<facebook::react::MessageQueueThread> RNHostProbeQueue;
facebook::jsi::Runtime *RNHostProbeRuntime = nullptr;

void RNHostProbeAttach(facebook::jsi::Runtime &runtime, std::shared_ptr<facebook::react::MessageQueueThread> queue)
{
    std::lock_guard<std::mutex> lock(RNHostProbeMutex);
    RNHostProbeRuntime = &runtime;
    RNHostProbeQueue = std::move(queue);
}

void RNHostLogHeapStats()
{
    std::shared_ptr<facebook::react::MessageQueueThread> queue;
    facebook::jsi::Runtime *runtime = nullptr;
    {
        std::lock_guard<std::mutex> lock(RNHostProbeMutex);
        queue = RNHostProbeQueue;
        runtime = RNHostProbeRuntime;
    }
    if (!queue || !runtime) {
        return;
    }
    queue->runOnQueue([runtime] {
        std::unordered_map<std::string, int64_t> info = runtime->instrumentation().getHeapInfo(false);
        std::vector<std::pair<std::string, int64_t>> entries(info.begin(), info.end());
        std::sort(entries.begin(), entries.end());
        std::string line;
        for (const auto &entry : entries) {
            line += entry.first + "=" + std::to_string(entry.second) + " ";
        }
        NSLog(@"rn-host: js heap %s", line.c_str());
    });
}

class RNHostHermesFactory : public facebook::react::RCTHermesInstance {
public:
    std::unique_ptr<facebook::react::JSRuntime> createJSRuntime(std::shared_ptr<facebook::react::MessageQueueThread> queue) noexcept override
    {
        std::unique_ptr<facebook::react::JSRuntime> runtime = RCTHermesInstance::createJSRuntime(queue);
        RNHostProbeAttach(runtime->getRuntime(), queue);
        return runtime;
    }
};

} // namespace
#endif

#ifdef RN_EXPO
#import <ExpoModulesCore/EXHostWrapper.h>
#import <ExpoModulesCore/EXReactSchedulerDispatch.h>
#import <ReactCommon/RCTHost.h>
#import <react/renderer/runtimescheduler/RuntimeSchedulerBinding.h>

extern "C" {
typedef const struct OpaqueJSContext *RNHostJSContext;
typedef const struct OpaqueJSContextGroup *RNHostJSGroup;
typedef const struct OpaqueJSValue *RNHostJSValue;
typedef struct OpaqueJSString *RNHostJSString;
RNHostJSContext RNJscRuntimeContext(void);
RNHostJSGroup JSContextGetGroup(RNHostJSContext context);
void JSContextGroupSetExecutionTimeLimit(RNHostJSGroup group, double limit, bool (*callback)(RNHostJSContext, void *), void *context);
RNHostJSValue JSEvaluateScript(RNHostJSContext ctx, RNHostJSString script, void *thisObject, RNHostJSString sourceURL, int line, RNHostJSValue *exception);
RNHostJSString JSStringCreateWithUTF8CString(const char *string);
RNHostJSString JSValueToStringCopy(RNHostJSContext ctx, RNHostJSValue value, RNHostJSValue *exception);
size_t JSStringGetMaximumUTF8CStringSize(RNHostJSString string);
size_t JSStringGetUTF8CString(RNHostJSString string, char *buffer, size_t bufferSize);
void JSStringRelease(RNHostJSString string);
}

static NSMutableDictionary *RNHostSamples;
static NSMutableDictionary *RNHostSelfSamples;
static NSUInteger RNHostSampleCount;

static bool RNHostSampleStack(RNHostJSContext ctx, void *)
{
    static bool inside = false;
    if (inside) {
        return false;
    }
    inside = true;
    RNHostJSString script = JSStringCreateWithUTF8CString("new Error().stack");
    RNHostJSValue exception = NULL;
    RNHostJSValue value = JSEvaluateScript(ctx, script, NULL, NULL, 0, &exception);
    JSStringRelease(script);
    RNHostJSString text = value ? JSValueToStringCopy(ctx, value, &exception) : NULL;
    if (text) {
        size_t size = JSStringGetMaximumUTF8CStringSize(text);
        char *bytes = (char *)malloc(size);
        JSStringGetUTF8CString(text, bytes, size);
        JSStringRelease(text);
        @autoreleasepool {
            NSArray *frames = [[NSString stringWithUTF8String:bytes] componentsSeparatedByString:@"\n"];
            NSString *stack = [[frames subarrayWithRange:NSMakeRange(0, MIN(frames.count, 16))] componentsJoinedByString:@" < "];
            RNHostSamples[stack] = @([RNHostSamples[stack] integerValue] + 1);
            NSString *top = frames.count > 1 ? frames[1] : @"(none)";
            RNHostSelfSamples[top] = @([RNHostSelfSamples[top] integerValue] + 1);
            if (RNHostSampleCount < 3) {
                NSLog(@"rn-host: JS sample %lu: %@", (unsigned long)RNHostSampleCount, stack);
            }
            if (++RNHostSampleCount % 100 == 0) {
                NSDictionary *out = @{@"samples": @(RNHostSampleCount), @"stacks": RNHostSamples, @"self": RNHostSelfSamples};
                [[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] writeToFile:RNHostRunPath(@"rnhost.jsprof.out") atomically:YES];
            }
        }
        free(bytes);
    }
    inside = false;
    return false;
}

extern "C" __attribute__((weak)) RNHostJSContext RNJscRuntimeContext(void)
{
    return NULL;
}

static void RNHostInstallSampler(void)
{
    NSString *flag = RNHostReadAppText(@"rnhost.jsprof");
    if (!flag) {
        return;
    }
    double interval = flag.doubleValue > 0 ? flag.doubleValue : 10;
    RNHostSamples = [NSMutableDictionary dictionary];
    RNHostSelfSamples = [NSMutableDictionary dictionary];
    if (!RNJscRuntimeContext()) {
        NSLog(@"rn-host: JS sampler needs the JavaScriptCore runtime, off");
        return;
    }
    JSContextGroupSetExecutionTimeLimit(JSContextGetGroup(RNJscRuntimeContext()), interval / 1000.0, RNHostSampleStack, NULL);
    NSLog(@"rn-host: JS sampler every %.0f ms", interval);
}

@protocol RNHostExpoAppContext <NSObject>
- (void)setRuntime:(void *)runtimePointer scheduler:(void *)scheduler dispatch:(const void *)dispatch;
- (void)setHostWrapper:(EXHostWrapper *)wrapper;
- (void)registerNativeModules;
@end

@interface RNHostReactFactory : RCTReactNativeFactory
@end

@implementation RNHostReactFactory {
    id<RNHostExpoAppContext> _appContext;
}

- (void)host:(RCTHost *)host didInitializeRuntime:(facebook::jsi::Runtime &)runtime
{
    id<RNHostExpoAppContext> appContext = [[NSClassFromString(@"EXAppContext") alloc] init];
    _appContext = appContext;
    auto binding = facebook::react::RuntimeSchedulerBinding::getBinding(runtime);
    auto scheduler = binding ? binding->getRuntimeScheduler() : nullptr;
    void *schedulerHandle = expo::createReactSchedulerHandle(scheduler);
    [appContext setRuntime:&runtime
                 scheduler:schedulerHandle
                  dispatch:schedulerHandle ? reinterpret_cast<const void *>(&expo::dispatchOnReactScheduler) : nullptr];
    [appContext setHostWrapper:[[EXHostWrapper alloc] initWithHost:host]];
    [appContext registerNativeModules];
    RNHostInstallSampler();
    NSLog(@"rn-host: expo app context installed, rss %.1f MB", [RNHostRuntime residentMegabytes]);
}

@end
#endif

@interface RNHostReactDelegate : RCTDefaultReactNativeFactoryDelegate
@end

@implementation RNHostReactDelegate

- (NSURL *)bundleURL
{
    NSString *path = [RNHostRuntime configuredBundlePath] ?: [[[NSBundle mainBundle] pathsForResourcesOfType:@"js" inDirectory:nil] firstObject];
    return [NSURL fileURLWithPath:path];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
    return [self bundleURL];
}

- (BOOL)newArchEnabled
{
    return YES;
}

- (BOOL)bridgelessEnabled
{
    return YES;
}

- (JSRuntimeFactoryRef)createJSRuntimeFactory
{
#ifdef RN_HERMES
    if ([RNHostRuntime usesHermes]) {
        NSLog(@"rn-host: engine hermes");
        return reinterpret_cast<JSRuntimeFactoryRef>(new RNHostHermesFactory());
    }
#endif
    NSLog(@"rn-host: engine jsc");
    return reinterpret_cast<JSRuntimeFactoryRef>(new facebook::react::RCTJscInstance());
}

@end

@implementation RNHostAppDelegate {
    RNHostReactDelegate *_reactDelegate;
#ifdef RN_EXPO
    RNHostReactFactory *_factory;
#else
    RCTReactNativeFactory *_factory;
#endif
}

static NSUInteger RNHostCountViews(UIView *view)
{
    NSUInteger count = 1;
    for (UIView *subview in view.subviews) {
        count += RNHostCountViews(subview);
    }
    return count;
}

- (void)logHeartbeat
{
    malloc_statistics_t malloced;
    malloc_zone_statistics(malloc_default_zone(), &malloced);
    NSLog(@"rn-host: heartbeat rss %.1f MB, subviews %lu, views %lu, malloc in use %.1f MB of %.1f MB",
          [RNHostRuntime residentMegabytes], (unsigned long)self.window.rootViewController.view.subviews.count,
          (unsigned long)RNHostCountViews(self.window), malloced.size_in_use / 1048576.0, malloced.size_allocated / 1048576.0);
#ifdef RN_HERMES
    RNHostLogHeapStats();
#endif
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    NSString *module = [RNHostRuntime configuredValueForKey:@"module"];
    if (!module) {
        self.window.rootViewController = [[RNHostViewController alloc] initWithNibName:nil bundle:nil];
        [self.window makeKeyAndVisible];
        return YES;
    }
    [RNHostRuntime applyEnvironment];
    NSLog(@"rn-host: react start module %@, rss %.1f MB", module, [RNHostRuntime residentMegabytes]);
    RCTSetLogThreshold(RCTLogLevelInfo);
    RCTSetLogFunction(^(RCTLogLevel level, RCTLogSource source, NSString *fileName, NSNumber *lineNumber, NSString *message) {
        NSLog(@"rn-host: rct[%d,%d] %@:%@ %@", (int)level, (int)source, fileName.lastPathComponent, lineNumber, message);
    });
    [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(logHeartbeat) userInfo:nil repeats:YES];
    _reactDelegate = [RNHostReactDelegate new];
    _reactDelegate.dependencyProvider = [RCTAppDependencyProvider new];
#ifdef RN_EXPO
    _factory = [[RNHostReactFactory alloc] initWithDelegate:_reactDelegate];
#else
    _factory = [[RCTReactNativeFactory alloc] initWithDelegate:_reactDelegate];
#endif
    [self.window makeKeyAndVisible];
    [_factory startReactNativeWithModuleName:module inWindow:self.window];
    NSLog(@"rn-host: react started, rss %.1f MB", [RNHostRuntime residentMegabytes]);
    return YES;
}

@end
