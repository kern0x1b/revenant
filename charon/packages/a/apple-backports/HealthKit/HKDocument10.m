// The iOS 10.0 group: documents, the document query, the CDA document, the wheelchair use, the
// workout configuration, and the members of the earlier classes that arrived with them.
//
// One object per release, so each of these is a file of its own and the earlier classes' new members
// are in categories, where the SDK itself keeps them.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKDocumentType

@implementation HKDocumentType
@end

@implementation HKObjectType (CharonIOS100)

// The one document type of 10.0, CDA, held as a shared object the way +workoutType and
// +activitySummaryType are. An identifier the SDK's headers do not declare a document type for is
// refused, as the release refuses one it has no type for.
+ (nullable HKDocumentType *)documentTypeForIdentifier:(HKDocumentTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier isEqualToString:HKDocumentTypeIdentifierCDA])
        return nil;
    static HKDocumentType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKDocumentType charon_typeWithIdentifier:HKDocumentTypeIdentifierCDA];
    });
    return type;
}

@end

#pragma mark - HKDocumentSample

@implementation HKDocumentSample {
    HKDocumentType *_documentType;
    NSDictionary *_charonDocument;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)charon_setMetadata:(nullable NSDictionary *)metadata
{
    [super charon_setMetadata:metadata];
}

- (instancetype)charon_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document
{
    HKDocumentSample *sample = [super charon_initWithType:(HKSampleType *)documentType
                                                 metadata:metadata
                                                startDate:startDate
                                                  endDate:endDate];
    if (sample) {
        sample->_documentType = documentType;
        sample->_charonDocument = [document copy];
    }
    return sample;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKDocumentSample *sample = [super initWithCoder:coder];
    if (sample) {
        sample->_documentType = [[coder decodeObjectOfClass:[HKDocumentType class] forKey:@"documentType"] copy];
        NSDictionary *document = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class],
                                                                          [NSData class], [NSDate class], [NSNumber class], nil]
                                                 forKey:@"document"];
        sample->_charonDocument = [document copy];
    }
    return sample;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_documentType forKey:@"documentType"];
    [coder encodeObject:_charonDocument forKey:@"document"];
}

- (instancetype)charon_copyForStore
{
    HKDocumentSample *copy = [super charon_copyForStore];
    if (copy) {
        copy->_documentType = [_documentType copy];
        copy->_charonDocument = [_charonDocument copy];
    }
    return copy;
}

- (HKDocumentType *)documentType
{
    return _documentType;
}

// The same sample with a different metadata dictionary, which is how a document query that was asked
// not to include the document's data hands the sample back without it.
- (instancetype)charon_copyWithoutDocument:(nullable NSDictionary *)metadata
{
    HKDocumentSample *copy = [self charon_copyForStore];
    if (copy)
        [copy charon_setMetadata:metadata];
    return copy;
}

@end

#pragma mark - HKCDADocumentSample

// The document's own facts, which the header declares on HKCDADocument: the data, the title and the
// three names of the people it is about. They are kept where the store can hand them back, and a
// document the store was given keeps the dictionary it arrived as.
@interface HKCDADocumentSample (CharonIOS100)
- (NSDictionary *)charon_document;
@end

@interface HKCDADocument (CharonIOS100)
- (instancetype)charon_initWithDocumentData:(NSData *)documentData
                                      title:(nullable NSString *)title
                                 patientName:(nullable NSString *)patientName
                                  authorName:(nullable NSString *)authorName
                               custodianName:(nullable NSString *)custodianName;
@end

