#include "RevenantMLModel.h"
#include "RevenantMLValue.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static const struct {
    const char *field;
    revenant_ml_model_kind kind;
} MODEL_KINDS[] = {
    {"pipelineClassifier", REVENANT_ML_KIND_PIPELINE_CLASSIFIER},
    {"pipelineRegressor", REVENANT_ML_KIND_PIPELINE_REGRESSOR},
    {"pipeline", REVENANT_ML_KIND_PIPELINE},
    {"neuralNetworkClassifier", REVENANT_ML_KIND_NEURAL_NETWORK_CLASSIFIER},
    {"neuralNetworkRegressor", REVENANT_ML_KIND_NEURAL_NETWORK_REGRESSOR},
    {"neuralNetwork", REVENANT_ML_KIND_NEURAL_NETWORK},
    {"treeEnsembleClassifier", REVENANT_ML_KIND_TREE_ENSEMBLE_CLASSIFIER},
    {"treeEnsembleRegressor", REVENANT_ML_KIND_TREE_ENSEMBLE_REGRESSOR},
    {"glmClassifier", REVENANT_ML_KIND_GLM_CLASSIFIER},
    {"glmRegressor", REVENANT_ML_KIND_GLM_REGRESSOR},
    {"supportVectorClassifier", REVENANT_ML_KIND_SVM_CLASSIFIER},
    {"supportVectorRegressor", REVENANT_ML_KIND_SVM_REGRESSOR},
    {"kNearestNeighborsClassifier", REVENANT_ML_KIND_KNN_CLASSIFIER},
    {"itemSimilarityRecommender", REVENANT_ML_KIND_ITEM_SIMILARITY},
    {"scaler", REVENANT_ML_KIND_SCALER},
    {"imputer", REVENANT_ML_KIND_IMPUTER},
    {"normalizer", REVENANT_ML_KIND_NORMALIZER},
    {"oneHotEncoder", REVENANT_ML_KIND_ONE_HOT_ENCODER},
    {"dictVectorizer", REVENANT_ML_KIND_DICT_VECTORIZER},
    {"featureVectorizer", REVENANT_ML_KIND_FEATURE_VECTORIZER},
    {"categoricalMapping", REVENANT_ML_KIND_CATEGORICAL_MAPPING},
    {"arrayFeatureExtractor", REVENANT_ML_KIND_ARRAY_FEATURE_EXTRACTOR},
    {"nonMaximumSuppression", REVENANT_ML_KIND_NON_MAXIMUM_SUPPRESSION},
    {"identity", REVENANT_ML_KIND_IDENTITY},
    {"mlProgram", REVENANT_ML_KIND_MIL_PROGRAM},
    {NULL, REVENANT_ML_KIND_NONE}};

const char *revenant_ml_kind_name(revenant_ml_model_kind kind)
{
    int index;
    for (index = 0; MODEL_KINDS[index].field != NULL; index++) {
        if (MODEL_KINDS[index].kind == kind) {
            return MODEL_KINDS[index].field;
        }
    }
    return kind == REVENANT_ML_KIND_NONE ? "none" : "other";
}

int revenant_ml_kind_is_classifier(revenant_ml_model_kind kind)
{
    switch (kind) {
    case REVENANT_ML_KIND_PIPELINE_CLASSIFIER:
    case REVENANT_ML_KIND_NEURAL_NETWORK_CLASSIFIER:
    case REVENANT_ML_KIND_TREE_ENSEMBLE_CLASSIFIER:
    case REVENANT_ML_KIND_GLM_CLASSIFIER:
    case REVENANT_ML_KIND_SVM_CLASSIFIER:
    case REVENANT_ML_KIND_KNN_CLASSIFIER:
        return 1;
    default:
        return 0;
    }
}

