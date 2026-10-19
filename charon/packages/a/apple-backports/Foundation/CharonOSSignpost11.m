#import "CharonOSSignpost.h"
#import "CharonOSLog.h"
#import <objc/runtime.h>
#import <mach/mach_time.h>

// The four functions of signpost.h that a TU can call, and the store they record into. Everything else
// in that header is a macro over these, so carrying these four carries the whole family: the
// interval_begin / interval_end / event_emit macros, os_signpost_emit_with_type, and the
// _os_signpost_emit_with_name_impl shape the macros call.

@implementation CharonSignpostInterval

@synthesize name = _name;
@synthesize subsystem = _subsystem;
@synthesize category = _category;
@synthesize seconds = _seconds;
@synthesize count = _count;

@end

@implementation CharonSignpostStore

// The intervals, in the order they ended, and the begins still open keyed by their id.
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

// A monotonic reading, which is what an interval is a difference of. mach_absolute_time counts from the
// boot, and the timebase it counts in is one nanosecond on every release this port runs on; the
// conversion is done through the port's own log format, which already reads a monotonic clock.
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

// The subsystem and category of the handle a signpost was marked through. The handle is an os_log_t
// the port did not necessarily make - an application can hand it one this package did not create, and a
// host comparison hands it the host's own - so the cast is checked before the ivars are read. Reading
// CharonOSLog's ivars off a class that is not CharonOSLog is undefined, and the signpost differential
// found it: lldb put the fault in [NSString stringWithUTF8String:] called from this file's line 90,
// with the host's log object in hand.
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
    // The public field the mark carries, kept with the interval so that a snapshot and a signpost are
    // the same fact: the signpost the application marked points at the snapshot the metrics came from.
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
    // The open record carries the log's own subsystem and category, so an interval is attributed to
    // the handle that marked it - which is where an interval belongs when it is read back.
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

// The ids. OS_SIGNPOST_ID_NULL is zero and must never come back from a generate, so the counter starts
// at one and every value carries the high bit that distinguishes a generated id from a pointer's - the
// distinction signpost.h draws between the two id sources, and one the emit path below relies on.
// A generated id, and the one convention this port keeps about the two id sources. The header does
// NOT require it: os/signpost.h says a uint64_t "can be cast directly" if it uniquely identifies the
// begin/end pair, names only OS_SIGNPOST_ID_NULL and OS_SIGNPOST_ID_INVALID as reserved, and says a
// generated value "is guaranteed to be unique within the matching scope" - there is no high bit
// anywhere in it. The host does not set one either: measured twice, os_signpost_id_generate on the
// host's SensorKit answers 0x0000000000000001 with the bit clear.
//
// So the port follows the host and leaves the bit clear, and keeps the two sources apart the way the
// header's own description of them does - a generated id counts up from 1, a pointer's id IS the
// pointer, and the first two reserved values are never returned. A test reads the host's answer and
// the port's and requires them to agree; see tests/backports/host/signpost.
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

// The header says what this does and does not promise, and the M-Z review's measurement agrees with it:
//
//   The header says the pointer is mangled into a valid os_signpost_id, with address randomization removed.
//   Its result is a valid os_signpost_id_t, OS_SIGNPOST_ID_NULL when signposts are turned off, and
//   OS_SIGNPOST_ID_INVALID when the log handle is system-scoped.
//
// So the value is NOT the pointer - the host's own round trip fails, and it is meant to - and a NULL
// pointer is not one of the two documented failures. The port therefore mangles the address the only way
// it can, which is honestly: it clears the low three bits, where an arm64 malloc never puts anything
// (the tag Apple's own allocator writes), and ORs in the port's own bit so the value cannot be mistaken
// for a generated id. What the header does promise, and what the port gives, is a valid id that is
// stable for the same pointer and never one of the two reserved values, which is what
// "any pointer that disambiguates among concurrent intervals" needs.
os_signpost_id_t os_signpost_id_make_with_pointer(os_log_t log, const void *ptr)
{
    uintptr_t address = (uintptr_t)ptr;
    return (os_signpost_id_t)((address & ~(uintptr_t)7) | (1ull << 2));
}

bool os_signpost_enabled(os_log_t log)
{
    // A signpost is a developer mark, and the port's log records everything it is handed at fault and
    // above and keeps every signpost interval, so a mark is always worth making. Returning true is
    // also what the macros above us: with this false, os_signpost_emit_with_type would compile the
    // format away and nothing would ever be recorded.
    return true;
}
