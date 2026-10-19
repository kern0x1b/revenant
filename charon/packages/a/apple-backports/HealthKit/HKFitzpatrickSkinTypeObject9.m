// HKFitzpatrickSkinTypeObject: the user's Fitzpatrick skin type. It arrived in iOS 9.0, so it is a
// file of its own.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKFitzpatrickSkinTypeObject {
    HKFitzpatrickSkinType _skinType;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)charon_fitzpatrickSkinTypeObject:(HKFitzpatrickSkinType)skinType
{
    HKFitzpatrickSkinTypeObject *object = [[HKFitzpatrickSkinTypeObject alloc] charon_initWithSkinType:skinType];
    return object;
}

- (instancetype)charon_initWithSkinType:(HKFitzpatrickSkinType)skinType
{
    HKFitzpatrickSkinTypeObject *fresh = [super init];
    if (fresh)
        fresh->_skinType = skinType;
    return fresh;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKFitzpatrickSkinTypeObject *fresh = [super init];
    if (fresh)
        fresh->_skinType = (HKFitzpatrickSkinType)[coder decodeIntegerForKey:@"skinType"];
    return fresh;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_skinType forKey:@"skinType"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [HKFitzpatrickSkinTypeObject charon_fitzpatrickSkinTypeObject:_skinType];
}

- (HKFitzpatrickSkinType)skinType
{
    return _skinType;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKFitzpatrickSkinTypeObject %ld", (long)_skinType];
}

@end
