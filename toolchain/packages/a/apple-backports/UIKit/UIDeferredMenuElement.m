#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UIDeferredMenuElement ()
- (void)charon_finishWithElements:(NSArray *)elements;
@end

@implementation UIDeferredMenuElement {
@private
    NSString *_identifier;
    void (^_provider)(void (^)(NSArray<UIMenuElement *> *));
    NSArray<UIMenuElement *> *_elements;
    NSMutableArray *_waiting;
    BOOL _asked;
    BOOL _cached;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)elementWithProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider
{
    UIDeferredMenuElement *element = [[self alloc] initCharonWithTitle:[[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Loading…"
                                                                                                                           value:@"Loading…"
                                                                                                                           table:nil]
                                                                  image:nil];
    element->_identifier = [@"com.apple.deferred-element.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
    element->_provider = [elementProvider copy];
    element->_cached = YES;
    return element;
}

+ (instancetype)elementWithUncachedProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider
{
    UIDeferredMenuElement *element = [self elementWithProvider:elementProvider];
    element->_cached = NO;
    return element;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        NSString *identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _identifier = identifier ? [identifier copy] : [@"com.apple.deferred-element.dynamic." stringByAppendingString:[NSUUID UUID].UUIDString];
        _cached = [coder containsValueForKey:@"cachesItems"] ? [coder decodeBoolForKey:@"cachesItems"] : YES;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeBool:_cached forKey:@"cachesItems"];
    [coder encodeBool:NO forKey:@"fulfilled"];
}

- (void)charon_fulfillWithCompletion:(void (^)(NSArray<UIMenuElement *> *))completion
{
    if (!_cached) {
        void (^provider)(void (^)(NSArray<UIMenuElement *> *)) = _provider;
        if (!provider) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[]);
            });
            return;
        }
        provider(^(NSArray<UIMenuElement *> *elements) {
            NSArray *result = elements ?: @[];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(result);
            });
        });
        return;
    }
    void (^provider)(void (^)(NSArray<UIMenuElement *> *)) = nil;
    BOOL ask = NO;
    @synchronized (self) {
        if (_elements) {
            NSArray *elements = _elements;
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(elements);
            });
            return;
        }
        if (!_waiting)
            _waiting = [NSMutableArray array];
        [_waiting addObject:[completion copy]];
        if (!_asked) {
            _asked = YES;
            ask = YES;
            provider = _provider;
        }
    }
    if (!ask)
        return;
    if (!provider) {
        [self charon_finishWithElements:@[]];
        return;
    }
    provider(^(NSArray<UIMenuElement *> *elements) {
        [self charon_finishWithElements:elements ?: @[]];
    });
}

- (void)charon_finishWithElements:(NSArray *)elements
{
    NSArray *waiting;
    @synchronized (self) {
        if (_elements)
            return;
        _elements = [elements copy];
        waiting = _waiting;
        _waiting = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (void (^completion)(NSArray *) in waiting)
            completion(elements);
    });
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIDeferredMenuElement class]])
        return NO;
    return [_identifier isEqual:((UIDeferredMenuElement *)object)->_identifier];
}

- (NSUInteger)hash
{
    return _identifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end
