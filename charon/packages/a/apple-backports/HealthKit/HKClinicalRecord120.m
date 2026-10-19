// The clinical record of iOS 12.0: the record, the FHIR resource behind it, and the type that says
// which kind of record it is.
//
// One object per release: this file is of 12.0 alone.
//
// A clinical record is a sample whose start and end dates are both the day it was added to Health,
// which is what the header's own discussion says and what this port does, so that a predicate over a
// period finds it. Its UUID is not stable, the header says, and the port does not pretend otherwise: the
// stable identity a caller is told to use is the combination of the source, the FHIR resource type and
// the FHIR identifier, and those three are kept and the two predicates of HKQuery are built over them.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKClinicalType

@implementation HKClinicalType
@end

@implementation HKObjectType (CharonIOS120)

// The clinical type of the identifier given, and nil for one that is not a clinical type. The header
// marks this class method deprecated in favour of a Swift initialiser and un-deprecated for the others,
// and this port answers the one every C caller uses, which is the one the corpus carries.
+ (nullable HKClinicalType *)clinicalTypeForIdentifier:(HKClinicalTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || ![identifier hasPrefix:@"HKClinicalTypeIdentifier"])
        return nil;
    static NSSet *known;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // the seven identifiers of 12.0, as the constants of that release hold them - each value was
        // read out of the HealthKit image of the arm64 shared cache of iOS 12.0, and HKConstants120.m
        // is the file that defines them
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

// The FHIR resource behind a clinical record: its version, its type, its identifier, its data and where
// it came from. The header closes off -init, so the resource is made the way the release makes it -
// through -initWithResourceType:identifier:data: - which this port declares of itself and the store
// uses when it reads a record back.
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

// FHIRVersion is of 14.0 and this group is of 12.0, so the property is @dynamic: the compiler emits no
// accessor, the selector is not in the library, and -respondsToSelector: answers NO for it rather than
// an accessor that would answer nil and look like a version this library has.
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

// The base allocation: the header closes off -init and gives no initialiser at all, so this is the
// port's own path and the factory above is the only way a caller makes one.
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

// This class is one the store keeps, so it adopts the protocol the store's gate tests for. Every
// member of that protocol is inherited from HKObject - the row's own facts, the archive and the
// class method that reads one back through this class's own -initWithCoder:. The declaration was
// missing, so -[CharonHKStore saveObjects:error:] refused this class and every other, with
// "is not a health object this database can keep".
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
    // The start and the end are the day the record was added, which is what the header's own
    // discussion says of the two dates, so a predicate over a period finds it.
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

// The FHIR resource behind the record, the one the header says is where applicable, and nil where the
// record has none - the header makes it nullable and this port keeps it so.
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

// The three facts the header says make a record's identity: the source, the resource type and the
// resource identifier. The two key paths are the ones the 12.0 image holds as
// "FHIRResource.identifier" and "FHIRResource.resourceType".
+ (NSPredicate *)predicateForClinicalRecordsFromSource:(HKSource *)source
                                        FHIRResourceType:(HKFHIRResourceType)resourceType
                                             identifier:(NSString *)identifier
{
    // A term for each of the three, whatever was given, and one that is a term for a value that was
    // not given: the host's own answers keep the nil terms, so a query with a resource type and an
    // identifier and no source is `source == nil AND …` and not the two terms alone. Measured by
    // tests/backports/host/healthkit, where the port's format was the two terms and the host's three.
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

// This class is one the store keeps, so it adopts the protocol the store's gate tests for. Every
// member of that protocol is inherited from HKObject - the row's own facts, the archive and the
// class method that reads one back through this class's own -initWithCoder:. The adoption was
// missing, so -[CharonHKStore saveObjects:error:] refused this class and every other, with
// "is not a health object this database can keep".

// These classes are ones the store keeps, so each adopts the protocol the store's gate tests for.
// Every member of that protocol is inherited from HKObject - the row's own facts, the archive and
// the class method that reads one back through the class's own -initWithCoder:. The adoption was
// missing, so -[CharonHKStore saveObjects:error:] refused these classes and every other, with
// "is not a health object this database can keep", and the two builders of 12.0 saved into a
// store that took nothing. Conformance is declared on a category interface and not repeated on
// its implementation, which is where Objective-C takes it.
@interface HKClinicalRecord (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKClinicalRecord (CharonHKStorable)
@end

