#ifndef CHARON_ML_MODEL_H
#define CHARON_ML_MODEL_H

#include <stddef.h>

#include "CharonMLProto.h"
#include "CharonMLValue.h"

typedef enum {
    CHARON_ML_KIND_NONE = 0,
    CHARON_ML_KIND_PIPELINE,
    CHARON_ML_KIND_PIPELINE_CLASSIFIER,
    CHARON_ML_KIND_PIPELINE_REGRESSOR,
    CHARON_ML_KIND_NEURAL_NETWORK,
    CHARON_ML_KIND_NEURAL_NETWORK_CLASSIFIER,
    CHARON_ML_KIND_NEURAL_NETWORK_REGRESSOR,
    CHARON_ML_KIND_TREE_ENSEMBLE_CLASSIFIER,
    CHARON_ML_KIND_TREE_ENSEMBLE_REGRESSOR,
    CHARON_ML_KIND_GLM_CLASSIFIER,
    CHARON_ML_KIND_GLM_REGRESSOR,
    CHARON_ML_KIND_SVM_CLASSIFIER,
    CHARON_ML_KIND_SVM_REGRESSOR,
    CHARON_ML_KIND_KNN_CLASSIFIER,
    CHARON_ML_KIND_ITEM_SIMILARITY,
    CHARON_ML_KIND_SCALER,
    CHARON_ML_KIND_IMPUTER,
    CHARON_ML_KIND_NORMALIZER,
    CHARON_ML_KIND_ONE_HOT_ENCODER,
    CHARON_ML_KIND_DICT_VECTORIZER,
    CHARON_ML_KIND_FEATURE_VECTORIZER,
    CHARON_ML_KIND_CATEGORICAL_MAPPING,
    CHARON_ML_KIND_ARRAY_FEATURE_EXTRACTOR,
    CHARON_ML_KIND_NON_MAXIMUM_SUPPRESSION,
    CHARON_ML_KIND_IDENTITY,
    CHARON_ML_KIND_MIL_PROGRAM,
    CHARON_ML_KIND_OTHER
} charon_ml_model_kind;

typedef enum {
    CHARON_ML_FEATURE_NONE = 0,
    CHARON_ML_FEATURE_INT64,
    CHARON_ML_FEATURE_DOUBLE,
    CHARON_ML_FEATURE_STRING,
    CHARON_ML_FEATURE_IMAGE,
    CHARON_ML_FEATURE_MULTI_ARRAY,
    CHARON_ML_FEATURE_DICTIONARY,
    CHARON_ML_FEATURE_SEQUENCE,
    CHARON_ML_FEATURE_STATE
} charon_ml_feature_type;

enum {
    CHARON_ML_COLOR_INVALID = 0,
    CHARON_ML_COLOR_GRAYSCALE = 10,
    CHARON_ML_COLOR_RGB = 20,
    CHARON_ML_COLOR_BGR = 30,
    CHARON_ML_COLOR_GRAYSCALE_FLOAT16 = 40
};

#define CHARON_ML_MAX_FEATURES 256

typedef struct {
    char *name;
    char *short_description;
    charon_ml_feature_type type;
    int optional;
    int data_type;
    int rank;
    int64_t shape[8];
    int64_t shape_range[8][2];
    int has_shape_range;
    int shape_kind;
    int image_width, image_height;
    int image_color_space;
    int image_width_range, image_height_range;
    charon_ml_feature_type element_type;
    int64_t count_lower, count_upper;
    int has_count_range;
    size_t enumerated_count;
    int *enumerated_ranks;
    int64_t (*enumerated_shapes)[CHARON_ML_MAX_RANK];
    int64_t *enumerated_widths, *enumerated_heights;
} charon_ml_feature;

enum {
    CHARON_ML_SHAPE_UNSPECIFIED = 0,
    CHARON_ML_SHAPE_RANGE = 1,
    CHARON_ML_SHAPE_ENUMERATED = 2
};

