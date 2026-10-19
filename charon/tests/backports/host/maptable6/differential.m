#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <unistd.h>
#import "check.h"

// The port's four factories (renamed charonHost_*) against the host's own, driven the same way side by side.

@interface NSMapTable (CharonHostObjects6)
+ (instancetype)charonHost_weakToStrongObjectsMapTable;
+ (instancetype)charonHost_strongToWeakObjectsMapTable;
+ (instancetype)charonHost_weakToWeakObjectsMapTable;
+ (instancetype)charonHost_strongToStrongObjectsMapTable;
@end

// Reads an archived NSMapTable in the order 6.0 writes it (xmake emulate): the key and value options, unkeyed, then
// each key and value, then nil. A later host also writes "NS.count", which this does not read.
@interface CharonHostArchivedTable : NSObject <NSCoding>
@property (nonatomic, readonly) NSString *fields;
@property (nonatomic, readonly) BOOL later;
@end

@implementation CharonHostArchivedTable

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _later = [coder containsValueForKey:@"NS.count"];
        NSUInteger keyOptions = 0, valueOptions = 0;
        [coder decodeValueOfObjCType:@encode(NSUInteger) at:&keyOptions];
        [coder decodeValueOfObjCType:@encode(NSUInteger) at:&valueOptions];
        NSMutableArray *read = [NSMutableArray arrayWithObjects:@(keyOptions), @(valueOptions), nil];
        for (id object = [coder decodeObject]; object; object = [coder decodeObject])
            [read addObject:object];
        _fields = [read componentsJoinedByString:@" "];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

static const char *label(const char *side, const char *what)
{
    return [NSString stringWithFormat:@"%s %s", side, what].UTF8String;
}

// A value a scenario puts in a table that holds its values weakly is kept alive by the scenario, unless the scenario is
// about a value going: the numbers a literal makes are not the same object on every release.
static NSMutableArray *pinned;

static id V(int number)
{
    id value = @(number);
    [pinned addObject:value];
    return value;
}

// What a table answers after a scenario, as one comparable string.
static NSString *outcome(void (^scenario)(NSMutableArray *said))
{
    pinned = [NSMutableArray array];
    NSMutableArray *said = [NSMutableArray array];
    @try {
        scenario(said);
    } @catch (NSException *exception) {
        [said addObject:[NSString stringWithFormat:@"raised %@", exception.name]];
    }
    return [said componentsJoinedByString:@", "];
}

static NSArray *sorted(id<NSFastEnumeration> keys)
{
    NSMutableArray *all = [NSMutableArray array];
    for (id key in keys)
        [all addObject:[key description]];
    return [all sortedArrayUsingSelector:@selector(compare:)];
}

