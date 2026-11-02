#import "RNHostRuntime.h"
#import "RNHostHostFunctions.h"
#import "RNHostRunFolder.h"

#include <JSCRuntime.h>
#include <jsi/jsi.h>

#include <mach/mach.h>
#include <mach/mach_time.h>

#include <exception>
#include <memory>

NSString *const RNHostErrorDomain = @"RNHost";

namespace {

std::shared_ptr<const facebook::jsi::Buffer> RNHostLoadBuffer(NSData *data)
{
    std::string source(static_cast<const char *>(data.bytes), data.length);
    return std::make_shared<facebook::jsi::StringBuffer>(source);
}

NSError *RNHostError(NSString *message)
{
    return [NSError errorWithDomain:RNHostErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

double RNHostMilliseconds(uint64_t ticks)
{
    static mach_timebase_info_data_t base;
    if (base.denom == 0) mach_timebase_info(&base);
    return (double)ticks * base.numer / base.denom / 1e6;
}

double RNHostResidentMegabytes()
{
    task_basic_info_data_t info;
    mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
    return info.resident_size / 1048576.0;
}

// rnhost.conf inside the application bundle. Only module, bundle, engine and JSC_* keys are taken; any other key is refused.
NSDictionary<NSString *, NSString *> *RNHostConfig()
{
    NSString *text = RNHostReadAppText(@"rnhost.conf");
    NSMutableDictionary<NSString *, NSString *> *config = [NSMutableDictionary dictionary];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSRange equals = [line rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [line substringToIndex:equals.location];
        BOOL allowed = [@[@"module", @"bundle", @"engine"] containsObject:key] || [key hasPrefix:@"JSC_"];
        if (!allowed) {
            NSLog(@"rn-host: refusing config key %@: only module, bundle, engine and JSC_* are read", key);
            continue;
        }
        config[key] = [line substringFromIndex:equals.location + 1];
    }
    return config;
}

}

@implementation RNHostRuntime

// The bundle named by the configuration, relative to the application bundle or absolute inside it. nil when there is none,
// or when it is not a root-owned regular file inside the application (then the refusal is logged).
+ (NSString *)configuredBundlePath
{
    NSString *bundle = RNHostConfig()[@"bundle"];
    if (!bundle) return nil;
    NSString *path = RNHostTrustedAppFile(bundle);
    if (!path) NSLog(@"rn-host: configured bundle %@ is not loaded: it must be a root-owned file inside the application", bundle);
    return path;
}

+ (double)residentMegabytes
{
    return RNHostResidentMegabytes();
}

+ (NSString *)configuredValueForKey:(NSString *)key
{
    return RNHostConfig()[key];
}

+ (void)applyEnvironment
{
    NSDictionary<NSString *, NSString *> *config = RNHostConfig();
    for (NSString *key in config) {
        if ([key hasPrefix:@"JSC_"]) {
            setenv(key.UTF8String, config[key].UTF8String, 1);
            NSLog(@"rn-host: env %@=%@", key, config[key]);
        }
    }
}

+ (NSString *)evaluateBundleAtPath:(NSString *)path error:(NSError **)error
{
    [self applyEnvironment];

    NSLog(@"rn-host: rss at start %.1f MB", RNHostResidentMegabytes());
    uint64_t t0 = mach_absolute_time();
    NSData *data = RNHostReadAppFile(path, NULL);
    if (!data) {
        NSString *message = [NSString stringWithFormat:@"cannot read bundle at %@ (missing, or not a root-owned file inside the application)", path];
        NSLog(@"rn-host: %@", message);
        if (error) *error = RNHostError(message);
        return nil;
    }
    uint64_t t1 = mach_absolute_time();
    NSLog(@"rn-host: read %lu bytes in %.0f ms, rss %.1f MB", (unsigned long)data.length, RNHostMilliseconds(t1 - t0), RNHostResidentMegabytes());

    std::unique_ptr<facebook::jsi::Runtime> runtime = facebook::jsc::makeJSCRuntime();
    RNHostInstallHostFunctions(*runtime);
    uint64_t t2 = mach_absolute_time();
    NSLog(@"rn-host: runtime created in %.0f ms, rss %.1f MB", RNHostMilliseconds(t2 - t1), RNHostResidentMegabytes());

    try {
        facebook::jsi::Value result = runtime->evaluateJavaScript(RNHostLoadBuffer(data), [[path lastPathComponent] UTF8String]);
        uint64_t t3 = mach_absolute_time();
        NSString *text = [NSString stringWithUTF8String:result.toString(*runtime).utf8(*runtime).c_str()];
        NSLog(@"rn-host: evaluated in %.0f ms, rss %.1f MB", RNHostMilliseconds(t3 - t2), RNHostResidentMegabytes());
        NSLog(@"rn-host: bundle result: %@", text);
        return text;
    } catch (const facebook::jsi::JSError &exception) {
        NSLog(@"rn-host: failed after %.0f ms, rss %.1f MB", RNHostMilliseconds(mach_absolute_time() - t2), RNHostResidentMegabytes());
        NSString *message = [NSString stringWithUTF8String:exception.getMessage().c_str()];
        NSLog(@"rn-host: bundle exception: %@\n%s", message, exception.getStack().c_str());
        if (error) *error = RNHostError(message);
        return nil;
    } catch (const std::exception &exception) {
        NSString *message = [NSString stringWithUTF8String:exception.what()];
        NSLog(@"rn-host: bundle failed: %@", message);
        if (error) *error = RNHostError(message);
        return nil;
    }
}

@end

#import <objc/runtime.h>

@implementation RNHostRuntime (ClassProbe)

+ (void)logClassProbes
{
    for (NSString *name in @[@"NSTextList", @"NSTextTab", @"NSTextStorage"]) {
        Class base = NSClassFromString(name);
        NSMutableString *chain = [NSMutableString string];
        for (Class cls = base; cls; cls = class_getSuperclass(cls)) {
            [chain appendFormat:@"%s%s", chain.length ? " < " : "", class_getName(cls)];
        }
        NSLog(@"rn-host: classprobe %@ chain: %@", name, chain.length ? chain : @"(null)");
        if (!base) continue;
        Class sub = objc_allocateClassPair(base, [[@"RNHostProbe" stringByAppendingString:name] UTF8String], 0);
        if (!sub) {
            NSLog(@"rn-host: classprobe %@ subclass allocation failed", name);
            continue;
        }
        objc_registerClassPair(sub);
        NSMutableString *subChain = [NSMutableString string];
        for (Class cls = sub; cls; cls = class_getSuperclass(cls)) {
            [subChain appendFormat:@"%s%s", subChain.length ? " < " : "", class_getName(cls)];
        }
        NSLog(@"rn-host: classprobe %@ subclass chain: %@; isSubclassOfClass: %d; superclass of base: %s", name, subChain, (int)[sub isSubclassOfClass:base], class_getSuperclass(base) ? class_getName(class_getSuperclass(base)) : "(null)");
    }
}

@end
