#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <unistd.h>
#import "check.h"

@interface NSMapTable (RevenantHostObjects6)
+ (instancetype)revenantHost_weakToStrongObjectsMapTable;
+ (instancetype)revenantHost_strongToWeakObjectsMapTable;
+ (instancetype)revenantHost_weakToWeakObjectsMapTable;
+ (instancetype)revenantHost_strongToStrongObjectsMapTable;
@end

@interface RevenantHostArchivedTable : NSObject <NSCoding>
@property (nonatomic, readonly) NSString *fields;
@property (nonatomic, readonly) BOOL later;
@end

@implementation RevenantHostArchivedTable

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

static NSMutableArray *pinned;

static id V(int number)
{
    id value = @(number);
    [pinned addObject:value];
    return value;
}

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
        if (!host)
            continue;
        NSString *theirs = outcome(^(NSMutableArray *said) { run(host(), said); });
        printf("release %s %s: %s\n", variant, scenarios[i].name, theirs.UTF8String);
        revenant_check([ours isEqual:theirs], label(variant, scenarios[i].name), [NSString stringWithFormat:@"%@ != %@", ours, theirs]);
    }
}

static RevenantHostArchivedTable *archived(NSMapTable *table)
{
    [table setObject:@"v" forKey:@"k"];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSKeyedArchiver archivedDataWithRootObject:table]];
    [unarchiver setClass:[RevenantHostArchivedTable class] forClassName:@"NSMapTable"];
    return [unarchiver decodeObjectForKey:@"root"];
}

static void archive_checks(const char *variant, NSMapTable *ours, NSMapTable *theirs, NSString *fields)
{
    RevenantHostArchivedTable *port = archived(ours), *release = theirs ? archived(theirs) : nil;
    CHECK([port isKindOfClass:[RevenantHostArchivedTable class]], label(variant, "port archives as NSMapTable"));
    if (release && !release.later)
        CHECK_EQUAL(port.fields, release.fields, label(variant, "port archives as the release does"));
    else
        CHECK_EQUAL(port.fields, fields, label(variant, "port archives in 6.0's order"));
    if (release.later)
        CHECK(!port.later, label(variant, "a later host writes NS.count, which 6.0 does not"));
}

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

static long watches_made, watches_gone, key_calls;

static void count_calls(Class cls, SEL selector, void (^count)(void))
{
    IMP original = method_getImplementation(class_getInstanceMethod(cls, selector));
    if (selector == @selector(init)) {
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
    revenant_check(key_calls < 20 * n, label(variant, "building a table of n keys reads entries a few times each"),
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
    CHECK_EQUAL(@(port ? [table count] : [[[table keyEnumerator] allObjects] count]), @1,
                label(variant, "and once they have gone the live entry is alone"));
}

static BOOL release_has_weak(void)
{
    return NSFoundationVersionNumber >= 881.0;
}

static BOOL ivar_flag(id object, const char *name)
{
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    return *(BOOL *)((char *)(__bridge void *)object + ivar_getOffset(ivar));
}

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

static id enumerated_object(int kind, long i, const char *tag)
{
    if (kind == 0)
        return [NSMutableString stringWithFormat:@"%s%ld", tag, i];
    return [NSNumber numberWithUnsignedLongLong:ULLONG_MAX - 2 * (unsigned long long)i - (tag[0] == 'v')];
}

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

@interface RevenantHostRefusesWeak : NSObject
@end

@implementation RevenantHostRefusesWeak
- (BOOL)allowsWeakReference
{
    return NO;
}
@end

static int refusal(const char *who, const char *variant, const char *side)
{
    BOOL port = strcmp(who, "port") == 0, key = strcmp(side, "key") == 0;
    NSString *selector = [NSString stringWithFormat:port ? @"revenantHost_%sObjectsMapTable" : @"%sObjectsMapTable", variant];
    if (![NSMapTable respondsToSelector:NSSelectorFromString(selector)]) {
        printf("outcome %s %s %s: no such factory\n", who, variant, side);
        return 0;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSMapTable *table = [NSMapTable performSelector:NSSelectorFromString(selector)];
#pragma clang diagnostic pop
    id refuses = [RevenantHostRefusesWeak new], other = [NSObject new];
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
        count_calls(NSClassFromString(@"RevenantSideWatch"), @selector(init), ^{ __sync_fetch_and_add(&watches_made, 1); });
        count_calls(NSClassFromString(@"RevenantSideWatch"), NSSelectorFromString(@"dealloc"), ^{ __sync_fetch_and_add(&watches_gone, 1); });
        count_calls(NSClassFromString(@"RevenantMapEntry"), @selector(key), ^{ key_calls++; });

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
            SEL port = NSSelectorFromString([NSString stringWithFormat:@"revenantHost_%sObjectsMapTable", name]);
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

        BOOL released = [NSMapTable respondsToSelector:@selector(strongToStrongObjectsMapTable)];
        NSMapTable *ours = [NSMapTable revenantHost_strongToStrongObjectsMapTable];
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
        printf("%d checks, %d failures\n", revenant_checks, revenant_failures);
    }
    return revenant_failures ? 1 : 0;
}