static void weak_checks(const char *variant, NSMapTable *(^make)(void), NSMapTable *(^host)(void))
{
    struct {
        const char *name;
        void (^run)(NSMapTable *table, NSMutableArray *said);
    } scenarios[] = {
        {"live keys", ^(NSMapTable *table, NSMutableArray *said) {
            NSString *a = [NSMutableString stringWithString:@"a"], *b = [NSMutableString stringWithString:@"b"];
            [table setObject:V(1) forKey:a];
            [table setObject:V(2) forKey:b];
            [said addObject:@([table count])];
            [said addObject:[table objectForKey:[NSMutableString stringWithString:@"a"]] ?: @"nil"];
            [said addObject:[table objectForKey:@"c"] ?: @"nil"];
            [said addObject:[sorted(table) componentsJoinedByString:@"/"]];
            [said addObject:[sorted([table keyEnumerator]) componentsJoinedByString:@"/"]];
            [said addObject:[[[table objectEnumerator] allObjects] valueForKeyPath:@"@sum.self"]];
            [said addObject:@([[table dictionaryRepresentation] count])];
        }},
        {"equal key keeps the first", ^(NSMapTable *table, NSMutableArray *said) {
            NSString *first = [NSMutableString stringWithString:@"k"], *second = [NSMutableString stringWithString:@"k"];
            [table setObject:V(1) forKey:first];
            [table setObject:V(2) forKey:second];
            [said addObject:@([table count])];
            [said addObject:[table objectForKey:first]];
            id kept = [[table keyEnumerator] nextObject];
            [said addObject:kept == first ? @"first" : kept == second ? @"second" : @"other"];
        }},
        {"a key is not retained and its entry goes with it", ^(NSMapTable *table, NSMutableArray *said) {
            __weak id watchedKey;
            id survivor = [NSObject new];
            @autoreleasepool {
                id key = [NSObject new], value = [NSObject new];
                watchedKey = key;
                [table setObject:value forKey:key];
                [table setObject:@"kept" forKey:survivor];
                [said addObject:@([table count])];
            }
            [said addObject:watchedKey ? @"key alive" : @"key gone"];
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
            [said addObject:[table objectForKey:survivor]];
            NSUInteger enumerated = 0;
            for (id key in table)
                enumerated += key == survivor;
            [said addObject:@(enumerated)];
        }},
        {"a string key goes with its entry", ^(NSMapTable *table, NSMutableArray *said) {
            @autoreleasepool {
                id key = [NSMutableString stringWithFormat:@"key %d", 1], value = [NSObject new];
                [table setObject:value forKey:key];
                [said addObject:[table objectForKey:[NSMutableString stringWithFormat:@"key %d", 1]] ? @"found" : @"not found"];
            }
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
            [said addObject:@([[[table objectEnumerator] allObjects] count])];
            [said addObject:[table objectForKey:@"key 1"] ? @"found" : @"not found"];
        }},
        {"a number key goes with its entry", ^(NSMapTable *table, NSMutableArray *said) {
            @autoreleasepool {
                [table setObject:@"v" forKey:[NSNumber numberWithDouble:12345.678]];
            }
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
        }},
        {"a value is retained", ^(NSMapTable *table, NSMutableArray *said) {
            id key = [NSObject new];
            __weak id watched;
            @autoreleasepool {
                id value = [NSObject new];
                watched = value;
                [table setObject:value forKey:key];
            }
            [said addObject:watched ? @"value alive" : @"value gone"];
            [table removeObjectForKey:key];
            [said addObject:watched ? @"value alive" : @"value gone"];
            [said addObject:@([table count])];
        }},
        {"remove", ^(NSMapTable *table, NSMutableArray *said) {
            for (int i = 0; i < 20; i++)
                [table setObject:V(i) forKey:[NSString stringWithFormat:@"%d", i]];
            [table removeObjectForKey:@"3"];
            [table removeObjectForKey:@"absent"];
            [said addObject:@([table count])];
            [said addObject:[table objectForKey:@"3"] ?: @"nil"];
            [table removeAllObjects];
            [said addObject:@([table count])];
        }},
        {"changed while enumerated", ^(NSMapTable *table, NSMutableArray *said) {
            [table setObject:V(1) forKey:@"x"];
            [table setObject:V(2) forKey:@"y"];
            for (id key in table)
                [table setObject:key forKey:@"z"];
            [said addObject:@"not raised"];
        }},
        {"nested enumeration, and a key going during one", ^(NSMapTable *table, NSMutableArray *said) {
            for (int i = 0; i < 3; i++)
                [table setObject:V(i) forKey:[NSString stringWithFormat:@"k%d", i]];
            NSUInteger pairs = 0;
            for (id outer in table)
                for (id inner in table)
                    pairs += outer && inner;
            [said addObject:@(pairs)];
            @autoreleasepool {
                [table setObject:@"short" forKey:[NSMutableString stringWithFormat:@"gone %d", 1]];
            }
            NSUInteger seen = 0;
            for (id key in table)
                seen += key != nil;
            [said addObject:@(seen)];
        }},
        {"copy", ^(NSMapTable *table, NSMutableArray *said) {
            id key = [NSObject new];
            [table setObject:V(1) forKey:key];
            NSMapTable *copy = [table copy];
            [copy setObject:V(2) forKey:@"only in the copy"];
            [said addObject:@([copy isKindOfClass:[NSMapTable class]])];
            [said addObject:@([table count])];
            [said addObject:@([copy count])];
            [said addObject:[copy objectForKey:key]];
        }},
        {"nil value", ^(NSMapTable *table, NSMutableArray *said) {
            [table setObject:V(1) forKey:@"k"];
            [table setObject:nil forKey:@"k"];
            [said addObject:@([table count])];
            [said addObject:[table objectForKey:@"k"] ?: @"nil"];
        }},
        {"nil key", ^(NSMapTable *table, NSMutableArray *said) {
            [table setObject:V(1) forKey:nil];
            [said addObject:@([table count])];
            [said addObject:[table objectForKey:nil] ?: @"nil"];
            [table removeObjectForKey:nil];
            [said addObject:@([table count])];
        }},
        {"a value goes with its entry, or is replaced", ^(NSMapTable *table, NSMutableArray *said) {
            id kept = [NSMutableString stringWithString:@"kept"], replaced = [NSMutableString stringWithString:@"replaced"];
            @autoreleasepool {
                [table setObject:[NSObject new] forKey:kept];
            }
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
            [said addObject:[table objectForKey:kept] ? @"found" : @"not found"];
            [said addObject:@([[[table objectEnumerator] allObjects] count])];
            id second = [NSObject new];
            @autoreleasepool {
                id first = [NSObject new];
                [table setObject:first forKey:replaced];
                [table setObject:second forKey:replaced];
            }
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
            [said addObject:[table objectForKey:replaced] == second ? @"second" : @"other"];
            [table removeObjectForKey:replaced];
            [said addObject:@([[[table keyEnumerator] allObjects] count])];
        }},
        {"pointer functions", ^(NSMapTable *table, NSMutableArray *said) {
            NSPointerFunctions *keys = [table keyPointerFunctions], *values = [table valuePointerFunctions];
            [said addObject:@(keys.usesWeakReadAndWriteBarriers)];
            [said addObject:@(keys.usesStrongWriteBarrier)];
            [said addObject:@(values.usesWeakReadAndWriteBarriers)];
            [said addObject:@(values.usesStrongWriteBarrier)];
            [said addObject:@(keys.acquireFunction == NULL)];
            [said addObject:@(values.acquireFunction == NULL)];
        }},
    };
    for (unsigned i = 0; i < sizeof scenarios / sizeof *scenarios; i++) {
        void (^run)(NSMapTable *, NSMutableArray *) = scenarios[i].run;
        NSString *ours = outcome(^(NSMutableArray *said) { run(make(), said); });
        printf("port %s %s: %s\n", variant, scenarios[i].name, ours.UTF8String);
        // A release before 6.0 has no table of its own to set beside the port: its answers are compared with 6.0's.
        if (!host)
            continue;
        NSString *theirs = outcome(^(NSMutableArray *said) { run(host(), said); });
        printf("release %s %s: %s\n", variant, scenarios[i].name, theirs.UTF8String);
        charon_check([ours isEqual:theirs], label(variant, scenarios[i].name), [NSString stringWithFormat:@"%@ != %@", ours, theirs]);
    }
}

