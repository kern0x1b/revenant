#import "RevenantOSSignpost.h"
#import "RevenantOSLog.h"
#import <objc/runtime.h>
#import <mach/mach_time.h>

@implementation RevenantSignpostInterval

@synthesize name = _name;
@synthesize subsystem = _subsystem;
@synthesize category = _category;
@synthesize seconds = _seconds;
@synthesize count = _count;

@end

@implementation RevenantSignpostStore

static NSMutableArray<RevenantSignpostInterval *> *revenant_intervals(void)
{
    static NSMutableArray *intervals;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        intervals = [NSMutableArray array];
    });
    return intervals;
}

static NSMutableDictionary<NSNumber *, NSMutableDictionary *> *revenant_open(void)
{
    static NSMutableDictionary *open;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        open = [NSMutableDictionary dictionary];
    });
    return open;
}

static NSTimeInterval revenant_monotonic(void)
{
    static mach_timebase_info_data_t info;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mach_timebase_info(&info);
    });
    uint64_t now = mach_absolute_time();
    long double seconds = ((long double)now * info.numer) / (long double)info.denom / 1e9L;
    return (NSTimeInterval)seconds;
}

static void revenant_handleNames(os_log_t log, NSString **subsystem, NSString **category)
{
    id handle = (REVENANT_OS_LOG_BRIDGE id)log;
    RevenantOSLog *own = [handle isKindOfClass:[RevenantOSLog class]] ? (RevenantOSLog *)handle : nil;
    *subsystem = own && own->_subsystem ? @(own->_subsystem) : @"";
    *category = own && own->_category ? @(own->_category) : @"";
}

static RevenantSignpostInterval *revenant_begin_record(NSDictionary *begin, const char *name)
{
    RevenantSignpostInterval *interval = [[RevenantSignpostInterval alloc] init];
    interval.name = name && *name ? @(name) : @"";
    interval.subsystem = begin[@"subsystem"] ?: @"";
    interval.category = begin[@"category"] ?: @"";
    interval.seconds = 0.0;
    interval.count = 1;
    return interval;
}

+ (void)takePointer:(void *)pointer forInterval:(RevenantSignpostInterval *)interval
{
    objc_setAssociatedObject(interval, @selector(RevenantSignpostSnapshot), (__bridge id)pointer, OBJC_ASSOCIATION_ASSIGN);
}

+ (NSArray<RevenantSignpostInterval *> *)intervals
{
    @synchronized (revenant_intervals()) {
        return [revenant_intervals() copy];
    }
}

+ (void)recordBeginFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSString *subsystem = nil, *category = nil;
    revenant_handleNames(log, &subsystem, &category);
    NSMutableDictionary *begin = [NSMutableDictionary dictionary];
    begin[@"subsystem"] = subsystem;
    begin[@"category"] = category;
    begin[@"at"] = @(revenant_monotonic());
    begin[@"name"] = name && *name ? @(name) : @"";
    @synchronized (revenant_open()) {
        revenant_open()[@(spid)] = begin;
    }
}

+ (void)recordEndFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSDictionary *begin = nil;
    @synchronized (revenant_open()) {
        begin = revenant_open()[@(spid)];
        if (begin)
            [revenant_open() removeObjectForKey:@(spid)];
    }
    if (!begin)
        return;
    RevenantSignpostInterval *interval = revenant_begin_record(begin, [begin[@"name"] UTF8String]);
    interval.seconds = revenant_monotonic() - [begin[@"at"] doubleValue];
    interval.name = name && *name ? @(name) : interval.name;
    @synchronized (revenant_intervals()) {
        [revenant_intervals() addObject:interval];
    }
}

+ (void)recordEventFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSString *subsystem = nil, *category = nil;
    revenant_handleNames(log, &subsystem, &category);
    NSDictionary *begin = @{ @"subsystem": subsystem, @"category": category };
    RevenantSignpostInterval *event = revenant_begin_record(begin, name);
    event.seconds = 0.0;
    event.count = 1;
    @synchronized (revenant_intervals()) {
        [revenant_intervals() addObject:event];
    }
}

+ (void)reset
{
    @synchronized (revenant_open()) {
        [revenant_open() removeAllObjects];
    }
    @synchronized (revenant_intervals()) {
        [revenant_intervals() removeAllObjects];
    }
}

@end

static os_signpost_id_t revenant_next_id(void)
{
    static uint64_t counter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        counter = 1;
    });
    uint64_t value;
    @synchronized ([RevenantSignpostStore class]) {
        value = counter++;
    }
    return (os_signpost_id_t)value;
}

os_signpost_id_t os_signpost_id_generate(os_log_t log)
{
    return revenant_next_id();
}

os_signpost_id_t os_signpost_id_make_with_pointer(os_log_t log, const void *ptr)
{
    uintptr_t address = (uintptr_t)ptr;
    return (os_signpost_id_t)((address & ~(uintptr_t)7) | (1ull << 2));
}

bool os_signpost_enabled(os_log_t log)
{
    return true;
}
