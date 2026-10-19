#ifndef CHARON_ML_INTERNAL_H
#define CHARON_ML_INTERNAL_H

#import <CoreML/CoreML.h>

#include "CharonMLModel.h"

@interface MLFeatureValue (CharonInvalid)
+ (instancetype)charon_featureValueOfInvalidType;
@end

@interface MLFeatureDescription (CharonRead)
- (instancetype)charon_initWithFeature:(const charon_ml_feature *)feature;
- (instancetype)charon_initWithName:(NSString *)name type:(MLFeatureType)type optional:(BOOL)optional;
@end

@interface MLMultiArrayShapeConstraint (CharonRead)
- (instancetype)charon_initWithType:(MLMultiArrayShapeConstraintType)type
                  sizeRanges:(NSArray<NSValue *> *)sizeRanges
           enumeratedShapes:(NSArray<NSArray<NSNumber *> *> *)enumeratedShapes;
@end

@interface MLMultiArrayConstraint (CharonRead)
- (instancetype)charon_initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
               shapeConstraint:(MLMultiArrayShapeConstraint *)shapeConstraint;
@end

@interface MLImageSize (CharonRead)
- (instancetype)charon_initWithPixelsWide:(NSInteger)pixelsWide pixelsHigh:(NSInteger)pixelsHigh;
@end

@interface MLImageSizeConstraint (CharonRead)
- (instancetype)charon_initWithType:(MLImageSizeConstraintType)type
              pixelsWideRange:(NSRange)pixelsWideRange
             pixelsHighRange:(NSRange)pixelsHighRange
        enumeratedImageSizes:(NSArray<MLImageSize *> *)enumeratedImageSizes;
@end

@interface MLImageConstraint (CharonRead)
- (instancetype)charon_initWithPixelsHigh:(NSInteger)pixelsHigh
                        pixelsWide:(NSInteger)pixelsWide
                  pixelFormatType:(OSType)pixelFormatType
                    sizeConstraint:(MLImageSizeConstraint *)sizeConstraint;
@end

@interface MLDictionaryConstraint (CharonRead)
- (instancetype)charon_initWithKeyType:(MLFeatureType)keyType;
@end

@interface MLSequenceConstraint (CharonRead)
- (instancetype)charon_initWithValueDescription:(MLFeatureDescription *)valueDescription
                              countRange:(NSRange)countRange;
@end

@interface MLNumericConstraint (CharonRead)
- (instancetype)charon_initWithMinNumber:(NSNumber *)minNumber
                         maxNumber:(NSNumber *)maxNumber
                enumeratedNumbers:(NSSet<NSNumber *> *)enumeratedNumbers;
@end

@interface MLModelDescription (CharonRead)
- (instancetype)charon_initWithModel:(const charon_ml_model *)model;
- (instancetype)charon_initWithFunction:(const charon_ml_function *)function;
@end

@interface MLModelAsset (CharonRead)
- (NSData *)charon_specificationData;
- (NSArray<NSString *> *)charon_functionNamesWithError:(NSError **)error;
- (MLModelDescription *)charon_descriptionOfFunctionNamed:(NSString *)functionName error:(NSError **)error;
@end

@interface MLModel (CharonRead)
- (instancetype)charon_initWithContentsOfAsset:(MLModelAsset *)asset
                           configuration:(MLModelConfiguration *)configuration
                                   error:(NSError **)error;
@end

@interface MLParameterKey (CharonNamed)
+ (instancetype)charon_keyNamed:(NSString *)name;
@end

@interface MLParameterDescription (CharonRead)
- (instancetype)charon_initWithKey:(MLParameterKey *)key
               defaultValue:(id)defaultValue
          numericConstraint:(MLNumericConstraint *)numericConstraint;
@end

#endif
