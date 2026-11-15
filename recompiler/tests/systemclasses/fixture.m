#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "SCFixture.h"

@implementation SCDict {
    NSMutableDictionary *_store;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _store = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSUInteger)count
{
    return _store.count;
}

- (id)objectForKey:(id)key
{
    return [_store objectForKey:key];
}

- (NSEnumerator *)keyEnumerator
{
    return [_store keyEnumerator];
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key
{
    [_store setObject:object forKey:key];
}

- (void)removeObjectForKey:(id)key
{
    [_store removeObjectForKey:key];
}
@end

extern char OBJC_CLASS_$_OS_dispatch_queue;

static void note(NSMutableArray *lines, NSString *name, BOOL passed)
{
    [lines addObject:[NSString stringWithFormat:@"%@ %@", passed ? @"ok" : @"FAIL", name]];
}

static BOOL wideSends(void)
{
    Class host = objc_getClass("SCHostWide");
    if (!host)
        return NO;
    long long (*mix)(id, SEL, int, long long) = (long long (*)(id, SEL, int, long long))objc_msgSend;
    long long (*pair)(id, SEL, long long, long long) = (long long (*)(id, SEL, long long, long long))objc_msgSend;
    long long (*tail)(id, SEL, int, int, int, long long) = (long long (*)(id, SEL, int, int, int, long long))objc_msgSend;
    unsigned long long (*unsign)(id, SEL, unsigned char, unsigned long long) = (unsigned long long (*)(id, SEL, unsigned char, unsigned long long))objc_msgSend;
    long long big = 0x1122334455667788LL;
    BOOL good = mix(host, sel_registerName("scMix:with:"), 5, big) == big + 5;
    good = good && mix(host, sel_registerName("scMix:with:"), -3, -2LL) == -5;
    good = good && pair(host, sel_registerName("scPair:and:"), big, 0x0102030405060708LL) == big - 0x0102030405060708LL;
    good = good && tail(host, sel_registerName("scTail:b:c:d:"), 1, 2, 3, big) == big + 6;
    good = good && unsign(host, sel_registerName("scUnsigned:with:"), 0xfe, 0xfedcba9876543210ULL) == 0xfedcba9876543210ULL + 0xfe;
    return good;
}

@interface NSObject (SCNative)
- (NSUInteger)scNative:(NSInteger)n;
- (NSInteger)scMix:(NSInteger)a with:(NSInteger)b and:(NSInteger)c;
@end

@implementation NSObject (SCNative)
- (NSUInteger)scNative:(NSInteger)n
{
    return (NSUInteger)(n + 7);
}

- (NSInteger)scMix:(NSInteger)a with:(NSInteger)b and:(NSInteger)c
{
    return a - b * 2 + c * 3;
}
@end

@interface SCGuestWide : NSObject
- (long long)scBig:(long long)n;
@end

@implementation SCGuestWide
- (long long)scBig:(long long)n
{
    return n + 1;
}
@end

@implementation SCFixture
+ (NSArray *)run
{
    NSMutableArray *lines = [NSMutableArray array];
    Class system = objc_getClass("NSMutableDictionary");
    note(lines, @"superclass", class_getSuperclass([SCDict class]) == system);
    SCDict *dict = [[SCDict alloc] init];
    note(lines, @"kind", [dict isKindOfClass:system] && [dict isKindOfClass:[NSMutableDictionary class]] && [dict isKindOfClass:[NSDictionary class]]);
    [dict addEntriesFromDictionary:@{@"a": @1, @"b": @2}];
    note(lines, @"addEntriesFromDictionary", dict.count == 2 && [[dict objectForKey:@"a"] isEqual:@1]);
    [dict removeAllObjects];
    note(lines, @"removeAllObjects", dict.count == 0);
    [dict setDictionary:@{@"c": @3}];
    note(lines, @"setDictionary", dict.count == 1 && [[dict objectForKey:@"c"] isEqual:@3]);
    note(lines, @"absent", [NSURLQueryItem class] != Nil);
    note(lines, @"shadowed", [CASpringAnimation class] != Nil);
    Class queue = (__bridge Class)(void *)&OBJC_CLASS_$_OS_dispatch_queue;
    note(lines, @"dispatch", queue != Nil && class_getName(queue) != NULL && [NSStringFromClass(queue) length] > 0);
    note(lines, @"wide", wideSends());
    return lines;
}
@end
