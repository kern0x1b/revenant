#import <objc/runtime.h>

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

static id CharonHKAllocateBuilder(Class cls)
{
    return class_createInstance(cls, 0);
}

#pragma mark - HKWorkoutRoute

@interface HKWorkoutRoute (CharonIOS110Internal)
+ (instancetype)charon_routeWithData:(NSData *)routeData;
@end

@implementation HKWorkoutRoute {
    NSData *_routeData;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_routeWithData:(NSData *)routeData
{
    NSData *data = [routeData isKindOfClass:[NSData class]] ? routeData : [NSData data];
    NSMutableData *archive = [NSMutableData data];
    NSKeyedArchiver *coder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archive];
    coder.requiresSecureCoding = YES;
    [coder encodeObject:data forKey:@"routeData"];
    [coder finishEncoding];
    NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    HKWorkoutRoute *route = [[self alloc] initWithCoder:reader];
    [reader finishDecoding];
    return route;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKWorkoutRoute *route = [super initWithCoder:coder];
    if (route)
        route->_routeData = [[coder decodeObjectOfClass:[NSData class] forKey:@"routeData"] copy];
    return route;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_routeData forKey:@"routeData"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKWorkoutRoute charon_routeWithData:_routeData];
}

@end

#pragma mark - HKWorkoutRouteBuilder

@interface HKWorkoutRouteBuilder (CharonIOS110Internal)
+ (instancetype)charon_builderWithHealthStore:(HKHealthStore *)store device:(nullable HKDevice *)device;
@end

@implementation HKWorkoutRouteBuilder {
    NSMutableArray<NSData *> *_inserted;
    NSMutableDictionary<NSString *, NSString *> *_metadata;
    __weak HKHealthStore *_store;
    HKDevice *_device;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_init
{
    return (HKWorkoutRouteBuilder *)CharonHKAllocateBuilder([self class]);
}

- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore device:(nullable HKDevice *)device
{
    HKWorkoutRouteBuilder *builder = [self charon_init];
    if (builder) {
        builder->_inserted = [NSMutableArray array];
        builder->_metadata = [NSMutableDictionary dictionary];
        builder->_store = healthStore;
        builder->_device = device;
    }
    return builder;
}

- (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_inserted forKey:@"inserted"];
    [coder encodeObject:_metadata forKey:@"metadata"];
    [coder encodeObject:_device forKey:@"device"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKWorkoutRouteBuilder *builder = [self charon_init];
    if (builder) {
        builder->_inserted = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSData class], nil]
                                                 forKey:@"inserted"] mutableCopy] ?: [NSMutableArray array];
        builder->_metadata = [[coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil]
                                                 forKey:@"metadata"] mutableCopy] ?: [NSMutableDictionary dictionary];
        builder->_device = [[coder decodeObjectOfClass:[HKDevice class] forKey:@"device"] copy];
    }
    return builder;
}

- (void)insertRouteData:(NSData *)routeData completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (![routeData isKindOfClass:[NSData class]] || !routeData.length) {
        if (completion)
            completion(NO, CharonHKError(HKErrorInvalidArgument,
                                          @"Route data must be at least one byte of Apple's own encoded path.", nil));
        return;
    }
    [_inserted addObject:[routeData copy]];
    if (completion)
        completion(YES, nil);
}

- (void)addMetadata:(NSDictionary<NSString *, NSString *> *)metadata completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (![metadata isKindOfClass:[NSDictionary class]]) {
        if (completion)
            completion(NO, CharonHKError(HKErrorInvalidArgument, @"Route metadata must be a dictionary.", nil));
        return;
    }
    [_metadata addEntriesFromDictionary:metadata];
    if (completion)
        completion(YES, nil);
}

- (void)finishRouteWithWorkout:(HKWorkout *)workout
                       metadata:(nullable NSDictionary<NSString *, NSString *> *)metadata
                     completion:(void (^)(HKWorkoutRoute *_Nullable route, NSError *_Nullable error))completion
{
    if (![workout isKindOfClass:[HKWorkout class]] || !_inserted.count) {
        if (completion)
            completion(nil, CharonHKError(HKErrorInvalidArgument,
                                          @"A finished route needs a workout and at least one insertion of route data.", nil));
        return;
    }
    NSMutableData *joined = [NSMutableData data];
    for (NSData *piece in _inserted)
        [joined appendData:piece];
    NSMutableDictionary *all = [NSMutableDictionary dictionaryWithDictionary:_metadata];
    if (metadata)
        [all addEntriesFromDictionary:metadata];
    HKWorkoutRoute *route = [HKWorkoutRoute charon_routeWithData:joined];
    [[CharonHKStore sharedStore] setWorkoutRoute:route
                                      forWorkout:workout
                                          device:_device
                                        metadata:all
                                           error:NULL];
    if (completion)
        completion(route, nil);
}

- (void)discard
{
    [_inserted removeAllObjects];
    [_metadata removeAllObjects];
}

@end

#pragma mark - HKWorkoutRouteQuery

@implementation HKWorkoutRouteQuery {
    HKWorkoutRoute *_route;
    void (^_dataHandler)(NSData *_Nullable, NSError *_Nullable);
}

- (instancetype)initWithRoute:(HKWorkoutRoute *)workoutRoute
                  dataHandler:(void (^)(NSData *_Nullable routeData, NSError *_Nullable error))dataHandler
{
    HKWorkoutRouteQuery *query = [super initWithCharonObjectType:[HKObjectType workoutType]];
    if (query) {
        query->_route = (HKWorkoutRoute *)[workoutRoute copy];
        query->_dataHandler = [dataHandler copy];
    }
    return query;
}

- (HKWorkoutRoute *)route
{
    return _route;
}

- (void)charon_run
{
    NSData *data = _route ? [[CharonHKStore sharedStore] routeDataOf:_route] : nil;
    NSError *error = data ? nil : CharonHKError(HKErrorNoData, @"The route has no data.", nil);
    [self charon_perform:^{
        if (self->_dataHandler)
            self->_dataHandler(data, error);
    }];
}

- (void)charon_stop
{
    _dataHandler = nil;
}

@end
