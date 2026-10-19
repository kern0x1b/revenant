#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"
#import "CharonHKTypes.h"

#pragma mark - HKObjectType

@implementation HKObjectType {
    NSString *_identifier;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_typeWithIdentifier:(NSString *)identifier
{
    HKObjectType *type = [[self alloc] charon_initWithIdentifier:identifier];
    return type;
}

- (instancetype)charon_initWithIdentifier:(NSString *)identifier
{
    HKObjectType *fresh = [super init];
    if (fresh)
        fresh->_identifier = [identifier copy] ?: @"";
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"identifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] charon_typeWithIdentifier:_identifier];
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSInteger)charon_storeKind
{
    return CharonHKTypeKindCharacteristic;
}

- (void)charon_setCanonicalUnitString:(NSString *)unitString aggregationStyle:(NSInteger)aggregationStyle
{
}

- (NSInteger)charon_aggregationStyleValue
{
    return CharonHKAggregationDiscreteArithmetic;
}

- (NSString *)charon_canonicalUnitString
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
    if (!CharonHKHasTypeIdentifier(identifier, CharonHKTypeKindQuantity))
        return nil;
    HKQuantityType *type = [HKQuantityType charon_typeWithIdentifier:identifier];
    const CharonHKTypeEntry *entry = CharonHKQuantityTypeEntry(identifier);
    [type charon_setCanonicalUnitString:entry->unit aggregationStyle:entry->aggregation];
    return type;
}

+ (nullable HKCategoryType *)categoryTypeForIdentifier:(HKCategoryTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!CharonHKHasTypeIdentifier(identifier, CharonHKTypeKindCategory))
        return nil;
    return [HKCategoryType charon_typeWithIdentifier:identifier];
}

+ (nullable HKCharacteristicType *)characteristicTypeForIdentifier:(HKCharacteristicTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!CharonHKHasTypeIdentifier(identifier, CharonHKTypeKindCharacteristic))
        return nil;
    return [HKCharacteristicType charon_typeWithIdentifier:identifier];
}

+ (nullable HKCorrelationType *)correlationTypeForIdentifier:(HKCorrelationTypeIdentifier)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || !identifier.length)
        return nil;
    if (!CharonHKHasTypeIdentifier(identifier, CharonHKTypeKindCorrelation))
        return nil;
    return [HKCorrelationType charon_typeWithIdentifier:identifier];
}

+ (HKWorkoutType *)workoutType
{
    static HKWorkoutType *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        type = [HKWorkoutType charon_typeWithIdentifier:HKWorkoutTypeIdentifier];
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

- (NSInteger)charon_storeKind
{
    return CharonHKTypeKindCategory;
}

@end

#pragma mark - HKCorrelationType

@implementation HKCorrelationType

- (NSInteger)charon_storeKind
{
    return CharonHKTypeKindCorrelation;
}

@end

#pragma mark - HKWorkoutType

@implementation HKWorkoutType

- (NSInteger)charon_storeKind
{
    return CharonHKTypeKindWorkout;
}

@end
