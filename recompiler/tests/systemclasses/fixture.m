#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
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
    return lines;
}
@end