const char *revenant_ml_feature_type_name(revenant_ml_feature_type type)
{
    switch (type) {
    case REVENANT_ML_FEATURE_INT64:
        return "int64";
    case REVENANT_ML_FEATURE_DOUBLE:
        return "double";
    case REVENANT_ML_FEATURE_STRING:
        return "string";
    case REVENANT_ML_FEATURE_IMAGE:
        return "image";
    case REVENANT_ML_FEATURE_MULTI_ARRAY:
        return "multiArray";
    case REVENANT_ML_FEATURE_DICTIONARY:
        return "dictionary";
    case REVENANT_ML_FEATURE_SEQUENCE:
        return "sequence";
    case REVENANT_ML_FEATURE_STATE:
        return "state";
    default:
        return "none";
    }
}

char *revenant_ml_copy_string(const revenant_ml_node *node, const char *field)
{
    const revenant_ml_node *value = revenant_ml_get(node, field);
    char *copy;
    if (value == NULL || value->field == NULL ||
        (value->field->kind != REVENANT_ML_KIND_STRING && value->field->kind != REVENANT_ML_KIND_BYTES)) {
        return NULL;
    }
    copy = (char *)malloc(value->value.text.length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, value->value.text.bytes, value->value.text.length);
    copy[value->value.text.length] = 0;
    return copy;
}

