#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

#pragma mark - HKDocumentType

@implementation HKDocumentType
@end

@implementation HKObjectType (RevenantIOS100)

+ (nullable HKDocumentType *)documentTypeForIdentifier:(HKDocumentTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier isEqualToString:HKDocumentTypeIdentifierCDA])
        return nil;
    static HKDocumentType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKDocumentType revenant_typeWithIdentifier:HKDocumentTypeIdentifierCDA];
    });
    return type;
}

@end

#pragma mark - HKDocumentSample

@implementation HKDocumentSample {
    HKDocumentType *_documentType;
    NSDictionary *_revenantDocument;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)revenant_setMetadata:(nullable NSDictionary *)metadata
{
    [super revenant_setMetadata:metadata];
}

- (instancetype)revenant_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document
{
    HKDocumentSample *sample = [super revenant_initWithType:(HKSampleType *)documentType
                                                 metadata:metadata
                                                startDate:startDate
                                                  endDate:endDate];
    if (sample) {
        sample->_documentType = documentType;
        sample->_revenantDocument = [document copy];
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
        sample->_revenantDocument = [document copy];
    }
    return sample;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_documentType forKey:@"documentType"];
    [coder encodeObject:_revenantDocument forKey:@"document"];
}

- (instancetype)revenant_copyForStore
{
    HKDocumentSample *copy = [super revenant_copyForStore];
    if (copy) {
        copy->_documentType = [_documentType copy];
        copy->_revenantDocument = [_revenantDocument copy];
    }
    return copy;
}

- (HKDocumentType *)documentType
{
    return _documentType;
}

- (instancetype)revenant_copyWithoutDocument:(nullable NSDictionary *)metadata
{
    HKDocumentSample *copy = [self revenant_copyForStore];
    if (copy)
        [copy revenant_setMetadata:metadata];
    return copy;
}

@end

#pragma mark - HKCDADocumentSample

@interface HKCDADocumentSample (RevenantIOS100)
- (NSDictionary *)revenant_document;
@end

@interface HKCDADocument (RevenantIOS100)
- (instancetype)revenant_initWithDocumentData:(NSData *)documentData
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
    all[@"_revenant_document"] = facts;
    return [self CDADocumentSampleWithData:data startDate:startDate endDate:endDate metadata:all];
}

+ (instancetype)CDADocumentSampleWithData:(NSData *)data
                                startDate:(NSDate *)startDate
                                  endDate:(NSDate *)endDate
                                 metadata:(nullable NSDictionary<NSString *, id> *)metadata
{
    if (![data isKindOfClass:[NSData class]])
        data = [NSData data];
    NSDictionary *stored = metadata[@"_revenant_document"];
    NSMutableDictionary *facts = [stored mutableCopy] ?: [NSMutableDictionary dictionary];
    facts[@"data"] = [data copy];
    NSMutableDictionary *all = [metadata mutableCopy] ?: [NSMutableDictionary dictionary];
    all[@"_revenant_document"] = facts;
    HKDocumentType *type = [HKObjectType documentTypeForIdentifier:HKDocumentTypeIdentifierCDA];
    return [[self alloc] revenant_initWithType:type metadata:all startDate:startDate endDate:endDate document:facts];
}

- (void)revenant_setMetadata:(nullable NSDictionary *)metadata
{
    [super revenant_setMetadata:metadata];
}

- (instancetype)revenant_initWithType:(HKDocumentType *)documentType
                            metadata:(nullable NSDictionary *)metadata
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                            document:(nullable NSDictionary *)document
{
    HKCDADocumentSample *sample = [super revenant_initWithType:documentType
                                                  metadata:metadata
                                                 startDate:startDate
                                                   endDate:endDate
                                                  document:document];
    if (sample)
        sample->_documentData = [document[@"data"] copy];
    return sample;
}

- (nullable HKCDADocument *)document
{
    NSDictionary *facts = [self revenant_document];
    NSData *data = facts[@"data"];
    if (![data isKindOfClass:[NSData class]])
        return nil;
    return [[HKCDADocument alloc] revenant_initWithDocumentData:data
                                                        title:facts[@"title"]
                                                   patientName:facts[@"patientName"]
                                                    authorName:facts[@"authorName"]
                                                 custodianName:facts[@"custodianName"]];
}

- (NSDictionary *)revenant_document
{
    return [[self metadata][@"_revenant_document"] copy] ?: @{};
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

+ (instancetype)revenant_wheelchairUseObject:(HKWheelchairUse)wheelchairUse
{
    HKWheelchairUseObject *object = [[HKWheelchairUseObject alloc] revenant_initWithWheelchairUse:wheelchairUse];
    return object;
}

- (instancetype)revenant_initWithWheelchairUse:(HKWheelchairUse)wheelchairUse
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
    return [HKWheelchairUseObject revenant_wheelchairUseObject:_wheelchairUse];
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

- (instancetype)revenant_initWithActivityType:(HKWorkoutActivityType)activityType
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
    return [[HKWorkoutConfiguration alloc] revenant_initWithActivityType:_activityType
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
