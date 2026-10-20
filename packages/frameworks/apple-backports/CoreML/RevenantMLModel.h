#ifndef REVENANT_ML_MODEL_H
#define REVENANT_ML_MODEL_H

#include <stddef.h>

#include "RevenantMLProto.h"
#include "RevenantMLValue.h"

typedef enum {
    REVENANT_ML_KIND_NONE = 0,
    REVENANT_ML_KIND_PIPELINE,
    REVENANT_ML_KIND_PIPELINE_CLASSIFIER,
    REVENANT_ML_KIND_PIPELINE_REGRESSOR,
    REVENANT_ML_KIND_NEURAL_NETWORK,
    REVENANT_ML_KIND_NEURAL_NETWORK_CLASSIFIER,
    REVENANT_ML_KIND_NEURAL_NETWORK_REGRESSOR,
    REVENANT_ML_KIND_TREE_ENSEMBLE_CLASSIFIER,
    REVENANT_ML_KIND_TREE_ENSEMBLE_REGRESSOR,
    REVENANT_ML_KIND_GLM_CLASSIFIER,
    REVENANT_ML_KIND_GLM_REGRESSOR,
    REVENANT_ML_KIND_SVM_CLASSIFIER,
    REVENANT_ML_KIND_SVM_REGRESSOR,
    REVENANT_ML_KIND_KNN_CLASSIFIER,
    REVENANT_ML_KIND_ITEM_SIMILARITY,
    REVENANT_ML_KIND_SCALER,
    REVENANT_ML_KIND_IMPUTER,
    REVENANT_ML_KIND_NORMALIZER,
    REVENANT_ML_KIND_ONE_HOT_ENCODER,
    REVENANT_ML_KIND_DICT_VECTORIZER,
    REVENANT_ML_KIND_FEATURE_VECTORIZER,
    REVENANT_ML_KIND_CATEGORICAL_MAPPING,
    REVENANT_ML_KIND_ARRAY_FEATURE_EXTRACTOR,
    REVENANT_ML_KIND_NON_MAXIMUM_SUPPRESSION,
    REVENANT_ML_KIND_IDENTITY,
    REVENANT_ML_KIND_MIL_PROGRAM,
    REVENANT_ML_KIND_OTHER
} revenant_ml_model_kind;

typedef enum {
    REVENANT_ML_FEATURE_NONE = 0,
    REVENANT_ML_FEATURE_INT64,
    REVENANT_ML_FEATURE_DOUBLE,
    REVENANT_ML_FEATURE_STRING,
    REVENANT_ML_FEATURE_IMAGE,
    REVENANT_ML_FEATURE_MULTI_ARRAY,
    REVENANT_ML_FEATURE_DICTIONARY,
    REVENANT_ML_FEATURE_SEQUENCE,
    REVENANT_ML_FEATURE_STATE
} revenant_ml_feature_type;

enum {
    REVENANT_ML_COLOR_INVALID = 0,
    REVENANT_ML_COLOR_GRAYSCALE = 10,
    REVENANT_ML_COLOR_RGB = 20,
    REVENANT_ML_COLOR_BGR = 30,
    REVENANT_ML_COLOR_GRAYSCALE_FLOAT16 = 40
};

#define REVENANT_ML_MAX_FEATURES 256

typedef struct {
    char *name;
    char *short_description;
    revenant_ml_feature_type type;
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
    revenant_ml_feature_type element_type;
    int64_t count_lower, count_upper;
    int has_count_range;
    size_t enumerated_count;
    int *enumerated_ranks;
    int64_t (*enumerated_shapes)[REVENANT_ML_MAX_RANK];
    int64_t *enumerated_widths, *enumerated_heights;
} revenant_ml_feature;

enum {
    REVENANT_ML_SHAPE_UNSPECIFIED = 0,
    REVENANT_ML_SHAPE_RANGE = 1,
    REVENANT_ML_SHAPE_ENUMERATED = 2
};