static CharonHostArchivedTable *archived(NSMapTable *table)
{
    [table setObject:@"v" forKey:@"k"];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSKeyedArchiver archivedDataWithRootObject:table]];
    [unarchiver setClass:[CharonHostArchivedTable class] forClassName:@"NSMapTable"];
    // "root": where 6.0's archive holds its top object ($top), NSKeyedArchiveRootObjectKey being iOS 10.
    return [unarchiver decodeObjectForKey:@"root"];
}

// The port archives as 6.0 does: the same fields as the release's own where the release writes 6.0's format, and 6.0's
// measured order (the key options, the value options, key, value) where a later host writes its own, with "NS.count".
static void archive_checks(const char *variant, NSMapTable *ours, NSMapTable *theirs, NSString *fields)
{
    CharonHostArchivedTable *port = archived(ours), *release = theirs ? archived(theirs) : nil;
    CHECK([port isKindOfClass:[CharonHostArchivedTable class]], label(variant, "port archives as NSMapTable"));
    if (release && !release.later)
        CHECK_EQUAL(port.fields, release.fields, label(variant, "port archives as the release does"));
    else
        CHECK_EQUAL(port.fields, fields, label(variant, "port archives in 6.0's order"));
    if (release.later)
        CHECK(!port.later, label(variant, "a later host writes NS.count, which 6.0 does not"));
}

