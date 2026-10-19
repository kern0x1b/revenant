#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKClinicalType

@implementation HKClinicalType
@end

@implementation HKObjectType (CharonIOS120)

+ (nullable HKClinicalType *)clinicalTypeForIdentifier:(HKClinicalTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier hasPrefix:@"HKClinicalTypeIdentifier"])
        return nil;
    static NSSet *known;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        known = [NSSet setWithObjects:HKClinicalTypeIdentifierAllergyRecord,
                                 HKClinicalTypeIdentifierConditionRecord,
                                 HKClinicalTypeIdentifierImmunizationRecord,
                                 HKClinicalTypeIdentifierLabResultRecord,
                                 HKClinicalTypeIdentifierMedicationRecord,
                                 HKClinicalTypeIdentifierProcedureRecord,
                                 HKClinicalTypeIdentifierVitalSignRecord, nil];
    });
    if (![known containsObject:identifier])
        return nil;
    return [HKClinicalType charon_typeWithIdentifier:identifier];
}

@end

#pragma mark - HKFHIRResource

@interface HKFHIRResource (CharonIOS120)
+ (nullable instancetype)charon_resourceWithType:(HKFHIRResourceType)resourceType
                                      identifier:(NSString *)identifier
                                            data:(NSData *)data
                                       sourceURL:(nullable NSURL *)sourceURL;
@end

@implementation HKFHIRResource {
    HKFHIRResourceType _resourceType;
    NSString *_identifier;
    NSData *_data;
    NSURL *_sourceURL;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

@dynamic FHIRVersion;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_resourceWithType:(HKFHIRResourceType)resourceType
                             identifier:(NSString *)identifier
                                   data:(NSData *)data
                              sourceURL:(nullable NSURL *)sourceURL
{
    HKFHIRResource *resource = [[self alloc] charon_init];
    if (resource) {
        resource->_resourceType = [resourceType copy];
        resource->_identifier = [identifier copy] ?: @"";
        resource->_data = [data copy] ?: [NSData data];
        resource->_sourceURL = [sourceURL copy];
    }
    return resource;
}

- (instancetype)charon_init
{
    return [super init];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKFHIRResource *resource = [super init];
    if (resource) {
        resource->_resourceType = [[coder decodeObjectOfClass:[NSString class] forKey:@"resourceType"] copy];
        resource->_identifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] copy] ?: @"";
        resource->_data = [[coder decodeObjectOfClass:[NSData class] forKey:@"data"] copy] ?: [NSData data];
        resource->_sourceURL = [[coder decodeObjectOfClass:[NSURL class] forKey:@"sourceURL"] copy];
    }
    return resource;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_resourceType forKey:@"resourceType"];
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_data forKey:@"data"];
    [coder encodeObject:_sourceURL forKey:@"sourceURL"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKFHIRResource charon_resourceWithType:_resourceType identifier:_identifier data:_data sourceURL:_sourceURL];
}

- (HKFHIRResourceType)resourceType
{
    return _resourceType;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSData *)data
{
    return _data;
}

- (nullable NSURL *)sourceURL
{
    return _sourceURL;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKFHIRResource[%@ %@]", _resourceType, _identifier];
}

@end

#pragma mark - HKClinicalRecord

@implementation HKClinicalRecord {
    HKClinicalType *_clinicalType;
    NSString *_displayName;
    HKFHIRResource *_FHIRResource;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_recordWithType:(HKClinicalType *)clinicalType
                          displayName:(NSString *)displayName
                         FHIRResource:(nullable HKFHIRResource *)resource
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                             metadata:(nullable NSDictionary *)metadata
{
    HKClinicalRecord *record = [[self alloc] charon_initWithType:(HKSampleType *)clinicalType
                                                        metadata:metadata
                                                       startDate:startDate
                                                         endDate:endDate];
    if (record) {
        record->_clinicalType = clinicalType;
        record->_displayName = [displayName copy] ?: @"";
        record->_FHIRResource = (HKFHIRResource *)[resource copy];
    }
    return record;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKClinicalRecord *record = [super initWithCoder:coder];
    if (record) {
        record->_clinicalType = [[coder decodeObjectOfClass:[HKClinicalType class] forKey:@"clinicalType"] copy];
        record->_displayName = [[coder decodeObjectOfClass:[NSString class] forKey:@"displayName"] copy] ?: @"";
        record->_FHIRResource = [[coder decodeObjectOfClass:[HKFHIRResource class] forKey:@"FHIRResource"] copy];
    }
    return record;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_clinicalType forKey:@"clinicalType"];
    [coder encodeObject:_displayName forKey:@"displayName"];
    [coder encodeObject:_FHIRResource forKey:@"FHIRResource"];
}

- (instancetype)charon_copyForStore
{
    HKClinicalRecord *copy = [super charon_copyForStore];
    if (copy) {
        copy->_clinicalType = [_clinicalType copy];
        copy->_displayName = [_displayName copy];
        copy->_FHIRResource = (HKFHIRResource *)[_FHIRResource copy];
    }
    return copy;
}

- (NSString *)charon_storeTypeIdentifier
{
    return _clinicalType.identifier ?: @"";
}

- (NSInteger)charon_storeKind
{
    return 4;
}

- (HKClinicalType *)clinicalType
{
    return _clinicalType;
}

- (NSString *)displayName
{
    return _displayName;
}

- (nullable HKFHIRResource *)FHIRResource
{
    return _FHIRResource;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKClinicalRecord %@ %@", _clinicalType.identifier, _displayName];
}

@end

#pragma mark - HKQuery

@implementation HKQuery (CharonIOS120)

+ (NSPredicate *)predicateForClinicalRecordsFromSource:(HKSource *)source
                                        FHIRResourceType:(HKFHIRResourceType)resourceType
                                             identifier:(NSString *)identifier
{
    NSMutableArray<NSPredicate *> *parts = [NSMutableArray array];
    [parts addObject:[NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathSource, source]];
    [parts addObject:[NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathClinicalRecordFHIRResourceType, resourceType]];
    [parts addObject:[NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathClinicalRecordFHIRResourceIdentifier, identifier]];
    if (parts.count == 1)
        return parts[0];
    return [NSCompoundPredicate andPredicateWithSubpredicates:parts];
}

+ (NSPredicate *)predicateForClinicalRecordsWithFHIRResourceType:(HKFHIRResourceType)resourceType
{
    if (![resourceType isKindOfClass:[NSString class]] || !resourceType.length)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K == %@", HKPredicateKeyPathClinicalRecordFHIRResourceType, resourceType];
}

@end

@interface HKClinicalRecord (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKClinicalRecord (CharonHKStorable)
@end
