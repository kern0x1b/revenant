/* The initialisers this package's own classes are built with, and nothing else.
 *
 * Core ML's classes arrive with no public initialiser: a feature description, a constraint, a
 * key and a model description are all made by a model and read by an application, and there is
 * no API for making one out of nothing. A port that has to build them -- and it does, because
 * the model reader has the specification's own fields and the classes have to be filled from
 * them -- needs an initialiser of its own, and it needs it to be the same one in every file that
 * builds one of these objects.
 *
 * That is all this header is: declarations of initialisers that the classes in this package
 * implement, for the other files of this package to call. They are not Core ML's API, nothing
 * exports them, and an application cannot reach one: each is declared as a category on a class
 * Core ML itself declares, which is a declaration and not a definition, and the definitions live
 * in the class's own implementation. The selectors they add are not in the registry, because
 * they are not part of the surface this port carries.
 *
 * A header rather than a .c or a .m file, for the reason CharonMLBridge.h gives: a .c file of
 * this package is compiled as C and cannot import Core ML, and a .m file is not compiled with
 * hidden visibility and would put these in the library's exports.
 */
#ifndef CHARON_ML_INTERNAL_H
#define CHARON_ML_INTERNAL_H

#import <CoreML/CoreML.h>

#include "CharonMLModel.h"

/* The description of one feature of the model the reader read: the reader's own struct, which
 * the description copies and outlives. */
/* A value of the invalid type: what an object that cannot be a feature value becomes. Not an
 * undefined value -- that one is a value the caller left out on purpose and keeps the type it was
 * given -- but a value that holds nothing and says its type is the invalid one. */
@interface MLFeatureValue (CharonInvalid)
+ (instancetype)charon_featureValueOfInvalidType;
@end

@interface MLFeatureDescription (CharonRead)
- (instancetype)charon_initWithFeature:(const charon_ml_feature *)feature;
- (instancetype)charon_initWithName:(NSString *)name type:(MLFeatureType)type optional:(BOOL)optional;
@end

/* The constraints, each built from the part of the specification's own message it reads. */
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

/* The description of a model, and the configuration, the options and the asset that go with a
 * model: each is built once by the model that carries it. */
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

/* A key by its own name, which is how the specification's parameter names are turned into the
 * keys an application asks a model by. The keys of the specification are the keys of the
 * framework: learningRate is the name the specification's own update parameters use and the name
 * MLParameterKey.learningRate answers. */
@interface MLParameterKey (CharonNamed)
+ (instancetype)charon_keyNamed:(NSString *)name;
@end

@interface MLParameterDescription (CharonRead)
- (instancetype)charon_initWithKey:(MLParameterKey *)key
               defaultValue:(id)defaultValue
          numericConstraint:(MLNumericConstraint *)numericConstraint;
@end

#endif /* CHARON_ML_INTERNAL_H */
