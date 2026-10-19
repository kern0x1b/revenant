// The workout route of iOS 11.0: the class, the builder that makes it and the query that reads it.
//
// Each of the three is made the way the release makes it, because the header closes off -init on all
// three and the way past that is the declared path:
//   - HKWorkoutRoute has no initialiser at all and its superclass HKSeriesSample has none either, so the
//     only path the release offers is the archive: it is constructed through -initWithCoder: over a real
//     archive of its own facts, which is what the release's own round trip does.
//   - HKWorkoutRouteBuilder's designated initialiser is -initWithHealthStore:device: and its
//     superclass's -init is closed off with the header's "Use only subclass initializer methods", so
//     the base allocation is a port-private one and the public entry point is the declared initialiser.
//   - HKWorkoutRouteQuery's designated initialiser is -initWithRoute:dataHandler:.
//
// The route data is Apple's own encoded path, which this port does not parse: the builder keeps the
// bytes in the order they were inserted, and the route a query reads is that sequence. That is what the
// header's own -insertRouteData: takes, so nothing is invented.

#import <objc/runtime.h>

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

// A bare allocation of the builder, for the base its closed-off -init would have made. The class is
// abstract in the header and has no coder path, so this is the only way its storage comes into
// existence, and the declared initialiser fills it in the step after.
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

// The route the archive describes. An archive is the release's own way of making one of these, because
// there is no other: -init is unavailable on the class and on its superclass, and -initWithCoder: is
// the path NSCoding gives every NSSecureCoding class.
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

// The class is abstract in the header - "-init NS_UNAVAILABLE, use only subclass initializer
// methods" - so the port's own base allocation is reached by name and the declared initialiser below
// is the only way a caller makes one, which is what the release offers.
- (instancetype)charon_init
{
    return (HKWorkoutRouteBuilder *)CharonHKAllocateBuilder([self class]);
}

// The release's own designated initialiser. Its superclass HKSeriesBuilder closes off -init with the
// header's "Use only subclass initializer methods", so the base allocation is the port's own
// charon_init and the public entry point is this one, which is the path the release hands a caller.
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

// The builder's own facts in an archive, and nothing from a superclass: HKSeriesBuilder is not
// NSSecureCoding, so there is no superclass archive to call and the builder's two collections are all
// its state is.
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

// The path of the workout, as the bytes Apple encoded it, kept in the order they were inserted.
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

// The route the inserted data and the metadata make, kept in the store against the workout so that the
// query of that route can be answered from it.
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

// Nothing may be collected after a route is finished, which is what the release's -discard says.
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
    // The route's bytes, as the builder inserted them, handed to the caller's handler on the queue
    // the query was given, and the release's own error where there is nothing to hand.
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
