/* The constraints Core ML added in iOS 12, in a file of their own because an object may only carry
 * the API of a single release: the multi array shape constraint (which one shape, which range of
 * shapes, or which set of them), the image size and the sizes an image feature will take, and the
 * sequence constraint (what one element is, and how many of them). Each is built from the same
 * fields of the specification's own message as the iOS 11 constraints beside them, and the reading
 * they share is in CharonMLConstraints.h.
 */
#import <CoreML/CoreML.h>

#include "CharonMLConstraints.h"

@interface MLMultiArrayShapeConstraint () {
    MLMultiArrayShapeConstraintType _type;
    NSArray<NSValue *> *_sizeRangeForDimension;
    NSArray<NSArray<NSNumber *> *> *_enumeratedShapes;
}
- (instancetype)charon_initWithType:(MLMultiArrayShapeConstraintType)type
                  sizeRanges:(NSArray<NSValue *> *)sizeRanges
           enumeratedShapes:(NSArray<NSArray<NSNumber *> *> *)enumeratedShapes;
@end

@interface MLImageSize () {
    NSInteger _pixelsWide;
    NSInteger _pixelsHigh;
}
- (instancetype)charon_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh;
@end

@interface MLImageSizeConstraint () {
    MLImageSizeConstraintType _type;
    NSRange _pixelsWideRange;
    NSRange _pixelsHighRange;
    NSArray<MLImageSize *> *_enumeratedImageSizes;
}
- (instancetype)charon_initWithType:(MLImageSizeConstraintType)type
              pixelsWideRange:(NSRange)pixelsWideRange
             pixelsHighRange:(NSRange)pixelsHighRange
        enumeratedImageSizes:(NSArray<MLImageSize *> *)enumeratedImageSizes;
@end

@interface MLSequenceConstraint () {
    MLFeatureDescription *_valueDescription;
    NSRange _countRange;
}
- (instancetype)charon_initWithValueDescription:(MLFeatureDescription *)valueDescription
                              countRange:(NSRange)countRange;
@end


@implementation MLMultiArrayShapeConstraint

- (instancetype)charon_initWithType:(MLMultiArrayShapeConstraintType)type
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
/* A copy is a constraint of the same kind with the same numbers, and a real copy rather than the
 * same object: a caller that holds a description and copies it must be able to read the copy
 * without the two sharing anything. */
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] charon_initWithType:_type
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

/* One image size, in the two numbers an image is measured in. */
@implementation MLImageSize

- (instancetype)charon_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh
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
    return [[[self class] allocWithZone:zone] charon_initWithPixelsWide:_pixelsWide pixelsHigh:_pixelsHigh];
}


- (NSInteger)pixelsHigh
{
    return _pixelsHigh;
}

/* Two sizes are the same size when they are the same two numbers: there is nothing else an
 * image size carries, and a caller putting sizes in a set is asking exactly that. */
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

/* The sizes an image feature takes: any, a set of them, or a range for each of the two numbers.
 * A range of length zero is the specification's "no upper bound", which is a range that does not
 * stop -- and a range of *location* zero with no length is a range that does not start either,
 * which is the same thing as no range at all. */
@implementation MLImageSizeConstraint

- (instancetype)charon_initWithType:(MLImageSizeConstraintType)type
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
    return [[[self class] allocWithZone:zone] charon_initWithType:_type
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

/* A sequence feature: what one element of it is, which is a description of its own, and how many
 * elements it may have. The count range's length of zero is the specification's "no upper
 * bound", so a sequence with a lower bound of two and no upper one answers a range starting at
 * two with no length -- and a sequence with neither answers a range of zero, which is any count. */
@implementation MLSequenceConstraint

- (instancetype)charon_initWithValueDescription:(MLFeatureDescription *)valueDescription
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
    return [[[self class] allocWithZone:zone] charon_initWithValueDescription:[_valueDescription copy]
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
