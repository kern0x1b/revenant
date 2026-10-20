#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@implementation HKBiologicalSexObject {
    HKBiologicalSex _biologicalSex;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)revenant_biologicalSexObject:(HKBiologicalSex)biologicalSex
{
    HKBiologicalSexObject *object = [[HKBiologicalSexObject alloc] revenant_initWithBiologicalSex:biologicalSex];
    return object;
}

- (instancetype)revenant_initWithBiologicalSex:(HKBiologicalSex)biologicalSex
{
    HKBiologicalSexObject *fresh = [super init];
    if (fresh)
        fresh->_biologicalSex = biologicalSex;
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _biologicalSex = (HKBiologicalSex)[coder decodeIntegerForKey:@"biologicalSex"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_biologicalSex forKey:@"biologicalSex"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKBiologicalSexObject revenant_biologicalSexObject:_biologicalSex];
}

- (HKBiologicalSex)biologicalSex
{
    return _biologicalSex;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKBiologicalSexObject %ld", (long)_biologicalSex];
}

@end

#pragma mark - HKBloodTypeObject

@implementation HKBloodTypeObject {
    HKBloodType _bloodType;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)revenant_bloodTypeObject:(HKBloodType)bloodType
{
    HKBloodTypeObject *object = [[HKBloodTypeObject alloc] revenant_initWithBloodType:bloodType];
    return object;
}

- (instancetype)revenant_initWithBloodType:(HKBloodType)bloodType
{
    HKBloodTypeObject *fresh = [super init];
    if (fresh)
        fresh->_bloodType = bloodType;
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _bloodType = (HKBloodType)[coder decodeIntegerForKey:@"bloodType"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_bloodType forKey:@"bloodType"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKBloodTypeObject revenant_bloodTypeObject:_bloodType];
}

- (HKBloodType)bloodType
{
    return _bloodType;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKBloodTypeObject %ld", (long)_bloodType];
}

@end
