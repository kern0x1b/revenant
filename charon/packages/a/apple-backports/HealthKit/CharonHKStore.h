// What the store keeps, and the private surface the classes of this framework share with it.
//
// Nothing here is API. Every name in this header and in the .m files that carry it begins with
// Charon or charon_, which the linker is told to hide, so no symbol of ours is exported under a name
// a release could answer for.

#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

NS_ASSUME_NONNULL_BEGIN

// What an object's row in the store holds, as this store records it: the sample itself archived, and
// the few facts SQLite has to narrow a query by.
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
// The object as it was archived: its own class, its own NSSecureCoding.
@property (readonly, copy) NSData *archive;
@end

// The one store the process's HKHealthStore objects share. A SQLite database under Application
// Support, opened on first use. The release runs no healthd and carries no health database, so this
// database is what stands in for it; what goes in it and what comes out is the objects' own
// NSSecureCoding, and what decides which of them a query sees is SQLite's and the release's own
// NSPredicate.
@interface CharonHKStore : NSObject

+ (CharonHKStore *)sharedStore;

@property (readonly, copy) NSString *path;
@property (readonly, getter=isOpen) BOOL open;
- (BOOL)openWithError:(NSError **)error;

// Every object the process saves is written under the type it names, so that a query can be narrowed
// by type and by date before anything is unarchived. A row also carries the source revision the
// process wrote it under, which is the process's own CFBundleVersion, and the device the sample names,
// so that -sourceRevision and -device read back what was saved.
- (BOOL)declareType:(HKObjectType *)type error:(NSError **)error;
- (nullable HKObjectType *)typeWithIdentifier:(NSString *)identifier;

// What the last authorization request recorded, and the store's enforcement of it: a save of a type
// the process may not share fails, and a query that finds a type it may not read returns nothing.
- (BOOL)recordAuthorizationToShare:(nullable NSSet *)typesToShare read:(nullable NSSet *)typesToRead error:(NSError **)error;
- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type;
- (BOOL)mayReadType:(HKObjectType *)type;
- (BOOL)mayShareType:(HKObjectType *)type;

// The characteristics of the user, kept as the plist of what the characteristic objects archive.
- (nullable id)characteristicForIdentifier:(NSString *)identifier;
- (BOOL)setCharacteristic:(nullable id)value forIdentifier:(NSString *)identifier error:(NSError **)error;

- (BOOL)saveObjects:(NSArray *)objects error:(NSError **)error;
// The samples of a workout, kept in the same table a correlation's members are, so that
// +[HKQuery predicateForObjectsFromWorkout:] finds them through the store's own relationship.
- (BOOL)addSamples:(NSArray *)samples toWorkout:(HKObject *)workout error:(NSError **)error;
- (BOOL)deleteObjects:(NSArray *)objects error:(NSError **)error;
- (NSUInteger)deleteObjectsOfType:(HKObjectType *)type predicate:(nullable NSPredicate *)predicate error:(NSError **)error;

// The objects of a type the store holds, newest last. A predicate is evaluated by the release's own
// NSPredicate, over the objects read back, after SQLite has narrowed by type and by date.
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
// The objects deleted after a position, as the HKDeletedObject instances an anchored query of iOS 9
// answers with. The store's own deleted table is where they come from.
- (nullable NSArray *)deletedObjectsSinceSequence:(NSInteger)sequence;

// A finished workout route, kept against the workout it belongs to and the device it was made on, and
// the bytes of a route. The bytes are what the builder inserted, in the order it inserted them; this
// port does not parse Apple's encoded path, and the header's own -insertRouteData: takes those bytes.
- (void)setWorkoutRoute:(HKWorkoutRoute *)route
             forWorkout:(HKWorkout *)workout
                 device:(nullable HKDevice *)device
              metadata:(nullable NSDictionary *)metadata
                 error:(NSError **)error;
- (NSData *)routeDataOf:(HKWorkoutRoute *)route;
+ (NSData *)charon_routeDataOf:(HKWorkoutRoute *)route;

// The documents of one type, with their own data or without it, the way a document query asks.
- (nullable NSArray *)documentsOfType:(HKDocumentType *)type
                            predicate:(nullable NSPredicate *)predicate
                               limit:(NSUInteger)limit
                    sortDescriptors:(nullable NSArray *)sortDescriptors
                 includeDocumentData:(BOOL)includeDocumentData
                             error:(NSError **)error;

// The activity summaries the store holds that a predicate matches. The rings are counted by the phone
// and recorded by the Activity application of a release that has one; nothing writes this table on
// this release, so the answer is an empty array and the reason is said once in the log.
- (NSArray *)activitySummariesMatching:(nullable NSPredicate *)predicate error:(NSError **)error;

// Every source the store holds a sample from, and the order the owner set for a type.
- (NSArray *)allSources;
- (NSArray *)sourcesForType:(HKObjectType *)type;
- (BOOL)deleteSourceWithBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
- (BOOL)setOrderedSources:(NSArray *)sources forType:(HKObjectType *)type error:(NSError **)error;

// Background delivery: the (type, frequency) pairs the process asked to be woken for. There is no
// healthd to wake it, so nothing is woken; the registration is kept and read back by a later call.
- (BOOL)setBackgroundDelivery:(BOOL)enabled forType:(HKObjectType *)type frequency:(NSUInteger)frequency error:(NSError **)error;
- (BOOL)disableAllBackgroundDeliveryWithError:(NSError **)error;