static void read_feature(revenant_ml_feature *feature, const revenant_ml_node *described)
{
    const revenant_ml_node *type;
    int index;

    memset(feature, 0, sizeof *feature);
    feature->name = revenant_ml_copy_string(described, "name");
    feature->short_description = revenant_ml_copy_string(described, "shortDescription");
    feature->image_color_space = REVENANT_ML_COLOR_INVALID;
    feature->image_width_range = feature->image_height_range = REVENANT_ML_FLEXIBLE;
    for (index = 0; index < 8; index++) {
        feature->shape[index] = REVENANT_ML_FLEXIBLE;
        feature->shape_range[index][0] = 0;
        feature->shape_range[index][1] = REVENANT_ML_FLEXIBLE;
    }
    type = revenant_ml_get(described, "type");
    if (type == NULL) {
        return;
    }
    for (index = 0; index < (int)revenant_ml_count(type); index++) {
        const revenant_ml_node *entry = revenant_ml_at(type, index);
        const char *name = entry->field->name;
        const revenant_ml_node *body = entry;
        if (strcmp(name, "isOptional") == 0) {
            feature->optional = revenant_ml_int(entry, 0) != 0;
            continue;
        }
        if (strcmp(name, "int64Type") == 0) {
            feature->type = REVENANT_ML_FEATURE_INT64;
        } else if (strcmp(name, "doubleType") == 0) {
            feature->type = REVENANT_ML_FEATURE_DOUBLE;
        } else if (strcmp(name, "stringType") == 0) {
            feature->type = REVENANT_ML_FEATURE_STRING;
        } else if (strcmp(name, "imageType") == 0) {
            feature->type = REVENANT_ML_FEATURE_IMAGE;
        } else if (strcmp(name, "multiArrayType") == 0) {
            feature->type = REVENANT_ML_FEATURE_MULTI_ARRAY;
        } else if (strcmp(name, "dictionaryType") == 0) {
            feature->type = REVENANT_ML_FEATURE_DICTIONARY;
        } else if (strcmp(name, "sequenceType") == 0) {
            feature->type = REVENANT_ML_FEATURE_SEQUENCE;
            {
                size_t element;
                for (element = 0; element < revenant_ml_count(body); element++) {
                    const revenant_ml_node *entry = revenant_ml_at(body, element);
                    const char *which = entry->field != NULL ? entry->field->name : "";
                    if (strcmp(which, "int64Type") == 0) {
                        feature->element_type = REVENANT_ML_FEATURE_INT64;
                    } else if (strcmp(which, "stringType") == 0) {
                        feature->element_type = REVENANT_ML_FEATURE_STRING;
                    }
                }
            }
            {
                const revenant_ml_node *range = revenant_ml_get(body, "sizeRange");
                if (range != NULL) {
                    feature->has_count_range = 1;
                    feature->count_lower = revenant_ml_int(revenant_ml_get(range, "lowerBound"), 0);
                    feature->count_upper =
                        revenant_ml_int(revenant_ml_get(range, "upperBound"), REVENANT_ML_FLEXIBLE);
                }
            }
        } else if (strcmp(name, "stateType") == 0) {
            feature->type = REVENANT_ML_FEATURE_STATE;
        } else {
            continue;
        }
        if (feature->type == REVENANT_ML_FEATURE_IMAGE) {
            const revenant_ml_node *range = revenant_ml_get(body, "imageSizeRange");
            const revenant_ml_node *sizes = revenant_ml_get(body, "enumeratedSizes");
            feature->image_width = revenant_ml_int(revenant_ml_get(body, "width"), 0);
            feature->image_height = revenant_ml_int(revenant_ml_get(body, "height"), 0);
            feature->image_color_space = revenant_ml_int(revenant_ml_get(body, "colorSpace"), REVENANT_ML_COLOR_INVALID);
            if (range == NULL && feature->image_width > 0 && feature->image_height > 0) {
                feature->image_width_range = 0;
                feature->image_height_range = 0;
            }
            if (range != NULL) {
                const revenant_ml_node *width = revenant_ml_get(range, "widthRange");
                const revenant_ml_node *height = revenant_ml_get(range, "heightRange");
                feature->image_width_range = revenant_ml_int(revenant_ml_get(width, "lowerBound"), 0);
                feature->image_width = revenant_ml_int(revenant_ml_get(width, "upperBound"), feature->image_width);
                feature->image_height_range = revenant_ml_int(revenant_ml_get(height, "lowerBound"), 0);
                feature->image_height = revenant_ml_int(revenant_ml_get(height, "upperBound"), feature->image_height);
            }
            if (sizes != NULL) {
                size_t total = revenant_ml_count_field(sizes, "sizes");
                if (total > 0) {
                    feature->enumerated_widths = (int64_t *)calloc(total, sizeof *feature->enumerated_widths);
                    feature->enumerated_heights = (int64_t *)calloc(total, sizeof *feature->enumerated_heights);
                    if (feature->enumerated_widths != NULL && feature->enumerated_heights != NULL) {
                        for (index = 0; index < (int)total; index++) {
                            const revenant_ml_node *size =
                                revenant_ml_node_at_field(sizes, "sizes", (size_t)index);
                            feature->enumerated_widths[index] =
                                revenant_ml_int(revenant_ml_get(size, "width"), 0);
                            feature->enumerated_heights[index] =
                                revenant_ml_int(revenant_ml_get(size, "height"), 0);
                        }
                        feature->enumerated_count = total;
                    } else {
                        free(feature->enumerated_widths);
                        free(feature->enumerated_heights);
                        feature->enumerated_widths = feature->enumerated_heights = NULL;
                    }
                }
            }
        } else if (feature->type == REVENANT_ML_FEATURE_MULTI_ARRAY) {
            const revenant_ml_node *range = revenant_ml_get(body, "shapeRange");
            const revenant_ml_node *shapes = revenant_ml_get(body, "enumeratedShapes");
            feature->data_type = revenant_ml_int(revenant_ml_get(body, "dataType"), REVENANT_ML_ARRAY_INVALID);
            feature->rank = (int)revenant_ml_count_field(body, "shape");
            if (feature->rank > 8) {
                feature->rank = 8;
            }
            for (index = 0; index < feature->rank; index++) {
                feature->shape[index] = revenant_ml_int_at(body, "shape", (size_t)index, REVENANT_ML_FLEXIBLE);
            }
            if (range != NULL) {
                size_t sizes = revenant_ml_count_field(range, "sizeRanges");
                if (sizes > 0) {
                    feature->has_shape_range = 1;
                    feature->shape_kind = REVENANT_ML_SHAPE_RANGE;
                    for (index = 0; index < (int)sizes && index < 8; index++) {
                        const revenant_ml_node *bounds = revenant_ml_node_at_field(range, "sizeRanges", (size_t)index);
                        feature->shape_range[index][0] = revenant_ml_int(revenant_ml_get(bounds, "lowerBound"), 0);
                        feature->shape_range[index][1] = revenant_ml_int(revenant_ml_get(bounds, "upperBound"), REVENANT_ML_FLEXIBLE);
                        if (feature->shape[index] == 0) {
                            feature->shape[index] = feature->shape_range[index][1];
                        }
                    }
                }
            }
            if (shapes != NULL) {
                size_t total = revenant_ml_count_field(shapes, "shapes");
                if (total > 0) {
                    feature->enumerated_ranks = (int *)calloc(total, sizeof *feature->enumerated_ranks);
                    feature->enumerated_shapes =
                        (int64_t (*)[REVENANT_ML_MAX_RANK])calloc(total, sizeof *feature->enumerated_shapes);
                    if (feature->enumerated_ranks != NULL && feature->enumerated_shapes != NULL) {
                        for (index = 0; index < (int)total; index++) {
                            const revenant_ml_node *entry =
                                revenant_ml_node_at_field(shapes, "shapes", (size_t)index);
                            size_t dimensions = revenant_ml_count_field(entry, "shape"), axis;
                            if (dimensions > REVENANT_ML_MAX_RANK) {
                                dimensions = REVENANT_ML_MAX_RANK;
                            }
                            feature->enumerated_ranks[index] = (int)dimensions;
                            for (axis = 0; axis < dimensions; axis++) {
                                feature->enumerated_shapes[index][axis] =
                                    revenant_ml_int_at(entry, "shape", axis, REVENANT_ML_FLEXIBLE);
                            }
                        }
                        feature->enumerated_count = total;
                        if (feature->shape_kind != REVENANT_ML_SHAPE_RANGE) {
                            feature->shape_kind = REVENANT_ML_SHAPE_ENUMERATED;
                        }
                    } else {
                        free(feature->enumerated_ranks);
                        free(feature->enumerated_shapes);
                        feature->enumerated_ranks = NULL;
                        feature->enumerated_shapes = NULL;
                    }
                }
            }
        }
        break;
    }
}

