// The two characteristic objects of iOS 8: what biological sex and what blood type the user has.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKBiologicalSexObject {
    HKBiologicalSex _biologicalSex;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_biologicalSexObject:(HKBiologicalSex)biologicalSex
{
    HKBiologicalSexObject *object = [[HKBiologicalSexObject alloc] charon_initWithBiologicalSex:biologicalSex];
    return object;
}

- (instancetype)charon_initWithBiologicalSex:(HKBiologicalSex)biologicalSex
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
    return [HKBiologicalSexObject charon_biologicalSexObject:_biologicalSex];
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

+ (instancetype)charon_bloodTypeObject:(HKBloodType)bloodType
{
    HKBloodTypeObject *object = [[HKBloodTypeObject alloc] charon_initWithBloodType:bloodType];
    return object;
}

- (instancetype)charon_initWithBloodType:(HKBloodType)bloodType
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
    return [HKBloodTypeObject charon_bloodTypeObject:_bloodType];
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