// A known divergence, held so that the test fails if it ever stops diverging: after a key or a value goes the release's
// table still counts its entry, and keeps what it holds, until it next grows (host, and 6.0 under xmake emulate); the
// port forgets the entry before it answers. What goes is a key where the table holds keys weakly, else a value.
static void count_after_death(const char *variant, BOOL weakKeys, NSMapTable *ours, NSMapTable *theirs)
{
    pinned = [NSMutableArray array];
    for (NSMapTable *table in theirs ? @[ours, theirs] : @[ours]) {
        for (int i = 0; i < 3; i++)
            [table setObject:V(i) forKey:[NSString stringWithFormat:@"k%d", i]];
        @autoreleasepool {
            if (weakKeys)
                [table setObject:@"short" forKey:[NSMutableString stringWithFormat:@"gone %d", 1]];
            else
                [table setObject:[NSMutableString stringWithFormat:@"gone %d", 1] forKey:@"short"];
        }
    }
    CHECK_EQUAL(@([ours count]), @3, label(variant, "port counts only live entries after a side goes"));
    if (theirs)
        CHECK_EQUAL(@([theirs count]), @4, label(variant, "release still counts a dead entry until it grows"));
}

// The same divergence for what the entry held: the side that stays is let go of by the port when the other goes, and kept
// by the release until the table grows. Only where one side is held.
static BOOL keeps_held_side(BOOL weakKeys, NSMapTable *table)
{
    __weak id held;
    @autoreleasepool {
        id heldObject = [NSObject new], goes = [NSObject new];
        held = heldObject;
        if (weakKeys)
            [table setObject:heldObject forKey:goes];
        else
            [table setObject:goes forKey:heldObject];
    }
    (void)[table count];
    return held != nil;
}

static void held_side_checks(const char *variant, BOOL weakKeys, NSMapTable *ours, NSMapTable *theirs)
{
    CHECK(!keeps_held_side(weakKeys, ours), label(variant, "port lets go of what an entry held when its other side goes"));
    if (theirs)
        CHECK(keeps_held_side(weakKeys, theirs), label(variant, "release keeps it until the table grows"));
}

// What the port does with the watches it leaves on objects, and how much work a table's reads take, are read from the
// port's own classes: the watches alive (made less gone) and the calls of an entry's -key.
static long watches_made, watches_gone, key_calls;

// The wrappers return a raw pointer, not an object: an object returned from a block under ARC is retained and
// autoreleased, which keeps every watch and every key the hooks see alive until the pool drains.
static void count_calls(Class cls, SEL selector, void (^count)(void))
{
    IMP original = method_getImplementation(class_getInstanceMethod(cls, selector));
    if (selector == @selector(init)) {
        // -init is NSObject's; the class gets its own, calling NSObject's.
        IMP counted = imp_implementationWithBlock(^void *(__unsafe_unretained id object) {
            count();
            return ((void *(*)(id, SEL))original)(object, selector);
        });
        class_addMethod(cls, selector, counted, "@@:");
    } else if (selector == NSSelectorFromString(@"dealloc")) {
        method_setImplementation(class_getInstanceMethod(cls, selector), imp_implementationWithBlock(^(__unsafe_unretained id object) {
            count();
            ((void (*)(id, SEL))original)(object, selector);
        }));
    } else {
        method_setImplementation(class_getInstanceMethod(cls, selector), imp_implementationWithBlock(^void *(__unsafe_unretained id object) {
            count();
            return ((void *(*)(id, SEL))original)(object, selector);
        }));
    }
}

