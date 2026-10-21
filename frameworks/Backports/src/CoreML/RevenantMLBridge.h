#ifndef REVENANT_ML_BRIDGE_H
#define REVENANT_ML_BRIDGE_H

#include <CoreVideo/CoreVideo.h>
#include <Foundation/Foundation.h>

#include "RevenantMLModel.h"
#include "RevenantMLValue.h"


#define REVENANT_ML_ERROR_GENERIC 0
#define REVENANT_ML_ERROR_FEATURE_TYPE 1
#define REVENANT_ML_ERROR_IO 3
#define REVENANT_ML_ERROR_CUSTOM_LAYER 4
#define REVENANT_ML_ERROR_CUSTOM_MODEL 5
#define REVENANT_ML_ERROR_UPDATE 6
#define REVENANT_ML_ERROR_PARAMETERS 7
#define REVENANT_ML_ERROR_DECRYPTION_KEY_FETCH 8
#define REVENANT_ML_ERROR_DECRYPTION 9
#define REVENANT_ML_ERROR_MODEL_COLLECTION 10

static inline NSError *revenant_ml_error(NSError **out, NSInteger code, NSString *message)
{
    if (out == NULL) {
        return nil;
    }
    *out = [NSError errorWithDomain:@"com.apple.CoreML"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : message ?: @"the model could not be used"}];
    return *out;
}

static inline NSError *revenant_ml_model_error(NSError **out, NSString *message)
{
    return revenant_ml_error(out, REVENANT_ML_ERROR_GENERIC, message);
}

static inline MLFeatureType revenant_ml_feature_type_of(NSInteger kind)
{
    switch (kind) {
    case REVENANT_ML_FEATURE_INT64: return MLFeatureTypeInt64;
    case REVENANT_ML_FEATURE_DOUBLE: return MLFeatureTypeDouble;
    case REVENANT_ML_FEATURE_STRING: return MLFeatureTypeString;
    case REVENANT_ML_FEATURE_IMAGE: return MLFeatureTypeImage;
    case REVENANT_ML_FEATURE_MULTI_ARRAY: return MLFeatureTypeMultiArray;
    case REVENANT_ML_FEATURE_DICTIONARY: return MLFeatureTypeDictionary;
    case REVENANT_ML_FEATURE_SEQUENCE: return MLFeatureTypeSequence;
    default: return MLFeatureTypeInvalid;
    }
}

static inline revenant_ml_feature_type revenant_ml_feature_kind(MLFeatureType type)
{
    switch (type) {
    case MLFeatureTypeInt64: return REVENANT_ML_FEATURE_INT64;
    case MLFeatureTypeDouble: return REVENANT_ML_FEATURE_DOUBLE;
    case MLFeatureTypeString: return REVENANT_ML_FEATURE_STRING;
    case MLFeatureTypeImage: return REVENANT_ML_FEATURE_IMAGE;
    case MLFeatureTypeMultiArray: return REVENANT_ML_FEATURE_MULTI_ARRAY;
    case MLFeatureTypeDictionary: return REVENANT_ML_FEATURE_DICTIONARY;
    case MLFeatureTypeSequence: return REVENANT_ML_FEATURE_SEQUENCE;
    default: return REVENANT_ML_FEATURE_NONE;
    }
}

static inline OSType revenant_ml_pixel_format_of(int color_space)
{
    switch (color_space) {
    case REVENANT_ML_COLOR_RGB:
    case REVENANT_ML_COLOR_BGR: return kCVPixelFormatType_32BGRA;
    case REVENANT_ML_COLOR_GRAYSCALE: return kCVPixelFormatType_OneComponent8;
    case REVENANT_ML_COLOR_GRAYSCALE_FLOAT16: return kCVPixelFormatType_OneComponent16Half;
    default: return (OSType)0;
    }
}

static inline MLMultiArrayDataType revenant_ml_array_type(int type)
{
    switch (type) {
    case REVENANT_ML_ARRAY_FLOAT32: return MLMultiArrayDataTypeFloat32;
    case REVENANT_ML_ARRAY_DOUBLE: return MLMultiArrayDataTypeDouble;
    case REVENANT_ML_ARRAY_INT32: return MLMultiArrayDataTypeInt32;
    case REVENANT_ML_ARRAY_FLOAT16: return MLMultiArrayDataTypeFloat16;
    default: return (MLMultiArrayDataType)0;
    }
}

static inline int revenant_ml_type_of_array(MLMultiArrayDataType type)
{
    switch (type) {
    case MLMultiArrayDataTypeFloat32: return REVENANT_ML_ARRAY_FLOAT32;
    case MLMultiArrayDataTypeDouble: return REVENANT_ML_ARRAY_DOUBLE;
    case MLMultiArrayDataTypeInt32: return REVENANT_ML_ARRAY_INT32;
    case MLMultiArrayDataTypeFloat16: return REVENANT_ML_ARRAY_FLOAT16;
    default: return REVENANT_ML_ARRAY_INVALID;
    }
}

static inline NSArray<NSNumber *> *revenant_ml_shape_to_array(const int64_t *shape, int rank)
{
    NSMutableArray<NSNumber *> *out = [NSMutableArray arrayWithCapacity:(NSUInteger)rank];
    int index;
    for (index = 0; index < rank; index++) {
        [out addObject:@(shape[index])];
    }
    return out;
}

static inline int revenant_ml_shape_from_array(NSArray<NSNumber *> *shape, int64_t *out, int room, int *rank)
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

@interface MLMultiArray (RevenantWindow)
- (instancetype)initWithWindowOf:(revenant_ml_array)array;
- (revenant_ml_array *)revenantArray;
@end

@interface MLSequence (RevenantCount)
- (NSUInteger)count;
@end

@interface MLFeatureValue (RevenantValue)
- (revenant_ml_value *)revenantValue;
+ (instancetype)revenant_featureValueWithOwned:(revenant_ml_value *)value type:(MLFeatureType)type;
@end

static inline revenant_ml_value revenant_ml_value_owned_copy(const revenant_ml_value *value)
{
    revenant_ml_value out;
    size_t index;
    memset(&out, 0, sizeof out);
    if (value == NULL) {
        return out;
    }
    switch (value->kind) {
    case REVENANT_ML_VALUE_NUMBER:
        return revenant_ml_value_number(value->number);
    case REVENANT_ML_VALUE_STRING:
        return revenant_ml_value_string_copy(value->string.bytes, value->string.length);
    case REVENANT_ML_VALUE_ARRAY:
        out = revenant_ml_value_array(
            revenant_ml_array_alloc(value->array.data_type, value->array.shape, value->array.rank));
        for (index = 0; index < out.array.count && index < value->array.count; index++) {
            revenant_ml_array_set(&out.array, (int64_t)index, revenant_ml_array_get(&value->array, (int64_t)index));
        }
        return out;
    case REVENANT_ML_VALUE_DICTIONARY:
        out = revenant_ml_value_dictionary();
        for (index = 0; index < value->dictionary.count; index++) {
            revenant_ml_dictionary_put(&out, value->dictionary.keys[index], value->dictionary.values[index]);
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