typedef struct {
    char *name;
    revenant_ml_value value;
} revenant_ml_feature_value;

#define REVENANT_ML_MAX_PARAMETERS 16
#define REVENANT_ML_MAX_PARAMETER_SET 32

typedef struct {
    char *key;
    revenant_ml_feature_type type;
    double number;
    char *string;
    int has_range;
    double range_min, range_max;
    int has_set;
    int64_t set_values[REVENANT_ML_MAX_PARAMETER_SET];
    size_t set_count;
} revenant_ml_parameter;

typedef struct {
    revenant_ml_feature_value entries[REVENANT_ML_MAX_FEATURES];
    size_t count;
} revenant_ml_features;

#define REVENANT_ML_MAX_FUNCTIONS 8
#define REVENANT_ML_MAX_FUNCTION_FEATURES 16

typedef struct {
    char *name;
    char *predicted_feature_name;
    char *predicted_probabilities_name;
    revenant_ml_feature inputs[REVENANT_ML_MAX_FUNCTION_FEATURES];
    size_t input_count;
    revenant_ml_feature outputs[REVENANT_ML_MAX_FUNCTION_FEATURES];
    size_t output_count;
} revenant_ml_function;

typedef struct {
    revenant_ml_node document;
    revenant_ml_model_kind kind;
    int specification_version;
    revenant_ml_feature inputs[REVENANT_ML_MAX_FEATURES];
    size_t input_count;
    revenant_ml_feature outputs[REVENANT_ML_MAX_FEATURES];
    size_t output_count;
    revenant_ml_feature training_inputs[REVENANT_ML_MAX_FEATURES];
    size_t training_input_count;
    int is_updatable;
    revenant_ml_parameter parameters[REVENANT_ML_MAX_PARAMETERS];
    size_t parameter_count;
    char **user_defined_keys, **user_defined_values;
    size_t user_defined_count;
    revenant_ml_function functions[REVENANT_ML_MAX_FUNCTIONS];
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
} revenant_ml_model;

int revenant_ml_model_read(revenant_ml_model *model, const char *path, char *error, size_t error_size);
int revenant_ml_model_read_data(revenant_ml_model *model, const void *bytes, size_t length, char *error,
                              size_t error_size);
void revenant_ml_model_release(revenant_ml_model *model);

int revenant_ml_model_from_node(revenant_ml_model *model, const revenant_ml_node *document, const char *bundle,
                              char *error, size_t error_size);
const char *revenant_ml_node_kind_name(const revenant_ml_node *document);

const revenant_ml_function *revenant_ml_model_function_at(const revenant_ml_model *model, size_t index);
const revenant_ml_function *revenant_ml_model_function_named(const revenant_ml_model *model, const char *name);

const char *revenant_ml_kind_name(revenant_ml_model_kind kind);
int revenant_ml_kind_is_classifier(revenant_ml_model_kind kind);
const char *revenant_ml_feature_type_name(revenant_ml_feature_type type);

void revenant_ml_features_init(revenant_ml_features *features);
void revenant_ml_features_release(revenant_ml_features *features);
int revenant_ml_features_put(revenant_ml_features *features, const char *name, revenant_ml_value value);
const revenant_ml_value *revenant_ml_features_get(const revenant_ml_features *features, const char *name);
int revenant_ml_features_remove(revenant_ml_features *features, const char *name);

int revenant_ml_features_take_outputs(const revenant_ml_model *model, revenant_ml_features *inputs,
                                    revenant_ml_features *outputs);
int revenant_ml_features_satisfy(const revenant_ml_model *model, const revenant_ml_features *features,
                               char *missing, size_t missing_size, char *mismatched, size_t mismatched_size);

char *revenant_ml_copy_string(const revenant_ml_node *node, const char *field);
char *revenant_ml_strndup(const char *bytes, size_t length);

#endif