@implementation HKCDADocumentSample {
    NSDictionary *_documentData;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// A CDA document sample over the data given, with the validation error a later release's parser
// found. There is no such parser on this release and no such argument in iOS 10.0's own signature -
// the header adds it with 11.0 - so it is read out of the metadata dictionary the caller was given,
// under HKDetailedCDAValidationErrorKey, and the caller's dictionary is not otherwise changed.
+ (instancetype)CDADocumentSampleWithData:(NSData *)data
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
                                 metadata:(nullable NSDictionary<NSString *, id> *)metadata
                           validationError:(nullable NSError *)validationError
{
    NSMutableDictionary *facts = [NSMutableDictionary dictionaryWithCapacity:4];
    facts[@"data"] = data;
    if (validationError)
        facts[HKDetailedCDAValidationErrorKey] = validationError;
    NSMutableDictionary *all = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
    all[@"_charon_document"] = facts;
    return [self CDADocumentSampleWithData:data startDate:startDate endDate:endDate metadata:all];
}

+ (instancetype)CDADocumentSampleWithData:(NSData *)data
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
                                 metadata:(nullable NSDictionary<NSString *, id> *)metadata
{
    if (![data isKindOfClass:[NSData class]])
        data = [NSData data];
    NSDictionary *stored = metadata[@"_charon_document"];
    NSMutableDictionary *facts = [stored mutableCopy] ?: [NSMutableDictionary dictionary];
    facts[@"data"] = [data copy];
    NSMutableDictionary *all = [metadata mutableCopy] ?: [NSMutableDictionary dictionary];
    all[@"_charon_document"] = facts;
    HKDocumentType *type = [HKObjectType documentTypeForIdentifier:HKDocumentTypeIdentifierCDA];
    return [[self alloc] charon_initWithType:type metadata:all startDate:startDate endDate:endDate document:facts];
}

- (void)charon_setMetadata:(nullable NSDictionary *)metadata
{
    [super charon_setMetadata:metadata];
}

- (instancetype)charon_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document
{
    HKCDADocumentSample *sample = [super charon_initWithType:documentType
                                                  metadata:metadata
                                                 startDate:startDate
                                                   endDate:endDate
                                                  document:document];
    if (sample)
        sample->_documentData = [document[@"data"] copy];
    return sample;
}

// The document, as the four members of the header spell it over one dictionary: the data, the title
// and the three names.
- (nullable HKCDADocument *)document
{
    NSDictionary *facts = [self charon_document];
    NSData *data = facts[@"data"];
    if (![data isKindOfClass:[NSData class]])
        return nil;
    return [[HKCDADocument alloc] charon_initWithDocumentData:data
                                                        title:facts[@"title"]
                                                   patientName:facts[@"patientName"]
                                                    authorName:facts[@"authorName"]
                                                 custodianName:facts[@"custodianName"]];
}

- (NSDictionary *)charon_document
{
    return [[self metadata][@"_charon_document"] copy] ?: @{};
}

@end

#pragma mark - HKWheelchairUseObject

@implementation HKWheelchairUseObject {
    HKWheelchairUse _wheelchairUse;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_wheelchairUseObject:(HKWheelchairUse)wheelchairUse
{
    HKWheelchairUseObject *object = [[HKWheelchairUseObject alloc] charon_initWithWheelchairUse:wheelchairUse];
    return object;
}

- (instancetype)charon_initWithWheelchairUse:(HKWheelchairUse)wheelchairUse
{
    HKWheelchairUseObject *fresh = [super init];
    if (fresh)
        fresh->_wheelchairUse = wheelchairUse;
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKWheelchairUseObject *fresh = [super init];
    if (fresh)
        fresh->_wheelchairUse = (HKWheelchairUse)[coder decodeIntegerForKey:@"wheelchairUse"];
    return fresh;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_wheelchairUse forKey:@"wheelchairUse"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKWheelchairUseObject charon_wheelchairUseObject:_wheelchairUse];
}

- (HKWheelchairUse)wheelchairUse
{
    return _wheelchairUse;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKWheelchairUseObject %ld", (long)_wheelchairUse];
}

@end

#pragma mark - HKWorkoutConfiguration

// A workout's configuration: what kind it is, where it happened, and the two lengths the rings of a
// lap swim and a cycle are measured in. Every member the header gives is kept and read back.
@implementation HKWorkoutConfiguration {
    HKWorkoutActivityType _activityType;
    HKWorkoutSessionLocationType _locationType;
    HKQuantity *_lapLength;
    HKWorkoutSwimmingLocationType _swimmingLocationType;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_initWithActivityType:(HKWorkoutActivityType)activityType
                               locationType:(HKWorkoutSessionLocationType)locationType
                                 lapLength:(nullable HKQuantity *)lapLength
                       swimmingLocationType:(HKWorkoutSwimmingLocationType)swimmingLocationType
{
    HKWorkoutConfiguration *configuration = [super init];
    if (configuration) {
        configuration->_activityType = activityType;
        configuration->_locationType = locationType;
        configuration->_lapLength = (HKQuantity *)[lapLength copy];
        configuration->_swimmingLocationType = swimmingLocationType;
    }
    return configuration;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKWorkoutConfiguration *configuration = [super init];
    if (configuration) {
        configuration->_activityType = (HKWorkoutActivityType)[coder decodeIntegerForKey:@"activityType"];
        configuration->_locationType = (HKWorkoutSessionLocationType)[coder decodeIntegerForKey:@"locationType"];
        configuration->_lapLength = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"lapLength"] copy];
        configuration->_swimmingLocationType = (HKWorkoutSwimmingLocationType)[coder decodeIntegerForKey:@"swimmingLocationType"];
    }
    return configuration;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_activityType forKey:@"activityType"];
    [coder encodeInteger:(NSInteger)_locationType forKey:@"locationType"];
    [coder encodeObject:_lapLength forKey:@"lapLength"];
    [coder encodeInteger:(NSInteger)_swimmingLocationType forKey:@"swimmingLocationType"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[HKWorkoutConfiguration alloc] charon_initWithActivityType:_activityType
                                                        locationType:_locationType
                                                          lapLength:_lapLength
                                                swimmingLocationType:_swimmingLocationType];
}

- (HKWorkoutActivityType)activityType
{
    return _activityType;
}

- (HKWorkoutSessionLocationType)locationType
{
    return _locationType;
}

- (nullable HKQuantity *)lapLength
{
    return _lapLength;
}

- (HKWorkoutSwimmingLocationType)swimmingLocationType
{
    return _swimmingLocationType;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKWorkoutConfiguration %ld at %ld", (long)_activityType, (long)_locationType];
}

@end