static void release_feature(revenant_ml_feature *feature)
{
    free(feature->name);
    free(feature->short_description);
    free(feature->enumerated_ranks);
    free(feature->enumerated_shapes);
    free(feature->enumerated_widths);
    free(feature->enumerated_heights);
    feature->name = NULL;
    feature->short_description = NULL;
    feature->enumerated_ranks = NULL;
    feature->enumerated_shapes = NULL;
    feature->enumerated_widths = NULL;
    feature->enumerated_heights = NULL;
    feature->enumerated_count = 0;
}

static size_t read_feature_list(revenant_ml_feature *into, size_t room, const revenant_ml_node *description,
                                const char *field)
{
    size_t total = revenant_ml_count_field(description, field), index, kept = 0;
    for (index = 0; index < total && kept < room; index++) {
        read_feature(&into[kept], revenant_ml_node_at_field(description, field, index));
        kept++;
    }
    return kept;
}

static size_t read_class_labels(revenant_ml_model *model, const revenant_ml_node *kind_node)
{
    const revenant_ml_node *labels = revenant_ml_oneof(kind_node, "stringClassLabels");
    size_t count, index;
    if (labels == NULL) {
        labels = revenant_ml_oneof(kind_node, "int64ClassLabels");
        model->class_labels_are_numbers = 1;
    }
    if (labels == NULL) {
        model->class_labels_are_numbers = 0;
        return 0;
    }
    count = revenant_ml_count_field(labels, "vector");
    if (count == 0) {
        return 0;
    }
    model->class_labels = (char **)calloc(count, sizeof *model->class_labels);
    if (model->class_labels == NULL) {
        return 0;
    }
    for (index = 0; index < count; index++) {
        const revenant_ml_node *entry = revenant_ml_node_at_field(labels, "vector", index);
        if (model->class_labels_are_numbers) {
            char text[32];
            snprintf(text, sizeof text, "%lld",
                     (long long)(entry != NULL ? entry->value.integer : 0));
            model->class_labels[index] = revenant_ml_strndup(text, strlen(text));
        } else if (entry != NULL && entry->value.text.length < 4096) {
            model->class_labels[index] = revenant_ml_strndup(entry->value.text.bytes, entry->value.text.length);
        } else {
            model->class_labels[index] = revenant_ml_strndup("", 0);
        }
    }
    model->class_label_count = count;
    return count;
}

