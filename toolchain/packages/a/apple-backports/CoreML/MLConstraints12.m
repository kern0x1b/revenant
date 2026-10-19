#import <CoreML/CoreML.h>

#include "RevenantMLConstraints.h"

@interface MLMultiArrayShapeConstraint () {
    MLMultiArrayShapeConstraintType _type;
    NSArray<NSValue *> *_sizeRangeForDimension;
    NSArray<NSArray<NSNumber *> *> *_enumeratedShapes;
}
- (instancetype)revenant_initWithType:(MLMultiArrayShapeConstraintType)type
                  sizeRanges:(NSArray<NSValue *> *)sizeRanges
           enumeratedShapes:(NSArray<NSArray<NSNumber *> *> *)enumeratedShapes;
@end

@interface MLImageSize () {
    NSInteger _pixelsWide;
    NSInteger _pixelsHigh;
}
- (instancetype)revenant_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh;
@end

@interface MLImageSizeConstraint () {
    MLImageSizeConstraintType _type;
    NSRange _pixelsWideRange;
    NSRange _pixelsHighRange;
    NSArray<MLImageSize *> *_enumeratedImageSizes;
}
- (instancetype)revenant_initWithType:(MLImageSizeConstraintType)type
              pixelsWideRange:(NSRange)pixelsWideRange
             pixelsHighRange:(NSRange)pixelsHighRange
        enumeratedImageSizes:(NSArray<MLImageSize *> *)enumeratedImageSizes;
@end

@interface MLSequenceConstraint () {
    MLFeatureDescription *_valueDescription;
    NSRange _countRange;
}
- (instancetype)revenant_initWithValueDescription:(MLFeatureDescription *)valueDescription
                              countRange:(NSRange)countRange;
@end


@implementation MLMultiArrayShapeConstraint

- (instancetype)revenant_initWithType:(MLMultiArrayShapeConstraintType)type
                  sizeRanges:(NSArray<NSValue *> *)sizeRanges
           enumeratedShapes:(NSArray<NSArray<NSNumber *> *> *)enumeratedShapes
{
    MLMultiArrayShapeConstraint *built = [super init];
    if (built != nil) {
        _type = type;
        _sizeRangeForDimension = sizeRanges != nil ? [sizeRanges copy] : @[];
        _enumeratedShapes = enumeratedShapes != nil ? [enumeratedShapes copy] : @[];
    }
    return built;
}

- (MLMultiArrayShapeConstraintType)type
{
    return _type;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithType:_type
                                                      sizeRanges:_sizeRangeForDimension
                                               enumeratedShapes:_enumeratedShapes];
}


- (NSArray<NSValue *> *)sizeRangeForDimension
{
    return _sizeRangeForDimension;
}

- (NSArray<NSArray<NSNumber *> *> *)enumeratedShapes
{
    return _enumeratedShapes;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _type = (MLMultiArrayShapeConstraintType)[coder decodeIntegerForKey:@"type"];
        _sizeRangeForDimension = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSValue class], nil]
                                                      forKey:@"sizeRangeForDimension"];
        _enumeratedShapes = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSArray class], [NSNumber class], nil]
                                                forKey:@"enumeratedShapes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
    [coder encodeObject:_sizeRangeForDimension forKey:@"sizeRangeForDimension"];
    [coder encodeObject:_enumeratedShapes forKey:@"enumeratedShapes"];
}

@end

@implementation MLImageSize

- (instancetype)revenant_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh
{
    MLImageSize *built = [super init];
    if (built != nil) {
        _pixelsWide = pixelsWide;
        _pixelsHigh = pixelsHigh;
    }
    return built;
}

- (NSInteger)pixelsWide
{
    return _pixelsWide;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithPixelsWide:_pixelsWide pixelsHigh:_pixelsHigh];
}


- (NSInteger)pixelsHigh
{
    return _pixelsHigh;
}

