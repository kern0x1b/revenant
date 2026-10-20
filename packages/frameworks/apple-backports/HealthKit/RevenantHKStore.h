#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantHKRow : NSObject
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

@interface RevenantHKStore : NSObject

+ (RevenantHKStore *)sharedStore;

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
+ (NSData *)revenant_routeDataOf:(HKWorkoutRoute *)route;

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

@protocol RevenantHKStorable <NSObject>
+ (nullable instancetype)revenant_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(RevenantHKStore *)store;
- (NSString *)revenant_storeTypeIdentifier;
- (NSInteger)revenant_storeKind;
- (NSData *)revenant_storeArchive;
+ (nullable instancetype)revenant_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(RevenantHKStore *)store;
@end

@protocol RevenantHKStoreObserver <NSObject>
- (void)revenant_storeDidChange:(NSArray<NSUUID *> *)identifiers;
@end

@protocol RevenantHKRunnableQuery <NSObject>
- (void)revenant_run;
- (void)revenant_stop;
- (void)revenant_setHasBeenExecuted:(BOOL)executed;
- (BOOL)revenant_hasBeenExecuted;
@end

@protocol RevenantHKTyped <NSObject>
+ (instancetype)revenant_typeWithIdentifier:(NSString *)identifier;
- (NSInteger)revenant_storeKind;
- (void)revenant_setCanonicalUnitString:(nullable NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle;
- (NSInteger)revenant_aggregationStyleValue;
- (nullable NSString *)revenant_canonicalUnitString;
@end

extern Class _Nullable RevenantHKClassForObjectKind(NSInteger kind);
extern Class _Nullable RevenantHKClassForTypeKind(NSInteger kind);

@interface HKStatisticsCollection (RevenantInternal)
+ (instancetype)revenant_collectionWithAnchorDate:(NSDate *)anchorDate
                                       options:(NSUInteger)options
                            intervalComponents:(NSDateComponents *)intervalComponents
                                      samples:(NSArray *)samples
                                      calendar:(NSCalendar *)calendar;
- (void)enumerateStatisticsFromDate:(nullable NSDate *)startDate
                             toDate:(nullable NSDate *)endDate
                           withBlock:(void (^)(HKStatistics *result, BOOL *stop))block;
@end

@interface HKDocumentSample (RevenantIOS100Internal)
- (instancetype)revenant_copyWithoutDocument:(nullable NSDictionary *)metadata;
- (void)revenant_setMetadata:(nullable NSDictionary *)metadata;
@end

@interface HKWorkoutEvent (RevenantIOS100Internal)
- (instancetype)revenant_initWithType:(HKWorkoutEventType)type date:(NSDate *)date;
- (nullable NSDictionary *)revenant_storedMetadata;
- (void)revenant_setMetadata:(nullable NSDictionary *)metadata;
- (nullable NSDateInterval *)revenant_storedDateInterval;
- (void)revenant_setDateInterval:(nullable NSDateInterval *)dateInterval;
@end

@interface HKObject (RevenantIOS9)
- (nullable HKSourceRevision *)sourceRevision;
- (nullable HKDevice *)device;
- (void)revenant_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device;
@end

@interface HKObjectType (RevenantInternal)
+ (instancetype)revenant_typeWithIdentifier:(NSString *)identifier;
@end

@interface HKObject (RevenantInternal)
- (instancetype)revenant_initWithUUID:(NSUUID *)uuid source:(HKSource *)source metadata:(NSDictionary *)metadata;
- (instancetype)revenant_copyForStore;
- (nullable HKCorrelation *)revenant_correlation;
- (void)revenant_setCorrelation:(nullable HKCorrelation *)correlation;
- (void)revenant_setMetadata:(nullable NSDictionary *)metadata;
- (void)revenant_setDevice:(nullable HKDevice *)device;
- (nullable HKDevice *)revenant_storedDevice;
- (nullable HKSourceRevision *)revenant_storedSourceRevision;
- (void)revenant_setStoredSourceRevision:(nullable HKSourceRevision *)revision;
- (instancetype)revenant_objectWithCoder:(NSCoder *)coder;
@end

@interface HKSample (RevenantInternal)
- (instancetype)revenant_initWithType:(HKSampleType *)sampleType
                           metadata:(nullable NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate;
- (HKObjectType *)revenant_typeForSaving;
@end


@interface HKQuery (RevenantInternalOperator)
+ (NSString *)revenant_predicateOperatorSpellingFor:(NSPredicateOperatorType)type;
@end

@interface HKWorkout (RevenantInternal)
- (instancetype)revenant_initWithType:(HKObjectType *)type
                           metadata:(nullable NSDictionary *)metadata
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate
                           duration:(NSTimeInterval)duration;
- (void)revenant_setWorkoutActivityType:(HKWorkoutActivityType)activityType;
- (void)revenant_setWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents;
- (nullable HKQuantity *)revenant_totalSwimmingStrokeCount;
- (void)revenant_setTotalSwimmingStrokeCount:(nullable HKQuantity *)count;
- (nullable HKQuantity *)revenant_storedTotalFlightsClimbed;
- (void)revenant_setTotalFlightsClimbed:(nullable HKQuantity *)flights;
- (void)revenant_setTotalEnergyBurned:(nullable HKQuantity *)energy totalDistance:(nullable HKQuantity *)distance;
@end

@interface HKCorrelation (RevenantInternal)
- (NSArray<HKObject *> *)revenant_allObjects;
- (NSSet<HKObject *> *)revenant_allObjectsSet;
@end

@interface HKQuantity (RevenantInternal)
- (nullable HKUnit *)revenant_unit;
- (double)revenant_rawValue;
@end

@interface HKUnit (RevenantInternal)
- (double)revenant_value:(double)value inUnit:(HKUnit *)unit;
+ (nullable HKUnit *)revenant_canonicalUnitForType:(HKQuantityType *)type;
- (BOOL)revenant_isCompatibleWithUnit:(HKUnit *)unit;
+ (nullable HKUnit *)revenant_namedUnit:(NSString *)string;
+ (instancetype)revenant_unitFromString:(NSString *)string;
+ (instancetype)revenant_prefixedUnitForDimension:(NSInteger)dimension prefix:(HKMetricPrefix)prefix;
@end

@interface HKAnchoredObjectQuery (RevenantInternal)
@property (nonatomic, copy, nullable) void (^revenant_updateHandler)(HKAnchoredObjectQuery *query,
                                                                    NSArray<HKSample *> *_Nullable added,
                                                                    NSArray<HKDeletedObject *> *_Nullable deleted,
                                                                    HKQueryAnchor *_Nullable anchor,
                                                                    NSError *_Nullable error);
@property (nonatomic) BOOL revenant_stopsAfterResults;
@property (nonatomic) NSUInteger revenant_limit;
- (nullable NSDate *)revenant_lastAnchor;
- (void)revenant_setLastAnchor:(nullable NSDate *)lastAnchor;
- (nullable HKStatisticsCollection *)revenant_statisticsCollection;
- (void)revenant_setStatisticsCollection:(nullable HKStatisticsCollection *)statisticsCollection;
- (void)revenant_setResultsHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<HKSample *> *_Nullable sampleObjects,
                                           NSArray<HKDeletedObject *> *_Nullable deletedObjects, HKQueryAnchor *_Nullable newAnchor,
                                           NSError *_Nullable error))handler;