static char *slurp(const char *path, size_t *length)
{
    FILE *file = fopen(path, "rb");
    char *bytes;
    long size;
    if (file == NULL) {
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0 || (size = ftell(file)) < 0) {
        fclose(file);
        return NULL;
    }
    rewind(file);
    bytes = (char *)malloc((size_t)size + 1);
    if (bytes == NULL || (size > 0 && fread(bytes, 1, (size_t)size, file) != (size_t)size)) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    bytes[size] = 0;
    *length = (size_t)size;
    return bytes;
}

static int is_directory(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0 && S_ISDIR(info.st_mode);
}

static int file_exists(const char *path)
{
    struct stat info;
    return stat(path, &info) == 0 && S_ISREG(info.st_mode);
}

static void join(char *out, size_t size, const char *directory, const char *name)
{
    size_t used = strlen(directory);
    snprintf(out, size, "%s%s%s", directory, used > 0 && directory[used - 1] == '/' ? "" : "/", name);
}

const char *revenant_ml_node_kind_name(const revenant_ml_node *document)
{
    int index;
    for (index = 0; MODEL_KINDS[index].field != NULL; index++) {
        if (revenant_ml_get(document, MODEL_KINDS[index].field) != NULL) {
            return MODEL_KINDS[index].field;
        }
    }
    return NULL;
}

static void read_parameter(revenant_ml_parameter *parameter, const char *key, const revenant_ml_node *node)
{
    const revenant_ml_node *range, *set;
    memset(parameter, 0, sizeof *parameter);
    parameter->key = strdup(key);
    if (strcmp(key, "shuffle") == 0) {
        parameter->type = REVENANT_ML_FEATURE_INT64;
        parameter->number = revenant_ml_int(revenant_ml_get(node, "defaultValue"), 0);
        return;
    }
    if (strcmp(key, "seed") == 0 || strcmp(key, "epochs") == 0 ||
        strcmp(key, "miniBatchSize") == 0 || strcmp(key, "numberOfNeighbors") == 0) {
        parameter->type = REVENANT_ML_FEATURE_INT64;
        parameter->number = (double)revenant_ml_int(revenant_ml_get(node, "defaultValue"), 0);
    } else {
        parameter->type = REVENANT_ML_FEATURE_DOUBLE;
        parameter->number = revenant_ml_double(revenant_ml_get(node, "defaultValue"), 0.0);
    }
    range = revenant_ml_get(node, "range");
    if (range != NULL) {
        parameter->has_range = 1;
        parameter->range_min = revenant_ml_double(revenant_ml_get(range, "minValue"), 0.0);
        parameter->range_max = revenant_ml_double(revenant_ml_get(range, "maxValue"), 0.0);
    }
    set = revenant_ml_get(node, "set");
    if (set != NULL) {
        size_t total = revenant_ml_count_field(set, "values"), index;
        if (total > REVENANT_ML_MAX_PARAMETER_SET) {
            total = REVENANT_ML_MAX_PARAMETER_SET;
        }
        for (index = 0; index < total; index++) {
            parameter->set_values[index] = revenant_ml_int_at(set, "values", index, 0);
        }
        parameter->set_count = total;
        parameter->has_set = total > 0;
    }
}

