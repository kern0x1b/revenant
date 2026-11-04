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
#include <mach/vm_region.h>
#include <mach/vm_statistics.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

#include <unistd.h>

#import <QuartzCore/QuartzCore.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <exception>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <vector>

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

namespace {

struct RNHostImageRange {
    uintptr_t start;
    uintptr_t end;
    std::string name;
};

struct RNHostMemoryBucket {
    uint64_t resident = 0;
    uint64_t dirtied = 0;
};

std::string RNHostTagName(unsigned int tag)
{
    switch (tag) {
    case 0:
        return "untagged (mapped file or unclassified)";
    case VM_MEMORY_MALLOC:
    case VM_MEMORY_MALLOC_SMALL:
    case VM_MEMORY_MALLOC_LARGE:
    case VM_MEMORY_MALLOC_HUGE:
    case VM_MEMORY_MALLOC_TINY:
    case VM_MEMORY_MALLOC_LARGE_REUSABLE:
    case VM_MEMORY_MALLOC_LARGE_REUSED:
    case VM_MEMORY_MALLOC_NANO:
    case VM_MEMORY_MALLOC_MEDIUM:
    case VM_MEMORY_MALLOC_PROB_GUARD:
        return "malloc zones";
    case VM_MEMORY_STACK:
        return "stacks";
    case VM_MEMORY_SHARED_PMAP:
        return "shared pmap";
    case VM_MEMORY_UNSHARED_PMAP:
        return "unshared pmap";
    case VM_MEMORY_FOUNDATION:
        return "Foundation";
    case VM_MEMORY_COREGRAPHICS:
    case VM_MEMORY_COREGRAPHICS_DATA:
    case VM_MEMORY_COREGRAPHICS_SHARED:
    case VM_MEMORY_COREGRAPHICS_FRAMEBUFFERS:
    case VM_MEMORY_COREGRAPHICS_BACKINGSTORES:
    case VM_MEMORY_COREGRAPHICS_XALLOC:
        return "CoreGraphics";
    case VM_MEMORY_CGIMAGE:
        return "CG images";
    case VM_MEMORY_LAYERKIT:
        return "CoreAnimation layers";
    case VM_MEMORY_IOSURFACE:
        return "IOSurface";
    case VM_MEMORY_IMAGEIO:
        return "ImageIO";
    case VM_MEMORY_COREIMAGE:
        return "CoreImage";
    case VM_MEMORY_COREUI_CACHED_IMAGE_DATA:
        return "CoreUI image cache";
    case VM_MEMORY_JAVASCRIPT_CORE:
        return "JavaScriptCore";
    case VM_MEMORY_JAVASCRIPT_JIT_EXECUTABLE_ALLOCATOR:
        return "JavaScript JIT";
    case VM_MEMORY_DYLD:
    case VM_MEMORY_DYLD_MALLOC:
        return "dyld";
    case VM_MEMORY_SQLITE:
        return "SQLite";
    case VM_MEMORY_LIBDISPATCH:
        return "libdispatch";
    case VM_MEMORY_IOKIT:
        return "IOKit";
    default:
        break;
    }
    return "tag " + std::to_string(tag);
}

// The address range of every loaded image, from its segments. The app is built for armv7 only, so the headers are 32-bit.
std::vector<RNHostImageRange> RNHostImageRanges()
{
    std::vector<RNHostImageRange> ranges;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (!header || header->magic != MH_MAGIC) {
            continue;
        }
        uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(i);
        std::string path = _dyld_get_image_name(i) ? _dyld_get_image_name(i) : "?";
        size_t slash = path.find_last_of('/');
        RNHostImageRange range = {UINTPTR_MAX, 0, slash == std::string::npos ? path : path.substr(slash + 1)};
        const struct load_command *command = (const struct load_command *)((const char *)header + sizeof(struct mach_header));
        for (uint32_t c = 0; c < header->ncmds && command->cmdsize > 0; c++) {
            if (command->cmd == LC_SEGMENT) {
                const struct segment_command *segment = (const struct segment_command *)command;
                // __PAGEZERO has no protection and maps nothing.
                if (segment->initprot != 0 && segment->vmsize > 0) {
                    uintptr_t start = (uintptr_t)segment->vmaddr + slide;
                    if (start < range.start) {
                        range.start = start;
                    }
                    if (start + segment->vmsize > range.end) {
                        range.end = start + segment->vmsize;
                    }
                }
            }
            command = (const struct load_command *)((const char *)command + command->cmdsize);
        }
        if (range.end > range.start) {
            ranges.push_back(range);
        }
    }
    return ranges;
}

} // namespace

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