typedef struct {
    char *name;
    charon_ml_value value;
} charon_ml_feature_value;

#define CHARON_ML_MAX_PARAMETERS 16
#define CHARON_ML_MAX_PARAMETER_SET 32

typedef struct {
    char *key;
    charon_ml_feature_type type;
    double number;
    char *string;
    int has_range;
    double range_min, range_max;
    int has_set;
    int64_t set_values[CHARON_ML_MAX_PARAMETER_SET];
    size_t set_count;
} charon_ml_parameter;

typedef struct {
    charon_ml_feature_value entries[CHARON_ML_MAX_FEATURES];
    size_t count;
} charon_ml_features;

#define CHARON_ML_MAX_FUNCTIONS 8
#define CHARON_ML_MAX_FUNCTION_FEATURES 16

typedef struct {
    char *name;
    char *predicted_feature_name;
    char *predicted_probabilities_name;
    charon_ml_feature inputs[CHARON_ML_MAX_FUNCTION_FEATURES];
    size_t input_count;
    charon_ml_feature outputs[CHARON_ML_MAX_FUNCTION_FEATURES];
    size_t output_count;
} charon_ml_function;

typedef struct {
    charon_ml_node document;
    charon_ml_model_kind kind;
    int specification_version;
    charon_ml_feature inputs[CHARON_ML_MAX_FEATURES];
    size_t input_count;
    charon_ml_feature outputs[CHARON_ML_MAX_FEATURES];
    size_t output_count;
    charon_ml_feature training_inputs[CHARON_ML_MAX_FEATURES];
    size_t training_input_count;
    int is_updatable;
    charon_ml_parameter parameters[CHARON_ML_MAX_PARAMETERS];
    size_t parameter_count;
    char **user_defined_keys, **user_defined_values;
    size_t user_defined_count;
    charon_ml_function functions[CHARON_ML_MAX_FUNCTIONS];
    size_t function_count;
    char *predicted_feature_name;
    char *predicted_probabilities_name;
    char **class_labels;
    size_t class_label_count;
    int class_labels_are_numbers;
    char *author;
    char *license;
    char *short_description;
    char *version;
    char *bundle;
    char *bytes;
    int borrowed;
} charon_ml_model;

int charon_ml_model_read(charon_ml_model *model, const char *path, char *error, size_t error_size);
int charon_ml_model_read_data(charon_ml_model *model, const void *bytes, size_t length, char *error,
                              size_t error_size);
void charon_ml_model_release(charon_ml_model *model);

int charon_ml_model_from_node(charon_ml_model *model, const charon_ml_node *document, const char *bundle,
                              char *error, size_t error_size);
const char *charon_ml_node_kind_name(const charon_ml_node *document);

const charon_ml_function *charon_ml_model_function_at(const charon_ml_model *model, size_t index);
const charon_ml_function *charon_ml_model_function_named(const charon_ml_model *model, const char *name);

const char *charon_ml_kind_name(charon_ml_model_kind kind);
int charon_ml_kind_is_classifier(charon_ml_model_kind kind);
const char *charon_ml_feature_type_name(charon_ml_feature_type type);

void charon_ml_features_init(charon_ml_features *features);
void charon_ml_features_release(charon_ml_features *features);
int charon_ml_features_put(charon_ml_features *features, const char *name, charon_ml_value value);
const charon_ml_value *charon_ml_features_get(const charon_ml_features *features, const char *name);
int charon_ml_features_remove(charon_ml_features *features, const char *name);

int charon_ml_features_take_outputs(const charon_ml_model *model, charon_ml_features *inputs,
                                    charon_ml_features *outputs);
int charon_ml_features_satisfy(const charon_ml_model *model, const charon_ml_features *features,
                               char *missing, size_t missing_size, char *mismatched, size_t mismatched_size);

char *charon_ml_copy_string(const charon_ml_node *node, const char *field);
char *charon_ml_strndup(const char *bytes, size_t length);

#endif