static long live_watches(void)
{
    return watches_made - watches_gone;
}

// A key that lives on carries a watch for each entry of a live table it is in, and none for an entry that has gone from
// its table: taken out, or the table discarded, or emptied.
static void watch_checks(const char *variant, NSMapTable *(^make)(void), long perEntry)
{
    id key = [NSObject new];
    NSMapTable *table = make(), *other = make();
    long base = live_watches();
    for (int i = 0; i < 1000; i++) {
        [table setObject:@"v" forKey:key];
        [table removeObjectForKey:key];
    }
    CHECK_EQUAL(@(live_watches() - base), @0, label(variant, "a key set and removed 1000 times carries no watch"));
    [table setObject:@"v" forKey:key];
    [table setObject:@"w" forKey:key];
    CHECK_EQUAL(@(live_watches() - base), @(perEntry), label(variant, "one watch a side for a key and table"));
    [other setObject:@"v" forKey:key];
    CHECK_EQUAL(@(live_watches() - base), @(2 * perEntry), label(variant, "and one for each table the key is in"));
    [table removeAllObjects];
    CHECK_EQUAL(@(live_watches() - base), @(perEntry), label(variant, "removeAllObjects takes them off"));
    NSMutableArray *keys = [NSMutableArray array];
    @autoreleasepool {
        NSMapTable *discarded = make();
        for (int i = 0; i < 100; i++) {
            [keys addObject:[NSObject new]];
            [discarded setObject:@"v" forKey:keys.lastObject];
        }
        CHECK_EQUAL(@(live_watches() - base), @(101 * perEntry), label(variant, "a hundred keys, a hundred watches"));
    }
    CHECK_EQUAL(@(live_watches() - base), @(perEntry), label(variant, "a discarded table leaves none on its live keys"));
    [keys removeAllObjects];
    CHECK_EQUAL(@(live_watches() - base), @(perEntry), label(variant, "the keys that go take their watches with them"));
}

// Building a table of n keys, and forgetting n keys that went, takes work in n, not in n squared: an entry's key is read
// a few times an entry, where a scan of every entry on every call reads it n * n times.
static void cost_checks(const char *variant, BOOL weakKeys, NSMapTable *(^make)(void))
{
    const int n = 1000;
    NSMapTable *table = make();
    NSMutableArray *keys = [NSMutableArray array];
    key_calls = 0;
    for (int i = 0; i < n; i++) {
        [keys addObject:[NSObject new]];
        [table setObject:@"v" forKey:keys.lastObject];
    }
    CHECK_EQUAL(@([table count]), @(n), label(variant, "a thousand keys in"));
    charon_check(key_calls < 20 * n, label(variant, "building a table of n keys reads entries a few times each"),
                 [NSString stringWithFormat:@"%ld reads of an entry's key for %d keys", key_calls, n]);
    NSMapTable *dying = make();
    NSMutableArray *held = [NSMutableArray array];
    @autoreleasepool {
        for (int i = 0; i < n; i++) {
            if (weakKeys)
                [dying setObject:@"v" forKey:[NSObject new]];
            else {
                [held addObject:[NSObject new]];
                [dying setObject:[NSObject new] forKey:held.lastObject];
            }
        }
    }
    key_calls = 0;
    CHECK_EQUAL(@([dying count]), @0, label(variant, "a thousand keys gone"));
    CHECK(key_calls < 20 * n, label(variant, "forgetting n keys that went reads entries a few times each"));
}

