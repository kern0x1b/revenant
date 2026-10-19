#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKCategorySample

@implementation HKCategorySample {
    NSInteger _value;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)categorySampleWithType:(HKCategoryType *)type
                                          value:(NSInteger)value
                                      startDate:(NSDate *)startDate
                                        endDate:(NSDate *)endDate
{
    return [self categorySampleWithType:type value:value startDate:startDate endDate:endDate metadata:nil];
}

+ (instancetype)categorySampleWithType:(HKCategoryType *)type
                                          value:(NSInteger)value
                                      startDate:(NSDate *)startDate
                                        endDate:(NSDate *)endDate
                                       metadata:(nullable NSDictionary *)metadata
{
    if (![type isKindOfClass:[HKCategoryType class]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a category type; a category sample is made with one of +[HKObjectType categoryTypeForIdentifier:].",
                           type];
        return nil;
    }
    HKCategorySample *sample = [[HKCategorySample alloc] charon_initWithType:(HKSampleType *)type
                                                                   metadata:metadata
                                                                  startDate:startDate
                                                                    endDate:endDate];
    if (sample)
        sample->_value = value;
    return sample;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        _value = [coder decodeIntegerForKey:@"value"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:_value forKey:@"value"];
}

- (instancetype)charon_copyForStore
{
    HKCategorySample *copy = [super charon_copyForStore];
    if (copy)
        copy->_value = _value;
    return copy;
}

- (NSInteger)value
{
    return _value;
}

- (NSInteger)charon_storeKind
{
    return 0;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKCategorySample %ld of %@ from %@ to %@", (long)_value,
                                      self.sampleType.identifier, self.startDate, self.endDate];
}

@end

#pragma mark - HKQuantitySample

@implementation HKQuantitySample {
    HKQuantity *_quantity;
}
@dynamic count;


+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)quantitySampleWithType:(HKQuantityType *)type
                                      quantity:(HKQuantity *)quantity
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
{
    return [self quantitySampleWithType:type quantity:quantity startDate:startDate endDate:endDate metadata:nil];
}

+ (instancetype)quantitySampleWithType:(HKQuantityType *)type
                                      quantity:(HKQuantity *)quantity
                                     startDate:(NSDate *)startDate
                                       endDate:(NSDate *)endDate
                                      metadata:(nullable NSDictionary *)metadata
{
    if (![type isKindOfClass:[HKQuantityType class]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a quantity type; a quantity sample is made with one of +[HKObjectType quantityTypeForIdentifier:].",
                           type];
        return nil;
    }
    if (![quantity isKindOfClass:[HKQuantity class]]) {
        [NSException raise:NSInvalidArgumentException format:@"%@ is not a quantity.", quantity];
        return nil;
    }
    if (![type isCompatibleWithUnit:[quantity charon_unit]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"A quantity in %@ cannot be saved as a sample of %@, which is counted in a different dimension.",
                           [quantity charon_unit].unitString, type.identifier];
        return nil;
    }
    HKQuantitySample *sample = [[HKQuantitySample alloc] charon_initWithType:(HKSampleType *)type
                                                                   metadata:metadata
                                                                  startDate:startDate
                                                                    endDate:endDate];
    if (sample)
        sample->_quantity = (HKQuantity *)[quantity copy];
    return sample;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
        _quantity = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"quantity"] copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_quantity forKey:@"quantity"];
}

- (instancetype)charon_copyForStore
{
    HKQuantitySample *copy = [super charon_copyForStore];
    if (copy)
        copy->_quantity = [_quantity copy];
    return copy;
}

- (HKQuantity *)quantity
{
    return _quantity;
}

- (HKQuantityType *)quantityType
{
    return (HKQuantityType *)self.sampleType;
}

- (NSInteger)charon_storeKind
{
    return 1;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKQuantitySample %@ of %@ from %@ to %@", _quantity,
                                      self.sampleType.identifier, self.startDate, self.endDate];
}

@end

#pragma mark - HKCorrelation

@implementation HKCorrelation {
    HKCorrelationType *_correlationType;
    NSMutableDictionary<NSString *, NSMutableArray<HKObject *> *> *_byType;
}


+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)correlationWithType:(HKCorrelationType *)type
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                     objects:(NSSet<HKSample *> *)objects
{
    return [self correlationWithType:type startDate:startDate endDate:endDate objects:objects metadata:nil];
}

+ (instancetype)correlationWithType:(HKCorrelationType *)type
                                   startDate:(NSDate *)startDate
                                     endDate:(NSDate *)endDate
                                     objects:(NSSet<HKSample *> *)objects
                                    metadata:(nullable NSDictionary *)metadata
{
    if (![type isKindOfClass:[HKCorrelationType class]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ is not a correlation type; a correlation is made with one of +[HKObjectType correlationTypeForIdentifier:].",
                           type];
        return nil;
    }
    HKCorrelation *correlation = [[HKCorrelation alloc] charon_initWithType:(HKSampleType *)type
                                                                  metadata:metadata
                                                                 startDate:startDate
                                                                   endDate:endDate];
    if (!correlation)
        return nil;
    correlation->_correlationType = type;
    correlation->_byType = [NSMutableDictionary dictionary];
    for (HKSample *object in objects) {
        if (![object conformsToProtocol:@protocol(CharonHKStorable)])
            continue;
        NSString *identifier = [(id<CharonHKStorable>)object charon_storeTypeIdentifier];
        if (!identifier.length)
            continue;
        if (![correlation->_byType[identifier] containsObject:object])
            [correlation->_byType[identifier] addObject:object];
    }
    return correlation;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _correlationType = [[coder decodeObjectOfClass:[HKCorrelationType class] forKey:@"correlationType"] copy];
        _byType = [NSMutableDictionary dictionary];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSArray class], [HKObject class], nil];
        NSDictionary *stored = [coder decodeObjectOfClasses:classes forKey:@"objects"];
        for (NSString *identifier in stored)
            _byType[identifier] = [stored[identifier] mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_correlationType forKey:@"correlationType"];
    [coder encodeObject:_byType forKey:@"objects"];
}

- (instancetype)charon_copyForStore
{
    HKCorrelation *copy = [super charon_copyForStore];
    if (copy) {
        copy->_correlationType = [_correlationType copy];
        copy->_byType = [_byType mutableCopy];
    }
    return copy;
}

- (HKCorrelationType *)correlationType
{
    return _correlationType;
}

- (NSSet<HKObject *> *)objectsForType:(HKObjectType *)type
{
    return [NSSet setWithArray:_byType[type.identifier] ?: @[]];
}

- (NSSet<HKObject *> *)objects
{
    return [self charon_allObjectsSet];
}

- (NSArray<HKObject *> *)charon_allObjects
{
    NSMutableArray *all = [NSMutableArray array];
    for (NSArray *group in _byType.allValues)
        [all addObjectsFromArray:group];
    return all;
}

- (NSSet<HKObject *> *)charon_allObjectsSet
{
    return [NSSet setWithArray:[self charon_allObjects]];
}

- (NSInteger)charon_storeKind
{
    return 2;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKCorrelation %@ of %@ from %@ to %@", _correlationType.identifier,
                                      self.startDate, self.endDate];
}

@end

@interface HKCategorySample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCategorySample (CharonHKStorable)
@end

@interface HKQuantitySample (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKQuantitySample (CharonHKStorable)
@end

@interface HKCorrelation (CharonHKStorable) <CharonHKStorable>
@end

@implementation HKCorrelation (CharonHKStorable)
@end
