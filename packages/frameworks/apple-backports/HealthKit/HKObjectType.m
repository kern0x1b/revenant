#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"
#import "RevenantHKTypes.h"

#pragma mark - HKObjectType

@implementation HKObjectType {
    NSString *_identifier;
}
REVENANT_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)revenant_typeWithIdentifier:(NSString *)identifier
{
    HKObjectType *type = [[self alloc] revenant_initWithIdentifier:identifier];
    return type;
}

- (instancetype)revenant_initWithIdentifier:(NSString *)identifier
{
    HKObjectType *fresh = [super init];
    if (fresh)
        fresh->_identifier = [identifier copy] ?: @"";
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self revenant_initWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] revenant_typeWithIdentifier:_identifier];
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSInteger)revenant_storeKind
{
    return RevenantHKTypeKindCharacteristic;
}

- (void)revenant_setCanonicalUnitString:(NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle
{
}

- (NSInteger)revenant_aggregationStyleValue
{
    return RevenantHKAggregationDiscreteArithmetic;
}

- (NSString *)revenant_canonicalUnitString
{
    return nil;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isMemberOfClass:[self class]])
        return NO;
    return [_identifier isEqualToString:((HKObjectType *)other).identifier];
}

- (NSUInteger)hash
{
    return _identifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@", NSStringFromClass(self.class), _identifier];
}

#pragma mark The table of types

+ (nullable HKQuantityType *)quantityTypeForIdentifier:(HKQuantityTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!RevenantHKHasTypeIdentifier(identifier, RevenantHKTypeKindQuantity))
        return nil;
    HKQuantityType *type = [HKQuantityType revenant_typeWithIdentifier:identifier];
    const RevenantHKTypeEntry *entry = RevenantHKQuantityTypeEntry(identifier);
    [type revenant_setCanonicalUnitString:entry->unit aggregationStyle:entry->aggregation];
    return type;
}

+ (nullable HKCategoryType *)categoryTypeForIdentifier:(HKCategoryTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!RevenantHKHasTypeIdentifier(identifier, RevenantHKTypeKindCategory))
        return nil;
    return [HKCategoryType revenant_typeWithIdentifier:identifier];
}

+ (nullable HKCharacteristicType *)characteristicTypeForIdentifier:(HKCharacteristicTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!RevenantHKHasTypeIdentifier(identifier, RevenantHKTypeKindCharacteristic))
        return nil;
    return [HKCharacteristicType revenant_typeWithIdentifier:identifier];
}

+ (nullable HKCorrelationType *)correlationTypeForIdentifier:(HKCorrelationTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!RevenantHKHasTypeIdentifier(identifier, RevenantHKTypeKindCorrelation))
        return nil;
    return [HKCorrelationType revenant_typeWithIdentifier:identifier];
}

+ (HKWorkoutType *)workoutType
{
    static HKWorkoutType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKWorkoutType revenant_typeWithIdentifier:HKWorkoutTypeIdentifier];
    });
    return type;
}

@end

#pragma mark - HKSampleType

@implementation HKSampleType
@dynamic isMaximumDurationRestricted;
@dynamic maximumAllowedDuration;
@dynamic isMinimumDurationRestricted;
@dynamic minimumAllowedDuration;
@dynamic allowsRecalibrationForEstimates;
@end

#pragma mark - HKCharacteristicType

@implementation HKCharacteristicType
@end

#pragma mark - HKCategoryType

@implementation HKCategoryType

- (NSInteger)revenant_storeKind
{
    return RevenantHKTypeKindCategory;
}

@end

#pragma mark - HKCorrelationType

@implementation HKCorrelationType

- (NSInteger)revenant_storeKind
{
    return RevenantHKTypeKindCorrelation;
}

@end

#pragma mark - HKWorkoutType

@implementation HKWorkoutType

- (NSInteger)revenant_storeKind
{
    return RevenantHKTypeKindWorkout;
}

@end
