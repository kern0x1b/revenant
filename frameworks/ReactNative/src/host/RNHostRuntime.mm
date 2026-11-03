#import "RNHostRuntime.h"
#import "RNHostHostFunctions.h"
#import "RNHostFiles.h"

#include <JSCRuntime.h>
#include <jsi/jsi.h>
#ifdef RN_HERMES
#include <hermes/hermes.h>
#endif

#include <mach/mach.h>
#include <mach/mach_time.h>

#include <cstring>
#include <exception>
#include <memory>

NSString *const RNHostErrorDomain = @"RNHost";

namespace {

#ifdef RN_HERMES
class RNHostDataBuffer : public facebook::jsi::Buffer {
public:
    explicit RNHostDataBuffer(NSData *data) : data_(data) {}
    size_t size() const override { return data_.length; }
    const uint8_t *data() const override { return static_cast<const uint8_t *>(data_.bytes); }
private:
    NSData *data_;
};
#endif

bool RNHostIsHermesBytecode(NSData *data)
{
    static const uint8_t magic[8] = {0xC6, 0x1F, 0xBC, 0x03, 0xC1, 0x03, 0x19, 0x1F};
    return data.length >= sizeof(magic) && memcmp(data.bytes, magic, sizeof(magic)) == 0;
}

std::shared_ptr<const facebook::jsi::Buffer> RNHostLoadBuffer(NSData *data, bool bytecode)
{
#ifdef RN_HERMES
    if (bytecode) {
        return std::make_shared<RNHostDataBuffer>(data);
    }
#endif
    std::string source(static_cast<const char *>(data.bytes), data.length);
    return std::make_shared<facebook::jsi::StringBuffer>(source);
}

std::unique_ptr<facebook::jsi::Runtime> RNHostMakeRuntime(bool hermes)
{
#ifdef RN_HERMES
    if (hermes) {
        return facebook::hermes::makeHermesRuntime();
    }
#endif
    return facebook::jsc::makeJSCRuntime();
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

+ (BOOL)usesHermes
{
#ifdef RN_HERMES
    return [[RNHostConfig()[@"engine"] lowercaseString] isEqualToString:@"hermes"];
#else
    return NO;
#endif
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

    bool hermes = [self usesHermes];
    bool bytecode = hermes && RNHostIsHermesBytecode(data);
    NSLog(@"rn-host: engine %@, bundle %@", hermes ? @"hermes" : @"jsc", bytecode ? @"bytecode" : @"source");
    std::unique_ptr<facebook::jsi::Runtime> runtime = RNHostMakeRuntime(hermes);
    RNHostInstallHostFunctions(*runtime);
    uint64_t t2 = mach_absolute_time();
    NSLog(@"rn-host: runtime created in %.0f ms, rss %.1f MB", RNHostMilliseconds(t2 - t1), RNHostResidentMegabytes());

    try {
        facebook::jsi::Value owner = runtime->evaluateJavaScript(
            std::make_shared<facebook::jsi::StringBuffer>("typeof HermesInternal === 'object' && HermesInternal.hasPromise && HermesInternal.hasPromise() ? 'engine' : 'polyfill'"),
            "promise-owner.js");
        NSLog(@"rn-host: Promise from %@", [NSString stringWithUTF8String:owner.toString(*runtime).utf8(*runtime).c_str()]);
        facebook::jsi::Value result = runtime->evaluateJavaScript(RNHostLoadBuffer(data, bytecode), [[path lastPathComponent] UTF8String]);
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