- (BOOL)isEqual:(id)object
{
    MLImageSize *other = [object isKindOfClass:[MLImageSize class]] ? object : nil;
    if (other == nil) {
        return NO;
    }
    return other->_pixelsWide == _pixelsWide && other->_pixelsHigh == _pixelsHigh;
}

- (NSUInteger)hash
{
    return (NSUInteger)(_pixelsWide * 31 + _pixelsHigh);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLImageSize %ld x %ld>", (long)_pixelsWide, (long)_pixelsHigh];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _pixelsWide = [coder decodeIntegerForKey:@"pixelsWide"];
        _pixelsHigh = [coder decodeIntegerForKey:@"pixelsHigh"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_pixelsWide forKey:@"pixelsWide"];
    [coder encodeInteger:_pixelsHigh forKey:@"pixelsHigh"];
}

@end

@implementation MLImageSizeConstraint

- (instancetype)revenant_initWithType:(MLImageSizeConstraintType)type
              pixelsWideRange:(NSRange)pixelsWideRange
             pixelsHighRange:(NSRange)pixelsHighRange
        enumeratedImageSizes:(NSArray<MLImageSize *> *)enumeratedImageSizes
{
    MLImageSizeConstraint *built = [super init];
    if (built != nil) {
        _type = type;
        _pixelsWideRange = pixelsWideRange;
        _pixelsHighRange = pixelsHighRange;
        _enumeratedImageSizes = enumeratedImageSizes != nil ? [enumeratedImageSizes copy] : @[];
    }
    return built;
}

- (MLImageSizeConstraintType)type
{
    return _type;
}

- (NSRange)pixelsWideRange
{
    return _pixelsWideRange;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithType:_type
                                              pixelsWideRange:_pixelsWideRange
                                             pixelsHighRange:_pixelsHighRange
                                        enumeratedImageSizes:_enumeratedImageSizes];
}


- (NSRange)pixelsHighRange
{
    return _pixelsHighRange;
}

- (NSArray<MLImageSize *> *)enumeratedImageSizes
{
    return _enumeratedImageSizes;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _type = (MLImageSizeConstraintType)[coder decodeIntegerForKey:@"type"];
        _pixelsWideRange = [[coder decodeObjectOfClass:[NSValue class] forKey:@"pixelsWideRange"] rangeValue];
        _pixelsHighRange = [[coder decodeObjectOfClass:[NSValue class] forKey:@"pixelsHighRange"] rangeValue];
        _enumeratedImageSizes = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [MLImageSize class], nil]
                                                forKey:@"enumeratedImageSizes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
    [coder encodeObject:[NSValue valueWithRange:_pixelsWideRange] forKey:@"pixelsWideRange"];
    [coder encodeObject:[NSValue valueWithRange:_pixelsHighRange] forKey:@"pixelsHighRange"];
    [coder encodeObject:_enumeratedImageSizes forKey:@"enumeratedImageSizes"];
}

@end

@implementation MLSequenceConstraint

- (instancetype)revenant_initWithValueDescription:(MLFeatureDescription *)valueDescription
                              countRange:(NSRange)countRange
{
    MLSequenceConstraint *built = [super init];
    if (built != nil) {
        _valueDescription = valueDescription;
        _countRange = countRange;
    }
    return built;
}

- (MLFeatureDescription *)valueDescription
{
    return _valueDescription;
}

- (NSRange)countRange
{
    return _countRange;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithValueDescription:[_valueDescription copy]
                              countRange:_countRange];
}


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _valueDescription = [coder decodeObjectOfClass:[MLFeatureDescription class]
                                            forKey:@"valueDescription"];
        _countRange = [[coder decodeObjectOfClass:[NSValue class] forKey:@"countRange"] rangeValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_valueDescription forKey:@"valueDescription"];
    [coder encodeObject:[NSValue valueWithRange:_countRange] forKey:@"countRange"];
}

@end