static void put_parameter(revenant_ml_model *model, const char *key, const revenant_ml_node *node)
{
    if (node == NULL || model->parameter_count >= REVENANT_ML_MAX_PARAMETERS) {
        return;
    }
    read_parameter(&model->parameters[model->parameter_count], key, node);
    if (model->parameters[model->parameter_count].key != NULL) {
        model->parameter_count++;
    }
}

static void read_functions(revenant_ml_model *model, const revenant_ml_node *description)
{
    size_t total = revenant_ml_count_field(description, "functions"), index;
    for (index = 0; index < total && model->function_count < REVENANT_ML_MAX_FUNCTIONS; index++) {
        const revenant_ml_node *entry = revenant_ml_node_at_field(description, "functions", index);
        revenant_ml_function *function = &model->functions[model->function_count];
        memset(function, 0, sizeof *function);
        function->name = revenant_ml_copy_string(entry, "name");
        function->predicted_feature_name = revenant_ml_copy_string(entry, "predictedFeatureName");
        function->predicted_probabilities_name = revenant_ml_copy_string(entry, "predictedProbabilitiesName");
        function->input_count =
            read_feature_list(function->inputs, REVENANT_ML_MAX_FUNCTION_FEATURES, entry, "input");
        function->output_count =
            read_feature_list(function->outputs, REVENANT_ML_MAX_FUNCTION_FEATURES, entry, "output");
        model->function_count++;
    }
}

const revenant_ml_function *revenant_ml_model_function_at(const revenant_ml_model *model, size_t index)
{
    if (model == NULL || index >= model->function_count) {
        return NULL;
    }
    return &model->functions[index];
}

const revenant_ml_function *revenant_ml_model_function_named(const revenant_ml_model *model, const char *name)
{
    size_t index;
    if (model == NULL || name == NULL) {
        return NULL;
    }
    for (index = 0; index < model->function_count; index++) {
        if (model->functions[index].name != NULL && strcmp(model->functions[index].name, name) == 0) {
            return &model->functions[index];
        }
    }
    return NULL;
}

static void read_update_parameters(revenant_ml_model *model, const revenant_ml_node *kind_node)
{
    const revenant_ml_node *update = revenant_ml_get(kind_node, "updateParams");
    const revenant_ml_node *optimizer, *chosen;
    if (update == NULL) {
        return;
    }
    put_parameter(model, "epochs", revenant_ml_get(update, "epochs"));
    put_parameter(model, "shuffle", revenant_ml_get(update, "shuffle"));
    put_parameter(model, "seed", revenant_ml_get(update, "seed"));
    optimizer = revenant_ml_get(update, "optimizer");
    if (optimizer == NULL) {
        return;
    }
    chosen = revenant_ml_get(optimizer, "adamOptimizer");
    if (chosen != NULL) {
        put_parameter(model, "learningRate", revenant_ml_get(chosen, "learningRate"));
        put_parameter(model, "miniBatchSize", revenant_ml_get(chosen, "miniBatchSize"));
        put_parameter(model, "beta1", revenant_ml_get(chosen, "beta1"));
        put_parameter(model, "beta2", revenant_ml_get(chosen, "beta2"));
        put_parameter(model, "eps", revenant_ml_get(chosen, "eps"));
        return;
    }
    chosen = revenant_ml_get(optimizer, "sgdOptimizer");
    if (chosen != NULL) {
        put_parameter(model, "learningRate", revenant_ml_get(chosen, "learningRate"));
        put_parameter(model, "miniBatchSize", revenant_ml_get(chosen, "miniBatchSize"));
        put_parameter(model, "momentum", revenant_ml_get(chosen, "momentum"));
    }
}

