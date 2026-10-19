#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CharonHKRow : NSObject
@property (readonly, copy) NSUUID *uuid;
@property (readonly, copy) NSString *type;
@property (readonly) NSInteger kind;
@property (readonly) NSTimeInterval start;
@property (readonly) NSTimeInterval end;
@property (readonly) NSTimeInterval created;
@property (readonly) NSInteger sequence;
@property (readonly, copy) NSString *sourceBundle;
@property (readonly, copy) NSString *sourceName;
@property (readonly, copy, nullable) NSString *sourceVersion;
@property (readonly, copy) NSData *archive;
@end

@interface CharonHKStore : NSObject

+ (CharonHKStore *)sharedStore;

@property (readonly, copy) NSString *path;
@property (readonly, getter=isOpen) BOOL open;
- (BOOL)openWithError:(NSError **)error;

- (BOOL)declareType:(HKObjectType *)type error:(NSError **)error;
- (nullable HKObjectType *)typeWithIdentifier:(NSString *)identifier;

- (BOOL)recordAuthorizationToShare:(nullable NSSet *)typesToShare read:(nullable NSSet *)typesToRead error:(NSError **)error;
- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type;
- (BOOL)mayReadType:(HKObjectType *)type;
- (BOOL)mayShareType:(HKObjectType *)type;

- (nullable id)characteristicForIdentifier:(NSString *)identifier;
- (BOOL)setCharacteristic:(nullable id)value forIdentifier:(NSString *)identifier error:(NSError **)error;

- (BOOL)saveObjects:(NSArray *)objects error:(NSError **)error;
- (BOOL)addSamples:(NSArray *)samples toWorkout:(HKObject *)workout error:(NSError **)error;
- (BOOL)deleteObjects:(NSArray *)objects error:(NSError **)error;
- (NSUInteger)deleteObjectsOfType:(HKObjectType *)type predicate:(nullable NSPredicate *)predicate error:(NSError **)error;

- (nullable NSArray *)objectsOfType:(HKObjectType *)type
                          predicate:(nullable NSPredicate *)predicate
                          startDate:(nullable NSDate *)startDate
                            endDate:(nullable NSDate *)endDate
                  strictStartDate:(BOOL)strictStartDate
                    strictEndDate:(BOOL)strictEndDate
                           limit:(NSUInteger)limit
                   sortDescriptors:(nullable NSArray *)sortDescriptors
                       fromSequence:(NSInteger)fromSequence
                             error:(NSError **)error;
- (nullable NSArray *)objectsWithUUIDs:(NSArray<NSUUID *> *)uuids ofType:(HKObjectType *)type error:(NSError **)error;
- (NSInteger)highestSequence;
- (NSArray *)deletedUUIDsSinceSequence:(NSInteger)sequence;
- (nullable NSArray *)deletedObjectsSinceSequence:(NSInteger)sequence;

- (void)setWorkoutRoute:(HKWorkoutRoute *)route
             forWorkout:(HKWorkout *)workout
                 device:(nullable HKDevice *)device
              metadata:(nullable NSDictionary *)metadata
                 error:(NSError **)error;
- (NSData *)routeDataOf:(HKWorkoutRoute *)route;
+ (NSData *)charon_routeDataOf:(HKWorkoutRoute *)route;

- (nullable NSArray *)documentsOfType:(HKDocumentType *)type
                            predicate:(nullable NSPredicate *)predicate
                               limit:(NSUInteger)limit
                    sortDescriptors:(nullable NSArray *)sortDescriptors
                 includeDocumentData:(BOOL)includeDocumentData
                             error:(NSError **)error;

- (NSArray *)activitySummariesMatching:(nullable NSPredicate *)predicate error:(NSError **)error;

- (NSArray *)allSources;
- (NSArray *)sourcesForType:(HKObjectType *)type;
- (BOOL)deleteSourceWithBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
- (BOOL)setOrderedSources:(NSArray *)sources forType:(HKObjectType *)type error:(NSError **)error;

- (BOOL)setBackgroundDelivery:(BOOL)enabled forType:(HKObjectType *)type frequency:(NSUInteger)frequency error:(NSError **)error;
- (BOOL)disableAllBackgroundDeliveryWithError:(NSError **)error;

- (nullable id)anchorForActivationUUID:(NSUUID *)uuid;
- (void)setAnchor:(nullable id)anchor forActivationUUID:(NSUUID *)uuid;

- (void)addObserver:(id)observer forTypes:(nullable NSSet *)types;
- (void)removeObserver:(id)observer;