// The owner thread of a table against the deaths of its sides on other threads, the one thing the port's lock and queue
// are for: keys and values are dropped by blocks on a concurrent queue, that never read the table, while the owner adds
// entries and asks -count and a live key's value. Only what a table claims is asked: nothing reads a key that is dying.
// It must finish, answer for the live key every time, and end with the live entry alone.
#ifndef THREAD_ROUNDS
#define THREAD_ROUNDS 20000
#endif
static void thread_checks(const char *variant, BOOL port, NSMapTable *(^make)(void))
{
    const long n = THREAD_ROUNDS;
    NSMapTable *table = make();
    id live = [NSObject new], liveValue = [NSObject new];
    [table setObject:liveValue forKey:live];
    dispatch_queue_t queue = dispatch_queue_create("maptable6.release", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    BOOL answered = YES;
    for (long i = 0; i < n; i++) {
        @autoreleasepool {
            NSObject *key = [NSObject new], *value = [NSObject new];
            [table setObject:value forKey:key];
            dispatch_group_async(group, queue, ^{
                (void)key;
                (void)value;
                usleep(i % 3);
            });
            if (i % 16 == 0) {
                (void)[table count];
                answered = answered && [table objectForKey:live] == liveValue;
            }
        }
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CHECK(answered, label(variant, "a live key answers its value while others die on other threads"));
    // The release keeps counting an entry that has gone until it grows (above), so what it enumerates is what is asked.
    CHECK_EQUAL(@(port ? [table count] : [[[table keyEnumerator] allObjects] count]), @1,
                label(variant, "and once they have gone the live entry is alone"));
}

// Whether the release has weak references of its own (5.0 and later), from its Foundation version, not from the port:
// which of the port's two paths a release takes is checked against this, and the checks that need the runtime's weak
// references run where this answers YES. 881.0 is NSFoundationVersionNumber of 5.0 (4.3 is 751.x).
static BOOL release_has_weak(void)
{
    return NSFoundationVersionNumber >= 881.0;
}

static BOOL ivar_flag(id object, const char *name)
{
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    return *(BOOL *)((char *)(__bridge void *)object + ivar_getOffset(ivar));
}

// The port's own choice of path for a weak side, read from its entry: through the runtime's weak reference where the
// release has one, the watch alone where it has none. A release that answers otherwise (a lookup that finds a function
// where there is none, or none where there is) fails here, before the calls the path makes safe are tried.
static void path_checks(const char *variant, BOOL weakKeys, BOOL weakValues, NSMapTable *table)
{
    id key = [NSObject new], value = [NSObject new];
    [table setObject:value forKey:key];
    id entry = [object_getIvar(table, class_getInstanceVariable(object_getClass(table), "_entries")) anyObject];
    BOOL native = release_has_weak();
    CHECK(entry != nil, label(variant, "an entry to read the path from"));
    if (weakKeys)
        CHECK_EQUAL(@(ivar_flag(entry, "_nativeKey")), @(native),
                    label(variant, native ? "a weak key is read through the runtime's weak reference" : "a weak key is watched only"));
    if (weakValues)
        CHECK_EQUAL(@(ivar_flag(entry, "_nativeValue")), @(native),
                    label(variant, native ? "a weak value is read through the runtime's weak reference" : "a weak value is watched only"));
}

// A key or a value of the kinds that keep their own retain count and that a table is really given: a mutable string, then
// a number too large for a tagged pointer.
static id enumerated_object(int kind, long i, const char *tag)
{
    if (kind == 0)
        return [NSMutableString stringWithFormat:@"%s%ld", tag, i];
    return [NSNumber numberWithUnsignedLongLong:ULLONG_MAX - 2 * (unsigned long long)i - (tag[0] == 'v')];
}

// The calls that read every entry's key - the enumerators, -copy - while the keys and values go on other threads, which
// the watch alone does not survive (4.3: the contract of the facts), and the runtime's weak references do. It runs where
// the release has them, and says so where it does not. The owner reads each key it is handed (-hash) and takes -copy; the
// live entry must be in every enumeration and every copy, and alone at the end.
static void enumeration_checks(const char *variant, BOOL port, NSMapTable *(^make)(void))
{
    if (!release_has_weak()) {
        printf("skip %s: the calls that read every entry's key are not held before 5.0 (coordination/crutches.md)\n", variant);
        return;
    }
    const long n = THREAD_ROUNDS;
    NSMapTable *table = make();
    id live = [NSObject new], liveValue = [NSObject new];
    [table setObject:liveValue forKey:live];
    dispatch_queue_t queue = dispatch_queue_create("maptable6.enumerate", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    BOOL whole = YES;
    long seen = 0;
    for (int kind = 0; kind < 2; kind++) {
        for (long i = 0; i < n; i++) {
            @autoreleasepool {
                id key = enumerated_object(kind, i, "k"), value = enumerated_object(kind, i, "v");
                [table setObject:value forKey:key];
                dispatch_group_async(group, queue, ^{
                    (void)key;
                    (void)value;
                    usleep(i % 3);
                });
                if (i % 16 == 0) {
                    BOOL sawLive = NO;
                    for (id each in [table keyEnumerator]) {
                        seen++;
                        sawLive = sawLive || each == live;
                        (void)[each hash];
                    }
                    NSMapTable *copy = [table copy];
                    whole = whole && sawLive && [copy objectForKey:live] == liveValue;
                }
            }
        }
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CHECK(seen > 0, label(variant, "keys were enumerated meanwhile"));
    CHECK(whole, label(variant, "every enumeration and copy meanwhile held the live entry"));
    CHECK_EQUAL(@(port ? [table count] : [[[table keyEnumerator] allObjects] count]), @1,
                label(variant, "and after the enumerations the live entry is alone"));
}

// A class that refuses a weak reference to its instances, as the weak side of a table: what a release does with it is its
// own answer (6.0 aborts: "cannot form weak reference"), and the port must give the same one where the release has weak
// references. An abort ends the process, so each case is a run of its own, asked for by argument:
//     maptable6 theirs|port weakToStrong|strongToWeak|weakToWeak|strongToStrong key|value
// and emulate.sh compares the outcomes. strongToStrong is the control: the class alone is not what aborts.
@interface CharonHostRefusesWeak : NSObject
@end

@implementation CharonHostRefusesWeak
- (BOOL)allowsWeakReference
{
    return NO;
}
@end

static int refusal(const char *who, const char *variant, const char *side)
{
    BOOL port = strcmp(who, "port") == 0, key = strcmp(side, "key") == 0;
    NSString *selector = [NSString stringWithFormat:port ? @"charonHost_%sObjectsMapTable" : @"%sObjectsMapTable", variant];
    if (![NSMapTable respondsToSelector:NSSelectorFromString(selector)]) {
        printf("outcome %s %s %s: no such factory\n", who, variant, side);
        return 0;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSMapTable *table = [NSMapTable performSelector:NSSelectorFromString(selector)];
#pragma clang diagnostic pop
    id refuses = [CharonHostRefusesWeak new], other = [NSObject new];
    printf("outcome %s %s %s: ", who, variant, side);
    fflush(stdout);
    [table setObject:key ? other : refuses forKey:key ? refuses : other];
    id found = [table objectForKey:key ? refuses : other];
    printf("held, count %lu, lookup %s\n", (unsigned long)[table count], found == (key ? other : refuses) ? "found" : "nil");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 4) {
        @autoreleasepool {
            return refusal(argv[1], argv[2], argv[3]);
        }
    }
    @autoreleasepool {
        count_calls(NSClassFromString(@"CharonSideWatch"), @selector(init), ^{ __sync_fetch_and_add(&watches_made, 1); });
        count_calls(NSClassFromString(@"CharonSideWatch"), NSSelectorFromString(@"dealloc"), ^{ __sync_fetch_and_add(&watches_gone, 1); });
        count_calls(NSClassFromString(@"CharonMapEntry"), @selector(key), ^{ key_calls++; });

        // What the port makes, and what the release makes where it has the factory.
        struct {
            const char *name;
            BOOL weakKeys, weakValues;
        } variants[] = {
            {"weakToStrong", YES, NO},
            {"strongToWeak", NO, YES},
            {"weakToWeak", YES, YES},
        };
        for (unsigned i = 0; i < sizeof variants / sizeof *variants; i++) {
            const char *name = variants[i].name;
            SEL port = NSSelectorFromString([NSString stringWithFormat:@"charonHost_%sObjectsMapTable", name]);
            SEL release = NSSelectorFromString([NSString stringWithFormat:@"%sObjectsMapTable", name]);
            BOOL released = [NSMapTable respondsToSelector:release];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSMapTable *(^ours)(void) = ^{ return (NSMapTable *)[NSMapTable performSelector:port]; };
            NSMapTable *(^theirs)(void) = released ? ^{ return (NSMapTable *)[NSMapTable performSelector:release]; } : nil;
#pragma clang diagnostic pop
            weak_checks(name, ours, theirs);
            archive_checks(name, ours(), released ? theirs() : nil,
                           [NSString stringWithFormat:@"%d %d k v", variants[i].weakKeys ? 5 : 0, variants[i].weakValues ? 5 : 0]);
            count_after_death(name, variants[i].weakKeys, ours(), released ? theirs() : nil);
            CHECK(![ours() isMemberOfClass:[NSMapTable class]] && [ours() isKindOfClass:[NSMapTable class]], label(name, "is a map table"));
            if (variants[i].weakKeys != variants[i].weakValues)
                held_side_checks(name, variants[i].weakKeys, ours(), released ? theirs() : nil);
            watch_checks(name, ours, (variants[i].weakKeys ? 1 : 0) + (variants[i].weakValues ? 1 : 0));
            cost_checks(name, variants[i].weakKeys, ours);
            path_checks(name, variants[i].weakKeys, variants[i].weakValues, ours());
            thread_checks(name, YES, ours);
            enumeration_checks(name, YES, ours);
            if (theirs) {
                const char *release_name = [NSString stringWithFormat:@"release %s", name].UTF8String;
                thread_checks(release_name, NO, theirs);
                enumeration_checks(release_name, NO, theirs);
            }
        }

        // Strong keys are retained, not copied, and values retained, as the host's own.
        BOOL released = [NSMapTable respondsToSelector:@selector(strongToStrongObjectsMapTable)];
        NSMapTable *ours = [NSMapTable charonHost_strongToStrongObjectsMapTable];
        NSMapTable *theirs = released ? [NSMapTable strongToStrongObjectsMapTable] : [NSMapTable mapTableWithKeyOptions:0 valueOptions:0];
        for (NSMapTable *table in @[ours, theirs]) {
            NSMutableString *key = [NSMutableString stringWithString:@"k"];
            __weak id watched;
            @autoreleasepool {
                id value = [NSObject new];
                watched = value;
                [table setObject:value forKey:key];
            }
            const char *side = table == ours ? "port" : "host";
            CHECK_EQUAL([[table keyEnumerator] nextObject] == key ? @"same key" : @"copied key", @"same key", label(side, "strongToStrong keeps the key itself"));
            CHECK(watched != nil, label(side, "strongToStrong retains the value"));
        }
        CHECK_EQUAL(@([ours keyPointerFunctions].usesStrongWriteBarrier), @([theirs keyPointerFunctions].usesStrongWriteBarrier), "strongToStrong key functions");
        CHECK_EQUAL(NSStringFromClass([ours class]), NSStringFromClass([theirs class]), "strongToStrong is the release's own table");
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