int revenant_ml_model_from_node(revenant_ml_model *model, const revenant_ml_node *document, const char *bundle,
                              char *error, size_t error_size)
{
    const revenant_ml_node *description, *kind_node, *metadata;
    const char *kind_field = revenant_ml_node_kind_name(document);
    int index;

    memset(model, 0, sizeof *model);
    model->kind = REVENANT_ML_KIND_NONE;
    model->borrowed = 1;
    model->bundle = bundle != NULL ? strdup(bundle) : NULL;
    model->document = *document;
    model->specification_version = revenant_ml_int(revenant_ml_get(document, "specificationVersion"), 0);
    kind_node = kind_field != NULL ? revenant_ml_get(document, kind_field) : NULL;
    if (kind_node == NULL) {
        snprintf(error, error_size, "the model names no kind of model the specification declares, so there is nothing to run");
        return 0;
    }
    for (index = 0; MODEL_KINDS[index].field != NULL; index++) {
        if (strcmp(MODEL_KINDS[index].field, kind_field) == 0) {
            model->kind = MODEL_KINDS[index].kind;
            break;
        }
    }
    description = revenant_ml_get(document, "description");
    if (description == NULL) {
        snprintf(error, error_size, "the model has no description, so it names no features");
        return 0;
    }
    model->input_count = read_feature_list(model->inputs, REVENANT_ML_MAX_FEATURES, description, "input");
    model->output_count = read_feature_list(model->outputs, REVENANT_ML_MAX_FEATURES, description, "output");
    model->predicted_feature_name = revenant_ml_copy_string(description, "predictedFeatureName");
    model->predicted_probabilities_name = revenant_ml_copy_string(description, "predictedProbabilitiesName");
    model->short_description = revenant_ml_copy_string(description, "shortDescription");
    metadata = revenant_ml_get(description, "metadata");
    if (metadata != NULL) {
        model->author = revenant_ml_copy_string(metadata, "author");
        model->license = revenant_ml_copy_string(metadata, "license");
        model->version = revenant_ml_copy_string(metadata, "versionString");
        if (model->short_description == NULL) {
            model->short_description = revenant_ml_copy_string(metadata, "shortDescription");
        }
    }
    model->training_input_count =
        read_feature_list(model->training_inputs, REVENANT_ML_MAX_FEATURES, description, "trainingInput");
    model->is_updatable = revenant_ml_int(revenant_ml_get(document, "isUpdatable"), 0) != 0;
    if (metadata != NULL) {
        size_t total = revenant_ml_count_field(metadata, "userDefined"), index;
        if (total > 0) {
            model->user_defined_keys = (char **)calloc(total, sizeof *model->user_defined_keys);
            model->user_defined_values = (char **)calloc(total, sizeof *model->user_defined_values);
            if (model->user_defined_keys != NULL && model->user_defined_values != NULL) {
                for (index = 0; index < total; index++) {
                    const revenant_ml_node *entry =
                        revenant_ml_node_at_field(metadata, "userDefined", index);
                    model->user_defined_keys[index] = revenant_ml_copy_string(entry, "key");
                    model->user_defined_values[index] = revenant_ml_copy_string(entry, "value");
                }
                model->user_defined_count = total;
            } else {
                free(model->user_defined_keys);
                free(model->user_defined_values);
                model->user_defined_keys = model->user_defined_values = NULL;
            }
        }
    }
    read_update_parameters(model, kind_node);
    read_functions(model, description);
    if (revenant_ml_kind_is_classifier(model->kind)) {
        read_class_labels(model, kind_node);
    }
    return 1;
}

int revenant_ml_model_read_data(revenant_ml_model *model, const void *bytes, size_t length, char *error,
                              size_t error_size)
{
    revenant_ml_node document;
    char *copy;

    memset(model, 0, sizeof *model);
    if (bytes == NULL || length == 0) {
        snprintf(error, error_size, "there were no bytes to read a model out of");
        return 0;
    }
    copy = (char *)malloc(length);
    if (copy == NULL) {
        snprintf(error, error_size, "the model's %lu bytes had nowhere to be copied to",
                 (unsigned long)length);
        return 0;
    }
    memcpy(copy, bytes, length);
    if (!revenant_ml_read(&document, copy, length, "CoreML.Specification.Model")) {
        snprintf(error, error_size,
                 "the data is not a Core ML model: it is not a message of the model type the specification declares");
        free(copy);
        return 0;
    }
    model->bytes = copy;
    if (!revenant_ml_model_from_node(model, &document, NULL, error, error_size)) {
        revenant_ml_free(&document);
        free(copy);
        snprintf(error, error_size, "the model in memory cannot be run: %s", error);
        return 0;
    }
    model->document = document;
    model->borrowed = 0;
    return 1;
}

