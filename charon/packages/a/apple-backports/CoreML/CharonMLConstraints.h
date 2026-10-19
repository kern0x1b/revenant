#ifndef CHARON_ML_CONSTRAINTS_H
#define CHARON_ML_CONSTRAINTS_H

#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"
#include "CharonMLModel.h"


static inline MLMultiArrayShapeConstraint *charon_ml_shape_constraint_of(const charon_ml_feature *feature)
{
    if (feature->shape_kind == CHARON_ML_SHAPE_RANGE) {
        NSMutableArray<NSValue *> *ranges = [NSMutableArray arrayWithCapacity:CHARON_ML_MAX_RANK];
        int axis;
        for (axis = 0; axis < feature->rank; axis++) {
            int64_t least = feature->shape_range[axis][0];
            int64_t most = feature->shape_range[axis][1];
            NSUInteger length = most < 0 ? 0 : (NSUInteger)(most - least);
            [ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)least, length)]];
        }
        return [[MLMultiArrayShapeConstraint alloc] charon_initWithType:MLMultiArrayShapeConstraintTypeRange
                                                          sizeRanges:ranges
                                                   enumeratedShapes:@[]];
    }
    {
        NSMutableArray<NSArray<NSNumber *> *> *shapes = [NSMutableArray arrayWithCapacity:1];
        NSMutableArray<NSValue *> *ranges = [NSMutableArray arrayWithCapacity:CHARON_ML_MAX_RANK];
        int64_t least[CHARON_ML_MAX_RANK], most[CHARON_ML_MAX_RANK];
        int rank = feature->rank, axis;
        size_t index;
        if (feature->enumerated_count > 0 && feature->enumerated_shapes != NULL) {
            for (index = 0; index < feature->enumerated_count; index++) {
                [shapes addObject:charon_ml_shape_to_array(feature->enumerated_shapes[index],
                                                           feature->enumerated_ranks[index])];
            }
            rank = feature->enumerated_ranks[0];
        } else if (feature->rank > 0) {
            [shapes addObject:charon_ml_shape_to_array(feature->shape, feature->rank)];
        }
        for (axis = 0; axis < rank; axis++) {
            least[axis] = 0;
            most[axis] = -1;
        }
        for (index = 0; index < shapes.count; index++) {
            for (axis = 0; axis < rank && axis < (int)shapes[index].count; axis++) {
                int64_t length = [shapes[index][axis] longLongValue];
                if (length < 0) {
                    continue;
                }
                if (index == 0) {
                    least[axis] = most[axis] = length;
                } else {
                    least[axis] = length < least[axis] ? length : least[axis];
                    most[axis] = length > most[axis] ? length : most[axis];
                }
            }
        }
        for (axis = 0; axis < rank; axis++) {
            NSUInteger length = most[axis] < 0 ? 0 : (NSUInteger)(most[axis] - least[axis] + 1);
            [ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)least[axis], length)]];
        }
        return [[MLMultiArrayShapeConstraint alloc] charon_initWithType:MLMultiArrayShapeConstraintTypeEnumerated
                                                          sizeRanges:ranges
                                                   enumeratedShapes:shapes];
    }
}

static inline MLImageSizeConstraint *charon_ml_image_size_constraint_of(const charon_ml_feature *feature)
{
    if (feature->enumerated_count > 0 && feature->enumerated_widths != NULL) {
        NSMutableArray<MLImageSize *> *sizes = [NSMutableArray arrayWithCapacity:feature->enumerated_count];
        size_t index;
        for (index = 0; index < feature->enumerated_count; index++) {
            [sizes addObject:[[MLImageSize alloc] charon_initWithPixelsWide:feature->enumerated_widths[index]
                                                           pixelsHigh:feature->enumerated_heights[index]]];
        }
        return [[MLImageSizeConstraint alloc] charon_initWithType:MLImageSizeConstraintTypeEnumerated
                                             pixelsWideRange:NSMakeRange(0, 0)
                                            pixelsHighRange:NSMakeRange(0, 0)
                                       enumeratedImageSizes:sizes];
    }
    if (feature->image_width > 0 && feature->image_height > 0 && feature->image_width_range == 0 &&
        feature->image_height_range == 0) {
        MLImageSize *only = [[MLImageSize alloc] charon_initWithPixelsWide:feature->image_width
                                                              pixelsHigh:feature->image_height];
        return [[MLImageSizeConstraint alloc] charon_initWithType:MLImageSizeConstraintTypeEnumerated
                                             pixelsWideRange:NSMakeRange((NSUInteger)feature->image_width, 1)
                                            pixelsHighRange:NSMakeRange((NSUInteger)feature->image_height, 1)
                                       enumeratedImageSizes:@[only]];
    }
    if (feature->image_width_range != 0 || feature->image_height_range != 0 ||
        feature->image_width <= 0 || feature->image_height <= 0) {
        NSUInteger wide = feature->image_width_range > 0
                              ? (NSUInteger)(feature->image_width - feature->image_width_range)
                              : 0;
        NSUInteger high = feature->image_height_range > 0
                              ? (NSUInteger)(feature->image_height - feature->image_height_range)
                              : 0;
        return [[MLImageSizeConstraint alloc]
            charon_initWithType:MLImageSizeConstraintTypeRange
            pixelsWideRange:NSMakeRange((NSUInteger)feature->image_width_range, wide)
           pixelsHighRange:NSMakeRange((NSUInteger)feature->image_height_range, high)
        enumeratedImageSizes:@[]];
    }
    return [[MLImageSizeConstraint alloc] charon_initWithType:MLImageSizeConstraintTypeUnspecified
                                        pixelsWideRange:NSMakeRange(0, 0)
                                       pixelsHighRange:NSMakeRange(0, 0)
                                  enumeratedImageSizes:@[]];
}