@end

@protocol CharonHKStorable <NSObject>
+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store;
- (NSString *)charon_storeTypeIdentifier;
- (NSInteger)charon_storeKind;
- (NSData *)charon_storeArchive;
+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store;
@end

@protocol CharonHKStoreObserver <NSObject>
- (void)charon_storeDidChange:(NSArray<NSUUID *> *)identifiers;
@end

@protocol CharonHKRunnableQuery <NSObject>
- (void)charon_run;
- (void)charon_stop;
- (void)charon_setHasBeenExecuted:(BOOL)executed;
- (BOOL)charon_hasBeenExecuted;
@end

@protocol CharonHKTyped <NSObject>
+ (instancetype)charon_typeWithIdentifier:(NSString *)identifier;
- (NSInteger)charon_storeKind;
- (void)charon_setCanonicalUnitString:(nullable NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle;
- (NSInteger)charon_aggregationStyleValue;
- (nullable NSString *)charon_canonicalUnitString;
@end

extern Class _Nullable CharonHKClassForObjectKind(NSInteger kind);
extern Class _Nullable CharonHKClassForTypeKind(NSInteger kind);

@interface HKStatisticsCollection (CharonInternal)
+ (instancetype)charon_collectionWithAnchorDate:(NSDate *)anchorDate
                                       options:(NSUInteger)options
                            intervalComponents:(NSDateComponents *)intervalComponents
                                      samples:(NSArray *)samples
                                      calendar:(NSCalendar *)calendar;
- (void)enumerateStatisticsFromDate:(nullable NSDate *)startDate
                             toDate:(nullable NSDate *)endDate
                           withBlock:(void (^)(HKStatistics *result, BOOL *stop))block;
@end

@interface HKDocumentSample (CharonIOS100Internal)
- (instancetype)charon_copyWithoutDocument:(nullable NSDictionary *)metadata;
- (void)charon_setMetadata:(nullable NSDictionary *)metadata;
@end

@interface HKWorkoutEvent (CharonIOS100Internal)
- (instancetype)charon_initWithType:(HKWorkoutEventType)type date:(NSDate *)date;
- (nullable NSDictionary *)charon_storedMetadata;
- (void)charon_setMetadata:(nullable NSDictionary *)metadata;
- (nullable NSDateInterval *)charon_storedDateInterval;
- (void)charon_setDateInterval:(nullable NSDateInterval *)dateInterval;
@end

@interface HKObject (CharonIOS9)
- (nullable HKSourceRevision *)sourceRevision;
- (nullable HKDevice *)device;
- (void)charon_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device;
@end

@interface HKObjectType (CharonInternal)
+ (instancetype)charon_typeWithIdentifier:(NSString *)identifier;
@end

@interface HKObject (CharonInternal)
- (instancetype)charon_initWithUUID:(NSUUID *)uuid source:(HKSource *)source metadata:(NSDictionary *)metadata;
- (instancetype)charon_copyForStore;
- (nullable HKCorrelation *)charon_correlation;
- (void)charon_setCorrelation:(nullable HKCorrelation *)correlation;
- (void)charon_setMetadata:(nullable NSDictionary *)metadata;
- (void)charon_setDevice:(nullable HKDevice *)device;
- (nullable HKDevice *)charon_storedDevice;
- (nullable HKSourceRevision *)charon_storedSourceRevision;
- (void)charon_setStoredSourceRevision:(nullable HKSourceRevision *)revision;
- (instancetype)charon_objectWithCoder:(NSCoder *)coder;
@end

@interface HKSample (CharonInternal)
- (instancetype)charon_initWithType:(HKSampleType *)sampleType
                           metadata:(nullable NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate;
- (HKObjectType *)charon_typeForSaving;
@end


@interface HKQuery (CharonInternalOperator)
+ (NSString *)charon_predicateOperatorSpellingFor:(NSPredicateOperatorType)type;
@end

@interface HKWorkout (CharonInternal)
- (instancetype)charon_initWithType:(HKObjectType *)type
                           metadata:(nullable NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate
                           duration:(NSTimeInterval)duration;
- (void)charon_setWorkoutActivityType:(HKWorkoutActivityType)activityType;
- (void)charon_setWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents;
- (nullable HKQuantity *)charon_totalSwimmingStrokeCount;
- (void)charon_setTotalSwimmingStrokeCount:(nullable HKQuantity *)count;
- (nullable HKQuantity *)charon_storedTotalFlightsClimbed;
- (void)charon_setTotalFlightsClimbed:(nullable HKQuantity *)flights;
- (void)charon_setTotalEnergyBurned:(nullable HKQuantity *)energy totalDistance:(nullable HKQuantity *)distance;
@end

@interface HKCorrelation (CharonInternal)
- (NSArray<HKObject *> *)charon_allObjects;
- (NSSet<HKObject *> *)charon_allObjectsSet;
@end

@interface HKQuantity (CharonInternal)
- (nullable HKUnit *)charon_unit;
- (double)charon_rawValue;
@end

@interface HKUnit (CharonInternal)
- (double)charon_value:(double)value inUnit:(HKUnit *)unit;
+ (nullable HKUnit *)charon_canonicalUnitForType:(HKQuantityType *)type;
- (BOOL)charon_isCompatibleWithUnit:(HKUnit *)unit;
+ (nullable HKUnit *)charon_namedUnit:(NSString *)string;
+ (instancetype)charon_unitFromString:(NSString *)string;
+ (instancetype)charon_prefixedUnitForDimension:(NSInteger)dimension prefix:(HKMetricPrefix)prefix;
@end

@interface HKAnchoredObjectQuery (CharonInternal)
@property (nonatomic, copy, nullable) void (^charon_updateHandler)(HKAnchoredObjectQuery *query,
                                                                    NSArray<HKSample *> *_Nullable added,
                                                                    NSArray<HKDeletedObject *> *_Nullable deleted,
                                                                    HKQueryAnchor *_Nullable anchor,
                                                                    NSError *_Nullable error);
@property (nonatomic) BOOL charon_stopsAfterResults;
@property (nonatomic) NSUInteger charon_limit;
- (nullable NSDate *)charon_lastAnchor;
- (void)charon_setLastAnchor:(nullable NSDate *)lastAnchor;
- (nullable HKStatisticsCollection *)charon_statisticsCollection;
- (void)charon_setStatisticsCollection:(nullable HKStatisticsCollection *)statisticsCollection;
- (void)charon_setResultsHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable sampleObjects,
                                           NSArray<HKDeletedObject *> *_Nullable deletedObjects, HKQueryAnchor *_Nullable newAnchor,
                                           NSError *_Nullable error))handler;
- (void)charon_storeDidChange:(NSArray<NSUUID *> *)identifiers;
@end

@interface HKHealthStore (CharonInternal)
- (void)charon_complete:(nullable void (^)(BOOL success, NSError *_Nullable error))completion
                     ok:(BOOL)ok
                  error:(nullable NSError *)error;
@end

@interface HKQuery (CharonInternalStop)
@property (nonatomic) BOOL charon_stopsAfterResults;
@end

@interface HKActivitySummary (CharonInternal)
- (instancetype)charon_initWithStartDate:(NSDate *)startDate;
- (nullable NSDateComponents *)dateComponents;
+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store;
@end

@interface HKActivitySummaryQuery (CharonInternal)
@property (nonatomic, copy, nullable) void (^charon_updateHandlerForSummaries)(HKActivitySummaryQuery *query,
                                                                                 NSArray<HKActivitySummary *> *_Nullable summaries,
                                                                                 NSError *_Nullable error);
@end

@interface HKQuery (CharonInternal)
- (instancetype)initWithCharonObjectType:(nullable HKObjectType *)objectType;
- (instancetype)initWithCharonSampleType:(nullable HKSampleType *)sampleType;
- (nullable NSPredicate *)charon_predicate;
- (nullable HKObjectType *)charon_objectType;
- (void)charon_setPredicate:(nullable NSPredicate *)predicate;
- (void)charon_setHasBeenExecuted:(BOOL)executed;
- (BOOL)charon_hasBeenExecuted;
- (void)charon_setQueue:(dispatch_queue_t)queue;
- (void)charon_perform:(dispatch_block_t)block;
@end

@interface HKStatisticsCollection (CharonInternalInterval)
+ (nullable NSDateComponents *)charon_normalizedIntervalComponents:(nullable NSDateComponents *)components;
@end

@interface HKStatistics (CharonInternal)
+ (instancetype)charon_statisticsForSamples:(NSArray *)samples options:(NSUInteger)options;
@end



@interface HKQuantityType (CharonInternal)
- (nullable HKUnit *)charon_canonicalUnit;
@end

@interface HKCategorySample (CharonInternal)
- (HKCategoryType *)categoryType;
@end

@interface HKSource (CharonInternal)
+ (instancetype)charon_sourceWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier;
+ (nullable NSString *)charon_processVersion;
@end

@interface HKDevice (CharonInternal)
+ (instancetype)charon_deviceWithName:(nullable NSString *)name
                        manufacturer:(nullable NSString *)manufacturer
                               model:(nullable NSString *)model
                     hardwareVersion:(nullable NSString *)hardwareVersion
                     firmwareVersion:(nullable NSString *)firmwareVersion
                     softwareVersion:(nullable NSString *)softwareVersion
                     localIdentifier:(nullable NSString *)localIdentifier
                 UDIDeviceIdentifier:(nullable NSString *)UDIDeviceIdentifier;
@end

@interface HKSourceRevision (CharonInternal)
- (instancetype)charon_initWithSource:(HKSource *)source version:(nullable NSString *)version;
- (void)charon_setProductType:(nullable NSString *)productType
     operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion;
- (nullable NSString *)charon_storedProductType;
- (NSOperatingSystemVersion)charon_storedOperatingSystemVersion;
- (instancetype)charon_initWithSource:(HKSource *)source version:(nullable NSString *)version;
@end

@interface HKDeletedObject (CharonInternal)
- (instancetype)charon_initWithUUID:(NSUUID *)uuid;
- (nullable NSDictionary<NSString *, id> *)charon_deletedMetadata;
@end

@interface HKFitzpatrickSkinTypeObject (CharonInternal)
+ (instancetype)charon_fitzpatrickSkinTypeObject:(HKFitzpatrickSkinType)skinType;
@end

@interface HKWheelchairUseObject (CharonInternal)
+ (instancetype)charon_wheelchairUseObject:(HKWheelchairUse)wheelchairUse;
@end

@interface HKDocumentSample (CharonInternal10)
- (instancetype)charon_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document;
@end

@interface HKCDADocument (CharonInternal10)
- (instancetype)charon_initWithDocumentData:(NSData *)documentData
                                      title:(nullable NSString *)title
                                 patientName:(nullable NSString *)patientName
                                  authorName:(nullable NSString *)authorName
                               custodianName:(nullable NSString *)custodianName;
@end

@interface HKWorkoutConfiguration (CharonInternal10)
- (instancetype)charon_initWithActivityType:(HKWorkoutActivityType)activityType
                               locationType:(HKWorkoutSessionLocationType)locationType
                                 lapLength:(nullable HKQuantity *)lapLength
                       swimmingLocationType:(HKWorkoutSwimmingLocationType)swimmingLocationType;
@end

@interface HKDocumentSample (CharonIOS100Internal)
- (instancetype)charon_copyWithoutDocument:(nullable NSDictionary *)metadata;
- (void)charon_setMetadata:(nullable NSDictionary *)metadata;
@end

@interface HKWorkoutEvent (CharonIOS100Internal)
- (instancetype)charon_initWithType:(HKWorkoutEventType)type date:(NSDate *)date;
- (nullable NSDictionary *)charon_storedMetadata;
- (void)charon_setMetadata:(nullable NSDictionary *)metadata;
- (nullable NSDateInterval *)charon_storedDateInterval;
- (void)charon_setDateInterval:(nullable NSDateInterval *)dateInterval;
@end

@interface HKObject (CharonIOS9)
- (nullable HKSourceRevision *)sourceRevision;
- (nullable HKDevice *)device;
- (void)charon_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device;
@end

@interface HKBiologicalSexObject (CharonInternal)
+ (instancetype)charon_biologicalSexObject:(HKBiologicalSex)biologicalSex;
@end

@interface HKBloodTypeObject (CharonInternal)
+ (instancetype)charon_bloodTypeObject:(HKBloodType)bloodType;
@end

@interface HKQueryAnchor (CharonInternal)
+ (instancetype)charon_anchorWithSequence:(NSInteger)sequence;
- (NSInteger)charon_sequence;
@end

extern NSError *CharonHKError(NSInteger code, NSString *description, NSString * _Nullable debug);

extern void charon_hk_say_once(NSString *key, NSString *text);

extern NSString *CharonHKStorePath(void);

#define CHARON_HEALTHKIT_UNCREATABLE_INIT                                                  \
    -(instancetype)init                                                                    \
    {                                                                                     \
        [NSException raise:NSInvalidArgumentException                                      \
                        format:@"The -init method is not available on %@",                 \
                               NSStringFromClass([self class])];                            \
        return nil;                                                                       \
    }

NS_ASSUME_NONNULL_END