// The anchor of a running query, kept against its activation UUID.
- (nullable id)anchorForActivationUUID:(NSUUID *)uuid;
- (void)setAnchor:(nullable id)anchor forActivationUUID:(NSUUID *)uuid;

// Who is watching: an observer query, an anchored query, a statistics collection. Every write and
// every delete tells each of them what changed, as this database's own did.
- (void)addObserver:(id)observer forTypes:(nullable NSSet *)types;
- (void)removeObserver:(id)observer;

@end

// The private surface a class of this framework answers with, so that the store can read an object
// and a type without either one's own header having to name the other. Each is implemented in the
// class's own @implementation, never in a category, so none of them is a selector the registry has
// to describe as a member this port adds to somebody else's class.
@protocol CharonHKStorable <NSObject>
+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store;
// The row's own facts, which SQLite indexes and narrows by.
- (NSString *)charon_storeTypeIdentifier;
- (NSInteger)charon_storeKind;
// The archive of the receiver, as NSSecureCoding writes it: the class name, then the properties.
- (NSData *)charon_storeArchive;
+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store;
@end

// Who is watching the store. Every write and every delete tells each of them what changed, as this
// database's own did: an observer query is answered with everything written since it last ran, and an
// anchored query with the objects that changed and the sequence past them.
@protocol CharonHKStoreObserver <NSObject>
- (void)charon_storeDidChange:(NSArray<NSUUID *> *)identifiers;
@end

// What HKHealthStore asks of a query, whatever its subclass: run it once against the store, and stop
// it when the caller says so.
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

// Which class a row of the store holds, from the kind its row records, and which class a type
// identifier names, from the kind the store keeps for it. Both are answered by name and looked up, so
// that the store names no class of this framework as a symbol and the file that defines a class
// stays the only one that carries it.
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

// The private surface of the classes of this framework that another of them needs. Declared here and
// implemented in each class's own @implementation, so that none of it is a selector this port adds
// to somebody else's class and none of it needs a category.
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

// What the iOS 9.0 form of an anchored query needs from the query of iOS 8.0 underneath it, which is
// not in a header of its own: the two handlers, and whether the query stops itself once the results
// handler has run or keeps running to be told with the update handler.
@interface HKAnchoredObjectQuery (CharonInternal)
@property (nonatomic, copy, nullable) void (^charon_updateHandler)(HKAnchoredObjectQuery *query,
                                                                    NSArray<HKSample *> *_Nullable added,
                                                                    NSArray<HKDeletedObject *> *_Nullable deleted,
                                                                    HKQueryAnchor *_Nullable anchor,
                                                                    NSError *_Nullable error);
@property (nonatomic) BOOL charon_stopsAfterResults;
@property (nonatomic) NSUInteger charon_limit;
// The handler of the iOS 9.0 initialiser, which is a different selector and a different shape from the
// one of iOS 8.0: an object anchor in, the deletions as objects out.
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
// The base of every query subclass's initialiser. It is an instance method and its name is in the init
// family, which is what lets a subclass write `self = [super initWithCharonObjectType:...]` and set its
// own ivars after: a category's class method is not visible through a subclass type, and a class
// extension declared in this header is visible only to the one file that implements HKQuery, so
// neither would reach the five subclass files that call it. -init is NS_UNAVAILABLE on HKQuery, so this
// is the port's own allocation and the path that leaves a query with its type, its predicate and its
// handler.
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
// The process's own version, out of its Info.plist, which is what the source revision of everything it
// saves carries; nil where the plist names none, which is what the release's own is.
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

// The error this framework answers with: of HKErrorDomain, with the release's own code, and the
// release's own localized description where there is one.
extern NSError *CharonHKError(NSInteger code, NSString *description, NSString * _Nullable debug);

// One line in the log, once per key, for what this port does not do.
extern void charon_hk_say_once(NSString *key, NSString *text);

// Where the database is: Application Support, or the temporary directory where this release has no
// Application Support of its own to create it in.
extern NSString *CharonHKStorePath(void);

// -init, for the classes whose own framework closes it. Seven of this framework's classes declare
// `- (instancetype)init NS_UNAVAILABLE;` in their SDK 26.2 header, and NS_UNAVAILABLE decides nothing at
// run time, so what Apple's own class does is the question. Measured on the host's own HealthKit, over
// all seven, in tests/backports/host/unavailable-init:
//
//   - six implement -init and it raises NSInvalidArgumentException whose reason is Apple's own text and
//     names the class: "The -init method is not available on HKClinicalRecord", and the same sentence
//     with each of the other five. The macro below is that sentence, with the class read off the
//     receiver, because the framework builds it the same way;
//   - one, HKDeletedObject, implements neither selector, so the port defines nothing there either - a
//     definition would put -init in the port's metadata where Apple's has none and answer the caller
//     exactly what NSObject's already answers.
//
// +new is not in the macro and not in any of the six blocks, and that is the other half of the
// measurement: own-new is 0 for all seven, so Apple's classes inherit NSObject's +new, which is
// +alloc/-init and therefore reaches the raise above. The iOS 16.0 cache agrees with the host on both
// questions for all seven (tools/corpus/objc-inventory.lua over the arm64e cache).
#define CHARON_HEALTHKIT_UNCREATABLE_INIT                                                  \
    -(instancetype)init                                                                    \
    {                                                                                     \
        [NSException raise:NSInvalidArgumentException                                      \
                        format:@"The -init method is not available on %@",                 \
                               NSStringFromClass([self class])];                            \
        return nil;                                                                       \
    }

NS_ASSUME_NONNULL_END
