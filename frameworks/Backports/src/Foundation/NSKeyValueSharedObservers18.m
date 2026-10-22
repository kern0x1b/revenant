#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RevenantMethodProem.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantSharedObservation : NSObject {
@package
    NSObject *_observer;
    NSString *_key;
    NSKeyValueObservingOptions _options;
    void *_context;
}
@end

@implementation RevenantSharedObservation
@end

@interface NSKeyValueSharedObserversSnapshot ()
- (instancetype)initWithRevenantObservableClass:(Class)observableClass observations:(NSArray *)observations;
@property (nonatomic, readonly) Class revenant_observableClass;
@property (nonatomic, readonly) NSArray *revenant_observations;
@end

@interface RevenantSharedObserversReaper : NSObject {
@package
    __unsafe_unretained NSObject *_owner;
    NSKeyValueSharedObserversSnapshot *_snapshot;
}
@end

static char RevenantSharedObserversKey;

@implementation RevenantSharedObserversReaper

- (void)revenant_unregister
{
    for (RevenantSharedObservation *observation in _snapshot.revenant_observations)
        [_owner removeObserver:observation->_observer forKeyPath:observation->_key context:observation->_context];
    _snapshot = nil;
}

- (void)dealloc
{
    [self revenant_unregister];
}

@end

@implementation NSKeyValueSharedObserversSnapshot {
    Class _observableClass;
    NSArray *_observations;
}

- (instancetype)initWithRevenantObservableClass:(Class)observableClass observations:(NSArray *)observations
{
    if ((self = [super init])) {
        _observableClass = observableClass;
        _observations = [observations copy];
    }
    return self;
}

- (Class)revenant_observableClass
{
    return _observableClass;
}

- (NSArray *)revenant_observations
{
    return _observations;
}

@end

@implementation NSKeyValueSharedObservers {
    Class _observableClass;
    NSMutableArray *_observations;
}

- (id)initWithObservableClass:(Class)observableClass
{
    if ((self = [super init])) {
        _observableClass = observableClass;
        _observations = [NSMutableArray array];
    }
    return self;
}

- (void)addSharedObserver:(NSObject *)observer forKey:(NSString *)key options:(NSKeyValueObservingOptions)options context:(void *)context
{
    if ([key rangeOfString:@"."].location != NSNotFound)
        [NSException raise:NSInvalidArgumentException format:@"%@: shared observers cannot observe the nested key path '%@'", revenant_method_proem(self, _cmd), key];
    if (![observer respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)])
        [NSException raise:NSInvalidArgumentException format:@"%@: the observer does not implement observeValueForKeyPath:ofObject:change:context:", revenant_method_proem(self, _cmd)];
    RevenantSharedObservation *observation = [[RevenantSharedObservation alloc] init];
    observation->_observer = observer;
    observation->_key = [key copy];
    observation->_options = options;
    observation->_context = context;
    @synchronized (self) {
        [_observations addObject:observation];
    }
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    [NSException raise:NSInvalidArgumentException format:@"%@: use addSharedObserver:forKey:options:context: to add shared observers", revenant_method_proem(self, _cmd)];
}

- (NSKeyValueSharedObserversSnapshot *)snapshot
{
    @synchronized (self) {
        return [[NSKeyValueSharedObserversSnapshot alloc] initWithRevenantObservableClass:_observableClass observations:_observations];
    }
}

@end

@implementation NSObject (RevenantSharedObservers18)

- (void)setSharedObservers:(NSKeyValueSharedObserversSnapshot *)sharedObservers
{
    if (sharedObservers && ![self isKindOfClass:sharedObservers.revenant_observableClass])
        [NSException raise:NSInvalidArgumentException format:@"%@: the shared observers were created for class %@, not for %@", revenant_method_proem(self, _cmd),
                                                              NSStringFromClass(sharedObservers.revenant_observableClass), NSStringFromClass([self class])];
    RevenantSharedObserversReaper *previous = objc_getAssociatedObject(self, &RevenantSharedObserversKey);
    [previous revenant_unregister];
    if (!sharedObservers) {
        objc_setAssociatedObject(self, &RevenantSharedObserversKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    RevenantSharedObserversReaper *reaper = [[RevenantSharedObserversReaper alloc] init];
    reaper->_owner = self;
    reaper->_snapshot = sharedObservers;
    for (RevenantSharedObservation *observation in sharedObservers.revenant_observations)
        [self addObserver:observation->_observer forKeyPath:observation->_key options:observation->_options context:observation->_context];
    objc_setAssociatedObject(self, &RevenantSharedObserversKey, reaper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
