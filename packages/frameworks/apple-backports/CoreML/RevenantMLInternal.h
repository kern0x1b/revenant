#ifndef REVENANT_ML_INTERNAL_H
#define REVENANT_ML_INTERNAL_H

#import <CoreML/CoreML.h>

#include "RevenantMLModel.h"

@interface MLFeatureValue (RevenantInvalid)
+ (instancetype)revenant_featureValueOfInvalidType;
@end

@interface MLFeatureDescription (RevenantRead)
- (instancetype)revenant_initWithFeature:(const revenant_ml_feature *)feature;
- (instancetype)revenant_initWithName:(NSString *)name type:(MLFeatureType)type optional:(BOOL)optional;
@end

@interface MLMultiArrayShapeConstraint (RevenantRead)
- (instancetype)revenant_initWithType:(MLMultiArrayShapeConstraintType)type
                  sizeRanges:(NSArray<NSValue *> *)sizeRanges
           enumeratedShapes:(NSArray<NSArray<NSNumber *> *> *)enumeratedShapes;
@end

@interface MLMultiArrayConstraint (RevenantRead)
- (instancetype)revenant_initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
               shapeConstraint:(MLMultiArrayShapeConstraint *)shapeConstraint;
@end

@interface MLImageSize (RevenantRead)
- (instancetype)revenant_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh;
@end

@interface MLImageSizeConstraint (RevenantRead)
- (instancetype)revenant_initWithType:(MLImageSizeConstraintType)type
              pixelsWideRange:(NSRange)pixelsWideRange
             pixelsHighRange:(NSRange)pixelsHighRange
        enumeratedImageSizes:(NSArray<MLImageSize *> *)enumeratedImageSizes;
@end

@interface MLImageConstraint (RevenantRead)
- (instancetype)revenant_initWithPixelsHigh:(NSInteger)pixelsHigh
                        pixelsWide:(NSInteger)pixelsWide
                  pixelFormatType:(OSType)pixelFormatType
                    sizeConstraint:(MLImageSizeConstraint *)sizeConstraint;
@end

@interface MLDictionaryConstraint (RevenantRead)
- (instancetype)revenant_initWithKeyType:(MLFeatureType)keyType;
@end

@interface MLSequenceConstraint (RevenantRead)
- (instancetype)revenant_initWithValueDescription:(MLFeatureDescription *)valueDescription
                              countRange:(NSRange)countRange;
@end

@interface MLNumericConstraint (RevenantRead)
- (instancetype)revenant_initWithMinNumber:(NSNumber *)minNumber
                         maxNumber:(NSNumber *)maxNumber
                enumeratedNumbers:(NSSet<NSNumber *> *)enumeratedNumbers;
@end

@interface MLModelDescription (RevenantRead)
- (instancetype)revenant_initWithModel:(const revenant_ml_model *)model;
- (instancetype)revenant_initWithFunction:(const revenant_ml_function *)function;
@end

@interface MLModelAsset (RevenantRead)
- (NSData *)revenant_specificationData;
- (NSArray<NSString *> *)revenant_functionNamesWithError:(NSError **)error;
- (MLModelDescription *)revenant_descriptionOfFunctionNamed:(NSString *)functionName error:(NSError **)error;
@end

@interface MLModel (RevenantRead)
- (instancetype)revenant_initWithContentsOfAsset:(MLModelAsset *)asset
                           configuration:(MLModelConfiguration *)configuration
                                   error:(NSError **)error;
@end

@interface MLParameterKey (RevenantNamed)
+ (instancetype)revenant_keyNamed:(NSString *)name;
@end

@interface MLParameterDescription (RevenantRead)
- (instancetype)revenant_initWithKey:(MLParameterKey *)key
               defaultValue:(id)defaultValue
          numericConstraint:(MLNumericConstraint *)numericConstraint;
@end

#endif