// Diagnostics: walks the task's address space and logs the resident and dirty bytes of the top 15 regions, grouped by
// the image that maps them (image name) or else by their VM tag. Called only behind rnhost.log.on.
// Diagnostics: walks the layer tree under root and logs how many layers have contents, the bytes their contents take
// (estimated as bounds x scale^2 x 4), the classes that own the most, and the largest layers.
+ (void)logLayerCensus:(UIView *)root
{
    NSMutableArray<CALayer *> *stack = [NSMutableArray arrayWithObject:root.layer];
    NSUInteger layers = 0;
    NSUInteger withContents = 0;
    NSUInteger offscreen = 0;
    double contentBytes = 0;
    std::map<std::string, std::pair<NSUInteger, double>> byClass;
    std::vector<std::pair<double, std::string>> largest;
    while (stack.count > 0) {
        CALayer *layer = stack.lastObject;
        [stack removeLastObject];
        [stack addObjectsFromArray:layer.sublayers];
        layers++;
        if (layer.shouldRasterize || layer.mask || layer.shadowOpacity > 0) {
            offscreen++;
        }
        if (!layer.contents) {
            continue;
        }
        withContents++;
        CGFloat scale = layer.contentsScale;
        double bytes = layer.bounds.size.width * scale * layer.bounds.size.height * scale * 4;
        contentBytes += bytes;
        id owner = layer.delegate;
        NSString *name = [owner isKindOfClass:[UIView class]] ? NSStringFromClass([owner class]) : NSStringFromClass([layer class]);
        std::pair<NSUInteger, double> &entry = byClass[name.UTF8String];
        entry.first++;
        entry.second += bytes;
        NSString *described = [NSString stringWithFormat:@"%@ %.0fx%.0f at %.0fx", name, layer.bounds.size.width, layer.bounds.size.height, scale];
        largest.push_back(std::make_pair(bytes, std::string(described.UTF8String)));
    }
    NSLog(@"rn-host: layers %lu, with contents %lu, offscreen %lu, contents estimate %.1f MB",
          (unsigned long)layers, (unsigned long)withContents, (unsigned long)offscreen, contentBytes / 1048576.0);
    std::vector<std::pair<std::string, std::pair<NSUInteger, double>>> classes(byClass.begin(), byClass.end());
    std::sort(classes.begin(), classes.end(), [](const std::pair<std::string, std::pair<NSUInteger, double>> &a, const std::pair<std::string, std::pair<NSUInteger, double>> &b) {
        return a.second.second > b.second.second;
    });
    for (size_t i = 0; i < classes.size() && i < 8; i++) {
        NSLog(@"rn-host: layer class %s: %lu with contents, %.1f MB", classes[i].first.c_str(),
              (unsigned long)classes[i].second.first, classes[i].second.second / 1048576.0);
    }
    std::sort(largest.begin(), largest.end(), [](const std::pair<double, std::string> &a, const std::pair<double, std::string> &b) {
        return a.first > b.first;
    });
    for (size_t i = 0; i < largest.size() && i < 8; i++) {
        NSLog(@"rn-host: layer largest %zu: %s, %.2f MB", i + 1, largest[i].second.c_str(), largest[i].first / 1048576.0);
    }
}

+ (void)logMemoryMap
{
    std::vector<RNHostImageRange> images = RNHostImageRanges();
    std::map<std::string, RNHostMemoryBucket> buckets;
    vm_size_t page = getpagesize();
    uint64_t resident = 0;
    uint64_t dirtied = 0;
    uint64_t regions = 0;
    vm_address_t address = 0;
    natural_t depth = 0;
    for (;;) {
        vm_size_t size = 0;
        vm_region_submap_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(mach_task_self(), &address, &size, &depth, (vm_region_recurse_info_t)&info, &count) != KERN_SUCCESS || size == 0) {
            break;
        }
        if (info.is_submap) {
            depth++;
            continue;
        }
        regions++;
        std::string name;
        for (const RNHostImageRange &image : images) {
            if (address >= image.start && address < image.end) {
                name = "image " + image.name;
                break;
            }
        }
        if (name.empty()) {
            name = RNHostTagName(info.user_tag);
        }
        uint64_t regionResident = (uint64_t)info.pages_resident * page;
        uint64_t regionDirtied = (uint64_t)info.pages_dirtied * page;
        RNHostMemoryBucket &bucket = buckets[name];
        bucket.resident += regionResident;
        bucket.dirtied += regionDirtied;
        resident += regionResident;
        dirtied += regionDirtied;
        address += size;
    }
    NSLog(@"rn-host: memory map: %llu regions, resident %.1f MB (task rss %.1f MB), dirtied %.1f MB",
          (unsigned long long)regions, resident / 1048576.0, RNHostResidentMegabytes(), dirtied / 1048576.0);
    std::vector<std::pair<std::string, RNHostMemoryBucket>> ordered(buckets.begin(), buckets.end());
    uint64_t imagesResident = 0;
    for (const auto &entry : ordered) {
        if (entry.first.compare(0, 6, "image ") == 0) {
            imagesResident += entry.second.resident;
        }
    }
    NSLog(@"rn-host: memory map: images %.1f MB, everything else %.1f MB",
          imagesResident / 1048576.0, (resident - imagesResident) / 1048576.0);
    std::sort(ordered.begin(), ordered.end(), [](const std::pair<std::string, RNHostMemoryBucket> &a, const std::pair<std::string, RNHostMemoryBucket> &b) {
        return a.second.resident > b.second.resident;
    });
    for (size_t i = 0; i < ordered.size() && i < 15; i++) {
        NSLog(@"rn-host: memory map %2zu: %s resident %.1f MB, dirtied %.1f MB", i + 1, ordered[i].first.c_str(),
              ordered[i].second.resident / 1048576.0, ordered[i].second.dirtied / 1048576.0);
    }
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
