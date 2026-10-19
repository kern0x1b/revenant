#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const NSDirectoryEnumerationOptions charon_post_order_option = 1UL << 3;

__attribute__((visibility("hidden")))
@interface CharonPostOrderEnumerator : NSDirectoryEnumerator {
    NSDirectoryEnumerator *_inner;
    NSMutableArray *_stack;
    NSURL *_lookahead;
    NSUInteger _lookaheadLevel;
    BOOL _post;
    NSUInteger _level;
}
- (instancetype)initWithEnumerator:(NSDirectoryEnumerator *)inner;
@end

@implementation CharonPostOrderEnumerator

- (instancetype)initWithEnumerator:(NSDirectoryEnumerator *)inner
{
    if ((self = [super init])) {
        _inner = inner;
        _stack = [NSMutableArray array];
    }
    return self;
}

- (id)nextObject
{
    NSURL *next = _lookahead;
    NSUInteger level = _lookaheadLevel;
    _lookahead = nil;
    if (!next) {
        next = [_inner nextObject];
        level = _inner.level;
    }
    NSArray *top = _stack.lastObject;
    if (!next || (top && [top[1] unsignedIntegerValue] >= level)) {
        if (!top)
            return nil;
        _lookahead = next;
        _lookaheadLevel = level;
        [_stack removeLastObject];
        _post = YES;
        _level = [top[1] unsignedIntegerValue];
        return top[0];
    }
    _post = NO;
    _level = level;
    NSNumber *directory = nil;
    [next getResourceValue:&directory forKey:NSURLIsDirectoryKey error:NULL];
    if (directory.boolValue)
        [_stack addObject:@[next, @(level)]];
    return next;
}

- (NSUInteger)level
{
    return _level;
}

- (BOOL)isEnumeratingDirectoryPostOrder
{
    return _post;
}

- (void)skipDescendants
{
    if (!_post)
        [_inner skipDescendants];
}

- (void)skipDescendents
{
    if (!_post)
        [_inner skipDescendents];
}

- (NSDictionary *)fileAttributes
{
    return _post ? nil : _inner.fileAttributes;
}

- (NSDictionary *)directoryAttributes
{
    return _inner.directoryAttributes;
}

@end

@implementation NSDirectoryEnumerator (CharonPostOrder)

- (BOOL)isEnumeratingDirectoryPostOrder
{
    return NO;
}

@end

@interface CharonPostOrderInstaller : NSObject
@end

@implementation CharonPostOrderInstaller

+ (void)load
{
#ifdef CHARON_HOST_DIFFERENTIAL
    return;
#endif
    SEL selector = @selector(enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:);
    NSMutableArray *targets = [NSMutableArray arrayWithObject:[NSFileManager class]];
    for (NSFileManager *manager in @[[NSFileManager defaultManager], [[NSFileManager alloc] init]]) {
        if (![targets containsObject:object_getClass(manager)])
            [targets addObject:object_getClass(manager)];
    }
    for (Class target in targets) {
        Method method = class_getInstanceMethod(target, selector);
        if (!method)
            continue;
        IMP original = method_getImplementation(method);
        class_replaceMethod(target, selector, imp_implementationWithBlock(^id(NSFileManager *manager, NSURL *url, NSArray *keys, NSDirectoryEnumerationOptions options, BOOL (^handler)(NSURL *, NSError *)) {
            NSDirectoryEnumerator *inner = ((id (*)(id, SEL, id, id, NSDirectoryEnumerationOptions, id))original)(manager, selector, url, keys, options & ~charon_post_order_option, handler);
            return inner && (options & charon_post_order_option) ? [[CharonPostOrderEnumerator alloc] initWithEnumerator:inner] : inner;
        }), method_getTypeEncoding(method));
    }
}

@end
