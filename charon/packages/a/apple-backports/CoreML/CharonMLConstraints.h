/* Reading the specification's own constraint fields, for the classes that answer with them.
 *
 * Three files of this package build constraints -- the ones iOS 11 declared, the ones iOS 12 added,
 * and the numeric one -- because an object may only carry the API of a single release, and the
 * reading of a feature's fields is the same for all three. A header of static inline functions, for
 * the reason CharonMLBridge.h gives: a .c file of this package is compiled as C and cannot import
 * Core ML, and a .m file is not compiled with hidden visibility and would put every one of these in
 * the library's exports, where the registry would owe an entry for it.
 */
#ifndef CHARON_ML_CONSTRAINTS_H
#define CHARON_ML_CONSTRAINTS_H

#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"
#include "CharonMLModel.h"


/* The specification writes a feature's shape or size in one of three ways, and which one it
 * wrote is what decides what a caller is told: one shape, a range per dimension, or a set of the
 * shapes it will take. A set and a range are in the same oneof, so a document that names both
 * names both and the set is the one that decides -- it is the one a caller has to be able to
 * name a shape from, and a range that merely covers the set would tell the caller the shape is
 * allowed without saying which of the allowed ones it is. */
/* The shape constraint of a feature, which is never nil. Measured against a real Core ML: a model
 * that fixes its shape is not a feature with no constraint, it is a feature whose constraint is of
 * the *enumerated* kind with that one shape in it -- and whose size ranges are filled in as well,
 * one per dimension, each of length one. So all three of the constraint's own properties are
 * answered for every multi array feature, and which of the two kinds it is decides what a value of
 * a shape that is not the one has to be. */
/* The shape constraint of a feature, which is never nil. Measured against a real Core ML: a model
 * that fixes its shape is not a feature with no constraint, it is a feature whose constraint is of
 * the *enumerated* kind with that one shape in it -- and whose size ranges are filled in as well,
 * one per dimension, each of length one. So all three of the constraint's own properties are
 * answered for every multi array feature, and which of the two kinds it is decides what a value of
 * a shape that is not one of them has to be. */
static inline MLMultiArrayShapeConstraint *charon_ml_shape_constraint_of(const charon_ml_feature *feature)
{
    if (feature->shape_kind == CHARON_ML_SHAPE_RANGE) {
        NSMutableArray<NSValue *> *ranges = [NSMutableArray arrayWithCapacity:CHARON_ML_MAX_RANK];
        int axis;
        for (axis = 0; axis < feature->rank; axis++) {
            int64_t least = feature->shape_range[axis][0];
            int64_t most = feature->shape_range[axis][1];
            /* The specification's flexible dimension -- an upper bound of -1 -- is a dimension of
             * no fixed length, so it has no range to answer: NSRange's own flexible length is 0,
             * which is also what a dimension with no range at all gives, and both mean any length.
             * The lower bound is kept either way, because a dimension of at least three and of no
             * fixed length is a real bound. */
            NSUInteger length = most < 0 ? 0 : (NSUInteger)(most - least);
            [ranges addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)least, length)]];
        }
        return [[MLMultiArrayShapeConstraint alloc] charon_initWithType:MLMultiArrayShapeConstraintTypeRange
                                                          sizeRanges:ranges
                                                   enumeratedShapes:@[]];
    }
    /* Either the model named a set of shapes or it fixed one, and both are the enumerated kind: a
     * set is a set, and a single shape is a set of one. The size ranges are the range the set
     * covers, dimension by dimension -- one shape is a range of one -- and a dimension of no fixed
     * length inside a shape leaves that dimension's range at nothing, as it does everywhere else. */
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
                    continue;   /* a dimension of no fixed length bounds nothing */
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

/* An image's size, in the two numbers it is measured in. A range of length zero is the
 * specification's "no upper bound", and it is left as zero: a dimension whose upper bound is
 * flexible has no upper bound to report, and the type says which of the two kinds of
 * constraint this is. */
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
        /* A FIXED size. Core ML reports this as the ENUMERATED kind carrying the one size it
         * allows, with each dimension's range of length one -- measured against this host's own
         * Core ML over tools/coreml's vision_image container (fixed 32 by 32 on both ends):
         * `sizeConstraint` 2, `pixelsWideRange` 32+1, `pixelsHighRange` 32+1,
         * `enumeratedImageSizes` 32x32. There is no Exact case in the enumeration the SDKs on this
         * machine carry (0 unspecified, 2 enumerated, 3 range), so the enumerated kind with a single
         * member is how a fixed size is spelled. */
        MLImageSize *only = [[MLImageSize alloc] charon_initWithPixelsWide:feature->image_width
                                                              pixelsHigh:feature->image_height];
        return [[MLImageSizeConstraint alloc] charon_initWithType:MLImageSizeConstraintTypeEnumerated
                                             pixelsWideRange:NSMakeRange((NSUInteger)feature->image_width, 1)
                                            pixelsHighRange:NSMakeRange((NSUInteger)feature->image_height, 1)
                                       enumeratedImageSizes:@[only]];
    }
    if (feature->image_width_range != 0 || feature->image_height_range != 0 ||
        feature->image_width <= 0 || feature->image_height <= 0) {
        /* A range of either number is a range of both, and an upper bound of -1 is the
         * specification's flexible one: no upper bound, so a length of zero. */
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

/* Whether a shape is one the constraint allows. The three cases are the three the constraint's own
 * type names, and the type decides rather than what the arrays happen to hold: a constraint of the
 * enumerated kind with nothing in it allows nothing, which is not the same answer as no constraint
 * at all and is what a caller comparing two constraints has to be able to see. */
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

/* Whether an image is one the constraint allows: the size it fixes, a size inside the range it
 * allows, or one of the sizes it enumerates. An image feature this port was handed as a pixel
 * buffer knows its own size, and one that is not a buffer at all -- an undefined value, which
 * the type check has already let through only for an optional feature -- has no size to judge. */
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
        /* No range and no set: the feature fixes the size, and a feature that fixes none takes
         * any, which is the same answer the fixed numbers give when they are zero. */
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

#endif /* CHARON_ML_CONSTRAINTS_H */