static inline MLImageConstraint *charon_ml_image_constraint_of(const charon_ml_feature *feature)
{
    return [[MLImageConstraint alloc] charon_initWithPixelsHigh:feature->image_height
                                              pixelsWide:feature->image_width
                                        pixelFormatType:charon_ml_pixel_format_of(feature->image_color_space)
                                          sizeConstraint:charon_ml_image_size_constraint_of(feature)];
}

static inline BOOL charon_ml_shape_allowed(MLMultiArrayShapeConstraint *constraint, NSArray<NSNumber *> *shape)
{
    NSUInteger index;
    if (constraint == nil) {
        return YES;
    }
    switch (constraint.type) {
    case MLMultiArrayShapeConstraintTypeEnumerated:
        for (index = 0; index < constraint.enumeratedShapes.count; index++) {
            if ([constraint.enumeratedShapes[index] isEqualToArray:shape]) {
                return YES;
            }
        }
        return NO;
    case MLMultiArrayShapeConstraintTypeRange:
        for (index = 0; index < shape.count && index < constraint.sizeRangeForDimension.count; index++) {
            NSRange allowed = [constraint.sizeRangeForDimension[index] rangeValue];
            NSInteger length = [shape[index] integerValue];
            if (length < (NSInteger)allowed.location ||
                (allowed.length != 0 && (NSUInteger)length > allowed.location + allowed.length)) {
                return NO;
            }
        }
        return YES;
    default:
        return YES;
    }
}

static inline BOOL charon_ml_image_size_allowed(MLImageSizeConstraint *constraint, NSInteger fixedHigh,
                                         NSInteger fixedWide, CVPixelBufferRef buffer)
{
    NSInteger high, wide;
    NSUInteger index;
    if (buffer == NULL) {
        return NO;
    }
    high = (NSInteger)CVPixelBufferGetHeight(buffer);
    wide = (NSInteger)CVPixelBufferGetWidth(buffer);
    switch (constraint.type) {
    case MLImageSizeConstraintTypeEnumerated:
        for (index = 0; index < constraint.enumeratedImageSizes.count; index++) {
            MLImageSize *size = constraint.enumeratedImageSizes[index];
            if (size.pixelsHigh == high && size.pixelsWide == wide) {
                return YES;
            }
        }
        return NO;
    case MLImageSizeConstraintTypeRange: {
        NSRange wideRange = constraint.pixelsWideRange;
        NSRange highRange = constraint.pixelsHighRange;
        if (wide < (NSInteger)wideRange.location ||
            (wideRange.length != 0 && (NSUInteger)wide > wideRange.location + wideRange.length)) {
            return NO;
        }
        if (high < (NSInteger)highRange.location ||
            (highRange.length != 0 && (NSUInteger)high > highRange.location + highRange.length)) {
            return NO;
        }
        return YES;
    }
    default:
        if (fixedHigh > 0 && fixedHigh != high) {
            return NO;
        }
        if (fixedWide > 0 && fixedWide != wide) {
            return NO;
        }
        return YES;
    }
}

static inline const char *charon_ml_feature_type_name_of(MLFeatureType type)
{
    switch (type) {
    case MLFeatureTypeInt64: return "int64";
    case MLFeatureTypeDouble: return "double";
    case MLFeatureTypeString: return "string";
    case MLFeatureTypeImage: return "image";
    case MLFeatureTypeMultiArray: return "multiArray";
    case MLFeatureTypeDictionary: return "dictionary";
    case MLFeatureTypeSequence: return "sequence";
    default: return "invalid";
    }
}

#endif
