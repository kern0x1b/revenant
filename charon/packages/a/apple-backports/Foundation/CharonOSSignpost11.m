#import "CharonOSSignpost.h"
#import "CharonOSLog.h"
#import <objc/runtime.h>
#import <mach/mach_time.h>

@implementation CharonSignpostInterval

@synthesize name = _name;
@synthesize subsystem = _subsystem;
@synthesize category = _category;
@synthesize seconds = _seconds;
@synthesize count = _count;

@end

@implementation CharonSignpostStore

static NSMutableArray<CharonSignpostInterval *> *charon_intervals(void)
{
    static NSMutableArray *intervals;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        intervals = [NSMutableArray array];
    });
    return intervals;
}

static NSMutableDictionary<NSNumber *, NSMutableDictionary *> *charon_open(void)
{
    static NSMutableDictionary *open;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        open = [NSMutableDictionary dictionary];
    });
    return open;
}

static NSTimeInterval charon_monotonic(void)
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

static void charon_handleNames(os_log_t log, NSString **subsystem, NSString **category)
{
    id handle = (CHARON_OS_LOG_BRIDGE id)log;
    CharonOSLog *own = [handle isKindOfClass:[CharonOSLog class]] ? (CharonOSLog *)handle : nil;
    *subsystem = own && own->_subsystem ? @(own->_subsystem) : @"";
    *category = own && own->_category ? @(own->_category) : @"";
}

static CharonSignpostInterval *charon_begin_record(NSDictionary *begin, const char *name)
{
    CharonSignpostInterval *interval = [[CharonSignpostInterval alloc] init];
    interval.name = name && *name ? @(name) : @"";
    interval.subsystem = begin[@"subsystem"] ?: @"";
    interval.category = begin[@"category"] ?: @"";
    interval.seconds = 0.0;
    interval.count = 1;
    return interval;
}

+ (void)takePointer:(void *)pointer forInterval:(CharonSignpostInterval *)interval
{
    objc_setAssociatedObject(interval, @selector(CharonSignpostSnapshot), (__bridge id)pointer, OBJC_ASSOCIATION_ASSIGN);
}

+ (NSArray<CharonSignpostInterval *> *)intervals
{
    @synchronized (charon_intervals()) {
        return [charon_intervals() copy];
    }
}

+ (void)recordBeginFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSString *subsystem = nil, *category = nil;
    charon_handleNames(log, &subsystem, &category);
    NSMutableDictionary *begin = [NSMutableDictionary dictionary];
    begin[@"subsystem"] = subsystem;
    begin[@"category"] = category;
    begin[@"at"] = @(charon_monotonic());
    begin[@"name"] = name && *name ? @(name) : @"";
    @synchronized (charon_open()) {
        charon_open()[@(spid)] = begin;
    }
}

+ (void)recordEndFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSDictionary *begin = nil;
    @synchronized (charon_open()) {
        begin = charon_open()[@(spid)];
        if (begin)
            [charon_open() removeObjectForKey:@(spid)];
    }
    if (!begin)
        return;
    CharonSignpostInterval *interval = charon_begin_record(begin, [begin[@"name"] UTF8String]);
    interval.seconds = charon_monotonic() - [begin[@"at"] doubleValue];
    interval.name = name && *name ? @(name) : interval.name;
    @synchronized (charon_intervals()) {
        [charon_intervals() addObject:interval];
    }
}

+ (void)recordEventFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name
{
    NSString *subsystem = nil, *category = nil;
    charon_handleNames(log, &subsystem, &category);
    NSDictionary *begin = @{ @"subsystem": subsystem, @"category": category };
    CharonSignpostInterval *event = charon_begin_record(begin, name);
    event.seconds = 0.0;
    event.count = 1;
    @synchronized (charon_intervals()) {
        [charon_intervals() addObject:event];
    }
}

+ (void)reset
{
    @synchronized (charon_open()) {
        [charon_open() removeAllObjects];
    }
    @synchronized (charon_intervals()) {
        [charon_intervals() removeAllObjects];
    }
}

@end

static os_signpost_id_t charon_next_id(void)
{
    static uint64_t counter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        counter = 1;
    });
    uint64_t value;
    @synchronized ([CharonSignpostStore class]) {
        value = counter++;
    }
    return (os_signpost_id_t)value;
}

os_signpost_id_t os_signpost_id_generate(os_log_t log)
{
    return charon_next_id();
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
