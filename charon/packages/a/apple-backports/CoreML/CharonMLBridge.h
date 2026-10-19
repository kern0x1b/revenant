#ifndef CHARON_ML_BRIDGE_H
#define CHARON_ML_BRIDGE_H

#include <CoreVideo/CoreVideo.h>
#include <Foundation/Foundation.h>

#include "CharonMLModel.h"
#include "CharonMLValue.h"


#define CHARON_ML_ERROR_GENERIC 0
#define CHARON_ML_ERROR_FEATURE_TYPE 1
#define CHARON_ML_ERROR_IO 3
#define CHARON_ML_ERROR_CUSTOM_LAYER 4
#define CHARON_ML_ERROR_CUSTOM_MODEL 5
#define CHARON_ML_ERROR_UPDATE 6
#define CHARON_ML_ERROR_PARAMETERS 7
#define CHARON_ML_ERROR_DECRYPTION_KEY_FETCH 8
#define CHARON_ML_ERROR_DECRYPTION 9
#define CHARON_ML_ERROR_MODEL_COLLECTION 10

static inline NSError *charon_ml_error(NSError **out, NSInteger code, NSString *message)
{
    if (out == NULL) {
        return nil;
    }
    *out = [NSError errorWithDomain:@"com.apple.CoreML"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : message ?: @"the model could not be used"}];
    return *out;
}

static inline NSError *charon_ml_model_error(NSError **out, NSString *message)
{
    return charon_ml_error(out, CHARON_ML_ERROR_GENERIC, message);
}

static inline MLFeatureType charon_ml_feature_type_of(NSInteger kind)
{
    switch (kind) {
    case CHARON_ML_FEATURE_INT64: return MLFeatureTypeInt64;
    case CHARON_ML_FEATURE_DOUBLE: return MLFeatureTypeDouble;
    case CHARON_ML_FEATURE_STRING: return MLFeatureTypeString;
    case CHARON_ML_FEATURE_IMAGE: return MLFeatureTypeImage;
    case CHARON_ML_FEATURE_MULTI_ARRAY: return MLFeatureTypeMultiArray;
    case CHARON_ML_FEATURE_DICTIONARY: return MLFeatureTypeDictionary;
    case CHARON_ML_FEATURE_SEQUENCE: return MLFeatureTypeSequence;
    default: return MLFeatureTypeInvalid;
    }
}

static inline charon_ml_feature_type charon_ml_feature_kind(MLFeatureType type)
{
    switch (type) {
    case MLFeatureTypeInt64: return CHARON_ML_FEATURE_INT64;
    case MLFeatureTypeDouble: return CHARON_ML_FEATURE_DOUBLE;
    case MLFeatureTypeString: return CHARON_ML_FEATURE_STRING;
    case MLFeatureTypeImage: return CHARON_ML_FEATURE_IMAGE;
    case MLFeatureTypeMultiArray: return CHARON_ML_FEATURE_MULTI_ARRAY;
    case MLFeatureTypeDictionary: return CHARON_ML_FEATURE_DICTIONARY;
    case MLFeatureTypeSequence: return CHARON_ML_FEATURE_SEQUENCE;
    default: return CHARON_ML_FEATURE_NONE;
    }
}

static inline OSType charon_ml_pixel_format_of(int color_space)
{
    switch (color_space) {
    case CHARON_ML_COLOR_RGB:
    case CHARON_ML_COLOR_BGR: return kCVPixelFormatType_32BGRA;
    case CHARON_ML_COLOR_GRAYSCALE: return kCVPixelFormatType_OneComponent8;
    case CHARON_ML_COLOR_GRAYSCALE_FLOAT16: return kCVPixelFormatType_OneComponent16Half;
    default: return (OSType)0;
    }
}

static inline MLMultiArrayDataType charon_ml_array_type(int type)
{
    switch (type) {
    case CHARON_ML_ARRAY_FLOAT32: return MLMultiArrayDataTypeFloat32;
    case CHARON_ML_ARRAY_DOUBLE: return MLMultiArrayDataTypeDouble;
    case CHARON_ML_ARRAY_INT32: return MLMultiArrayDataTypeInt32;
    case CHARON_ML_ARRAY_FLOAT16: return MLMultiArrayDataTypeFloat16;
    default: return (MLMultiArrayDataType)0;
    }
}

static inline int charon_ml_type_of_array(MLMultiArrayDataType type)
{
    switch (type) {
    case MLMultiArrayDataTypeFloat32: return CHARON_ML_ARRAY_FLOAT32;
    case MLMultiArrayDataTypeDouble: return CHARON_ML_ARRAY_DOUBLE;
    case MLMultiArrayDataTypeInt32: return CHARON_ML_ARRAY_INT32;
    case MLMultiArrayDataTypeFloat16: return CHARON_ML_ARRAY_FLOAT16;
    default: return CHARON_ML_ARRAY_INVALID;
    }
}

static inline NSArray<NSNumber *> *charon_ml_shape_to_array(const int64_t *shape, int rank)
{
    NSMutableArray<NSNumber *> *out = [NSMutableArray arrayWithCapacity:(NSUInteger)rank];
    int index;
    for (index = 0; index < rank; index++) {
        [out addObject:@(shape[index])];
    }
    return out;
}

static inline int charon_ml_shape_from_array(NSArray<NSNumber *> *shape, int64_t *out, int room, int *rank)
{
    NSUInteger index, total = shape.count;
    if (total > (NSUInteger)room) {
        return 0;
    }
    for (index = 0; index < total; index++) {
        out[index] = [shape[index] longLongValue];
    }
    *rank = (int)total;
    return 1;
}

@interface MLMultiArray (CharonWindow)
- (instancetype)initWithWindowOf:(charon_ml_array)array;
- (charon_ml_array *)charonArray;
@end

@interface MLSequence (CharonCount)
- (NSUInteger)count;
@end

@interface MLFeatureValue (CharonValue)
- (charon_ml_value *)charonValue;
+ (instancetype)charon_featureValueWithOwned:(charon_ml_value *)value type:(MLFeatureType)type;
@end

static inline charon_ml_value charon_ml_value_owned_copy(const charon_ml_value *value)
{
    charon_ml_value out;
    size_t index;
    memset(&out, 0, sizeof out);
    if (value == NULL) {
        return out;
    }
    switch (value->kind) {
    case CHARON_ML_VALUE_NUMBER:
        return charon_ml_value_number(value->number);
    case CHARON_ML_VALUE_STRING:
        return charon_ml_value_string_copy(value->string.bytes, value->string.length);
    case CHARON_ML_VALUE_ARRAY:
        out = charon_ml_value_array(
            charon_ml_array_alloc(value->array.data_type, value->array.shape, value->array.rank));
        for (index = 0; index < out.array.count && index < value->array.count; index++) {
            charon_ml_array_set(&out.array, (int64_t)index, charon_ml_array_get(&value->array, (int64_t)index));
        }
        return out;
    case CHARON_ML_VALUE_DICTIONARY:
        out = charon_ml_value_dictionary();
        for (index = 0; index < value->dictionary.count; index++) {
            charon_ml_dictionary_put(&out, value->dictionary.keys[index], value->dictionary.values[index]);
        }
        return out;
    default:
        out = *value;
        out.array.owns_data = 0;
        out.string.owned = 0;
        return out;
    }
}

#endif