- (void)revenant_storeDidChange:(NSArray<NSUUID *> *)identifiers;
@end

@interface HKHealthStore (RevenantInternal)
- (void)revenant_complete:(nullable void (^)(BOOL success, NSError *_Nullable error))completion
                     ok:(BOOL)ok
                  error:(nullable NSError *)error;
@end

@interface HKQuery (RevenantInternalStop)
@property (nonatomic) BOOL revenant_stopsAfterResults;
@end

@interface HKActivitySummary (RevenantInternal)
- (instancetype)revenant_initWithStartDate:(NSDate *)startDate;
- (nullable NSDateComponents *)dateComponents;
+ (nullable instancetype)revenant_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(RevenantHKStore *)store;
@end

@interface HKActivitySummaryQuery (RevenantInternal)
@property (nonatomic, copy, nullable) void (^revenant_updateHandlerForSummaries)(HKActivitySummaryQuery *query,
                                                                                 NSArray<HKActivitySummary *> *_Nullable summaries,
                                                                                 NSError *_Nullable error);
@end

@interface HKQuery (RevenantInternal)
- (instancetype)initWithRevenantObjectType:(nullable HKObjectType *)objectType;
- (instancetype)initWithRevenantSampleType:(nullable HKSampleType *)sampleType;
- (nullable NSPredicate *)revenant_predicate;
- (nullable HKObjectType *)revenant_objectType;
- (void)revenant_setPredicate:(nullable NSPredicate *)predicate;
- (void)revenant_setHasBeenExecuted:(BOOL)executed;
- (BOOL)revenant_hasBeenExecuted;
- (void)revenant_setQueue:(dispatch_queue_t)queue;
- (void)revenant_perform:(dispatch_block_t)block;
@end

@interface HKStatisticsCollection (RevenantInternalInterval)
+ (nullable NSDateComponents *)revenant_normalizedIntervalComponents:(nullable NSDateComponents *)components;
@end

@interface HKStatistics (RevenantInternal)
+ (instancetype)revenant_statisticsForSamples:(NSArray *)samples options:(NSUInteger)options;
@end



@interface HKQuantityType (RevenantInternal)
- (nullable HKUnit *)revenant_canonicalUnit;
@end

@interface HKCategorySample (RevenantInternal)
- (HKCategoryType *)categoryType;
@end