int revenant_ml_model_read(revenant_ml_model *model, const char *path, char *error, size_t error_size)
{
    char container[1024];
    char *bytes;
    size_t length = 0;
    revenant_ml_node document;

    memset(model, 0, sizeof *model);
    if (path == NULL) {
        snprintf(error, error_size, "no path to a model");
        return 0;
    }
    if (is_directory(path)) {
        join(container, sizeof container, path, "coremldata.bin");
        if (!file_exists(container)) {
            snprintf(error, error_size,
                     "the bundle at %s holds no coremldata.bin, which is where a compiled model keeps its program",
                     path);
            return 0;
        }
    } else {
        snprintf(container, sizeof container, "%s", path);
    }
    bytes = slurp(container, &length);
    if (bytes == NULL) {
        snprintf(error, error_size, "the model at %s could not be read", container);
        return 0;
    }
    if (length == 0 || !revenant_ml_read(&document, bytes, length, "CoreML.Specification.Model")) {
        snprintf(error, error_size,
                 "the file at %s is not a Core ML model: it is not a message of the model type the specification declares",
                 container);
        free(bytes);
        return 0;
    }
    model->bytes = bytes;
    model->borrowed = 0;
    if (is_directory(path)) {
        model->bundle = strdup(path);
    }
    if (!revenant_ml_model_from_node(model, &document, model->bundle, error, error_size)) {
        revenant_ml_model_release(model);
        snprintf(error, error_size, "the model at %s cannot be run: %s", container, error);
        return 0;
    }
    model->document = document;
    model->borrowed = 0;
    return 1;
}

void revenant_ml_model_release(revenant_ml_model *model)
{
    size_t index;
    if (model == NULL) {
        return;
    }
    for (index = 0; index < model->input_count; index++) {
        release_feature(&model->inputs[index]);
    }
    for (index = 0; index < model->output_count; index++) {
        release_feature(&model->outputs[index]);
    }
    for (index = 0; index < model->training_input_count; index++) {
        release_feature(&model->training_inputs[index]);
    }
    for (index = 0; index < model->parameter_count; index++) {
        free(model->parameters[index].key);
        free(model->parameters[index].string);
    }
    for (index = 0; index < model->function_count; index++) {
        size_t axis;
        free(model->functions[index].name);
        free(model->functions[index].predicted_feature_name);
        free(model->functions[index].predicted_probabilities_name);
        for (axis = 0; axis < model->functions[index].input_count; axis++) {
            release_feature(&model->functions[index].inputs[axis]);
        }
        for (axis = 0; axis < model->functions[index].output_count; axis++) {
            release_feature(&model->functions[index].outputs[axis]);
        }
    }
    for (index = 0; index < model->user_defined_count; index++) {
        free(model->user_defined_keys[index]);
        free(model->user_defined_values[index]);
    }
    free(model->user_defined_keys);
    free(model->user_defined_values);
    for (index = 0; index < model->class_label_count; index++) {
        free(model->class_labels[index]);
    }
    free(model->class_labels);
    free(model->predicted_feature_name);
    free(model->predicted_probabilities_name);
    free(model->author);
    free(model->license);
    free(model->short_description);
    free(model->version);
    free(model->bundle);
    if (!model->borrowed) {
        revenant_ml_free(&model->document);
        free(model->bytes);
    }
    memset(model, 0, sizeof *model);
}