@interface HKSource (RevenantInternal)
+ (instancetype)revenant_sourceWithName:(NSString *)name bundleIdentifier:(NSString *)bundleIdentifier;
+ (nullable NSString *)revenant_processVersion;
@end

@interface HKDevice (RevenantInternal)
+ (instancetype)revenant_deviceWithName:(nullable NSString *)name
                        manufacturer:(nullable NSString *)manufacturer
                               model:(nullable NSString *)model
                     hardwareVersion:(nullable NSString *)hardwareVersion
                     firmwareVersion:(nullable NSString *)firmwareVersion
                     softwareVersion:(nullable NSString *)softwareVersion
                     localIdentifier:(nullable NSString *)localIdentifier
                 UDIDeviceIdentifier:(nullable NSString *)UDIDeviceIdentifier;
@end

@interface HKSourceRevision (RevenantInternal)
- (instancetype)revenant_initWithSource:(HKSource *)source version:(nullable NSString *)version;
- (void)revenant_setProductType:(nullable NSString *)productType
     operatingSystemVersion:(NSOperatingSystemVersion)operatingSystemVersion;
- (nullable NSString *)revenant_storedProductType;
- (NSOperatingSystemVersion)revenant_storedOperatingSystemVersion;
- (instancetype)revenant_initWithSource:(HKSource *)source version:(nullable NSString *)version;
@end

@interface HKDeletedObject (RevenantInternal)
- (instancetype)revenant_initWithUUID:(NSUUID *)uuid;
- (nullable NSDictionary<NSString *, id> *)revenant_deletedMetadata;
@end

@interface HKFitzpatrickSkinTypeObject (RevenantInternal)
+ (instancetype)revenant_fitzpatrickSkinTypeObject:(HKFitzpatrickSkinType)skinType;
@end

@interface HKWheelchairUseObject (RevenantInternal)
+ (instancetype)revenant_wheelchairUseObject:(HKWheelchairUse)wheelchairUse;
@end

@interface HKDocumentSample (RevenantInternal10)
- (instancetype)revenant_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document;
@end

@interface HKCDADocument (RevenantInternal10)
- (instancetype)revenant_initWithDocumentData:(NSData *)documentData
                                      title:(nullable NSString *)title
                                 patientName:(nullable NSString *)patientName
                                  authorName:(nullable NSString *)authorName
                               custodianName:(nullable NSString *)custodianName;
@end

@interface HKWorkoutConfiguration (RevenantInternal10)
- (instancetype)revenant_initWithActivityType:(HKWorkoutActivityType)activityType
                               locationType:(HKWorkoutSessionLocationType)locationType
                                 lapLength:(nullable HKQuantity *)lapLength
                       swimmingLocationType:(HKWorkoutSwimmingLocationType)swimmingLocationType;
@end

@interface HKDocumentSample (RevenantIOS100Internal)
- (instancetype)revenant_copyWithoutDocument:(nullable NSDictionary *)metadata;
- (void)revenant_setMetadata:(nullable NSDictionary *)metadata;
@end

@interface HKWorkoutEvent (RevenantIOS100Internal)
- (instancetype)revenant_initWithType:(HKWorkoutEventType)type date:(NSDate *)date;
- (nullable NSDictionary *)revenant_storedMetadata;
- (void)revenant_setMetadata:(nullable NSDictionary *)metadata;
- (nullable NSDateInterval *)revenant_storedDateInterval;
- (void)revenant_setDateInterval:(nullable NSDateInterval *)dateInterval;
@end

@interface HKObject (RevenantIOS9)
- (nullable HKSourceRevision *)sourceRevision;
- (nullable HKDevice *)device;
- (void)revenant_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device;
@end

@interface HKBiologicalSexObject (RevenantInternal)
+ (instancetype)revenant_biologicalSexObject:(HKBiologicalSex)biologicalSex;
@end

@interface HKBloodTypeObject (RevenantInternal)
+ (instancetype)revenant_bloodTypeObject:(HKBloodType)bloodType;
@end

@interface HKQueryAnchor (RevenantInternal)
+ (instancetype)revenant_anchorWithSequence:(NSInteger)sequence;
- (NSInteger)revenant_sequence;
@end

extern NSError *RevenantHKError(NSInteger code, NSString *description, NSString * _Nullable debug);

extern void revenant_hk_say_once(NSString *key, NSString *text);

extern NSString *RevenantHKStorePath(void);

#define REVENANT_HEALTHKIT_UNCREATABLE_INIT                                                  \
    -(instancetype)init                                                                    \
    {                                                                                     \
        [NSException raise:NSInvalidArgumentException                                      \
                        format:@"The -init method is not available on %@",                 \
                               NSStringFromClass([self class])];                            \
        return nil;                                                                       \
    }

NS_ASSUME_NONNULL_END
