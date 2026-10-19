/* A Core ML model read from its container: which kind of model it is, what its features are,
 * and the set of values a prediction is made from and answered in.
 * CharonMLModel.h says what it is for; this is the reading of it.
 *
 * Every field is read through the specification (CharonMLProto.h), so a model this port runs
 * is the model its container describes. Nothing here interprets a layer or a weight: it is
 * the document, its description and its class labels, and nothing more.
 */
#include "CharonMLModel.h"
#include "CharonMLValue.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

/* The cases of the specification's Type oneof, and the kind each is read as. A name the
 * specification has and this list does not is CHARON_ML_KIND_OTHER: the model loads, and the
 * interpreter refuses it with a message naming the kind, rather than the load being refused
 * for a kind that is real. */
static const struct {
    const char *field;
    charon_ml_model_kind kind;
} MODEL_KINDS[] = {
    {"pipelineClassifier", CHARON_ML_KIND_PIPELINE_CLASSIFIER},
    {"pipelineRegressor", CHARON_ML_KIND_PIPELINE_REGRESSOR},
    {"pipeline", CHARON_ML_KIND_PIPELINE},
    {"neuralNetworkClassifier", CHARON_ML_KIND_NEURAL_NETWORK_CLASSIFIER},
    {"neuralNetworkRegressor", CHARON_ML_KIND_NEURAL_NETWORK_REGRESSOR},
    {"neuralNetwork", CHARON_ML_KIND_NEURAL_NETWORK},
    {"treeEnsembleClassifier", CHARON_ML_KIND_TREE_ENSEMBLE_CLASSIFIER},
    {"treeEnsembleRegressor", CHARON_ML_KIND_TREE_ENSEMBLE_REGRESSOR},
    {"glmClassifier", CHARON_ML_KIND_GLM_CLASSIFIER},
    {"glmRegressor", CHARON_ML_KIND_GLM_REGRESSOR},
    {"supportVectorClassifier", CHARON_ML_KIND_SVM_CLASSIFIER},
    {"supportVectorRegressor", CHARON_ML_KIND_SVM_REGRESSOR},
    {"kNearestNeighborsClassifier", CHARON_ML_KIND_KNN_CLASSIFIER},
    {"itemSimilarityRecommender", CHARON_ML_KIND_ITEM_SIMILARITY},
    {"scaler", CHARON_ML_KIND_SCALER},
    {"imputer", CHARON_ML_KIND_IMPUTER},
    {"normalizer", CHARON_ML_KIND_NORMALIZER},
    {"oneHotEncoder", CHARON_ML_KIND_ONE_HOT_ENCODER},
    {"dictVectorizer", CHARON_ML_KIND_DICT_VECTORIZER},
    {"featureVectorizer", CHARON_ML_KIND_FEATURE_VECTORIZER},
    {"categoricalMapping", CHARON_ML_KIND_CATEGORICAL_MAPPING},
    {"arrayFeatureExtractor", CHARON_ML_KIND_ARRAY_FEATURE_EXTRACTOR},
    {"nonMaximumSuppression", CHARON_ML_KIND_NON_MAXIMUM_SUPPRESSION},
    {"identity", CHARON_ML_KIND_IDENTITY},
    {"mlProgram", CHARON_ML_KIND_MIL_PROGRAM},
    {NULL, CHARON_ML_KIND_NONE}};

const char *charon_ml_kind_name(charon_ml_model_kind kind)
{
    int index;
    for (index = 0; MODEL_KINDS[index].field != NULL; index++) {
        if (MODEL_KINDS[index].kind == kind) {
            return MODEL_KINDS[index].field;
        }
    }
    return kind == CHARON_ML_KIND_NONE ? "none" : "other";
}

int charon_ml_kind_is_classifier(charon_ml_model_kind kind)
{
    switch (kind) {
    case CHARON_ML_KIND_PIPELINE_CLASSIFIER:
    case CHARON_ML_KIND_NEURAL_NETWORK_CLASSIFIER:
    case CHARON_ML_KIND_TREE_ENSEMBLE_CLASSIFIER:
    case CHARON_ML_KIND_GLM_CLASSIFIER:
    case CHARON_ML_KIND_SVM_CLASSIFIER:
    case CHARON_ML_KIND_KNN_CLASSIFIER:
        return 1;
    default:
        return 0;
    }
}

const char *charon_ml_feature_type_name(charon_ml_feature_type type)
{
    switch (type) {
    case CHARON_ML_FEATURE_INT64:
        return "int64";
    case CHARON_ML_FEATURE_DOUBLE:
        return "double";
    case CHARON_ML_FEATURE_STRING:
        return "string";
    case CHARON_ML_FEATURE_IMAGE:
        return "image";
    case CHARON_ML_FEATURE_MULTI_ARRAY:
        return "multiArray";
    case CHARON_ML_FEATURE_DICTIONARY:
        return "dictionary";
    case CHARON_ML_FEATURE_SEQUENCE:
        return "sequence";
    case CHARON_ML_FEATURE_STATE:
        return "state";
    default:
        return "none";
    }
}

char *charon_ml_copy_string(const charon_ml_node *node, const char *field)
{
    const charon_ml_node *value = charon_ml_get(node, field);
    char *copy;
    if (value == NULL || value->field == NULL ||
        (value->field->kind != CHARON_ML_KIND_STRING && value->field->kind != CHARON_ML_KIND_BYTES)) {
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

/* --- the description of one feature ----------------------------------------------------------- */

static void read_feature(charon_ml_feature *feature, const charon_ml_node *described)
{
    const charon_ml_node *type;
    int index;

    memset(feature, 0, sizeof *feature);
    feature->name = charon_ml_copy_string(described, "name");
    feature->short_description = charon_ml_copy_string(described, "shortDescription");
    feature->image_color_space = CHARON_ML_COLOR_INVALID;
    feature->image_width_range = feature->image_height_range = CHARON_ML_FLEXIBLE;
    for (index = 0; index < 8; index++) {
        feature->shape[index] = CHARON_ML_FLEXIBLE;
        feature->shape_range[index][0] = 0;
        feature->shape_range[index][1] = CHARON_ML_FLEXIBLE;
    }
    type = charon_ml_get(described, "type");
    if (type == NULL) {
        return;
    }
    /* The FeatureType oneof: which case is in the document is which field the node carries, so
     * the kind is asked of the field rather than matched by name against a list. */
    for (index = 0; index < (int)charon_ml_count(type); index++) {
        const charon_ml_node *entry = charon_ml_at(type, index);
        const char *name = entry->field->name;
        const charon_ml_node *body = entry;
        if (strcmp(name, "isOptional") == 0) {
            feature->optional = charon_ml_int(entry, 0) != 0;
            continue;
        }
        if (strcmp(name, "int64Type") == 0) {
            feature->type = CHARON_ML_FEATURE_INT64;
        } else if (strcmp(name, "doubleType") == 0) {
            feature->type = CHARON_ML_FEATURE_DOUBLE;
        } else if (strcmp(name, "stringType") == 0) {
            feature->type = CHARON_ML_FEATURE_STRING;
        } else if (strcmp(name, "imageType") == 0) {
            feature->type = CHARON_ML_FEATURE_IMAGE;
        } else if (strcmp(name, "multiArrayType") == 0) {
            feature->type = CHARON_ML_FEATURE_MULTI_ARRAY;
        } else if (strcmp(name, "dictionaryType") == 0) {
            feature->type = CHARON_ML_FEATURE_DICTIONARY;
        } else if (strcmp(name, "sequenceType") == 0) {
            feature->type = CHARON_ML_FEATURE_SEQUENCE;
            /* A sequence's oneof holds what its elements are -- a whole number or a string --
             * and the size range beside it is how many of them there may be. */
            {
                size_t element;
                for (element = 0; element < charon_ml_count(body); element++) {
                    const charon_ml_node *entry = charon_ml_at(body, element);
                    const char *which = entry->field != NULL ? entry->field->name : "";
                    if (strcmp(which, "int64Type") == 0) {
                        feature->element_type = CHARON_ML_FEATURE_INT64;
                    } else if (strcmp(which, "stringType") == 0) {
                        feature->element_type = CHARON_ML_FEATURE_STRING;
                    }
                }
            }
            {
                const charon_ml_node *range = charon_ml_get(body, "sizeRange");
                if (range != NULL) {
                    feature->has_count_range = 1;
                    feature->count_lower = charon_ml_int(charon_ml_get(range, "lowerBound"), 0);
                    feature->count_upper =
                        charon_ml_int(charon_ml_get(range, "upperBound"), CHARON_ML_FLEXIBLE);
                }
            }
        } else if (strcmp(name, "stateType") == 0) {
            feature->type = CHARON_ML_FEATURE_STATE;
        } else {
            continue;
        }
        if (feature->type == CHARON_ML_FEATURE_IMAGE) {
            const charon_ml_node *range = charon_ml_get(body, "imageSizeRange");
            const charon_ml_node *sizes = charon_ml_get(body, "enumeratedSizes");
            feature->image_width = charon_ml_int(charon_ml_get(body, "width"), 0);
            feature->image_height = charon_ml_int(charon_ml_get(body, "height"), 0);
            feature->image_color_space = charon_ml_int(charon_ml_get(body, "colorSpace"), CHARON_ML_COLOR_INVALID);
            if (range == NULL && feature->image_width > 0 && feature->image_height > 0) {
                /* A FIXED size, which the specification writes as ImageFeatureType.width/.height
                 * and beside no range. The ranges stay FLEXIBLE above, which is right for a
                 * dimension with no upper bound and wrong here: a size that is fixed has no range at
                 * all, and leaving FLEXIBLE in made every fixed-size image look like a range whose
                 * lower bound is -1. Measured against this host's own Core ML, which reports such a
                 * feature as the enumerated kind with the one size in it (facts/CoreML/CoreML.md). */
                feature->image_width_range = 0;
                feature->image_height_range = 0;
            }
            if (range != NULL) {
                const charon_ml_node *width = charon_ml_get(range, "widthRange");
                const charon_ml_node *height = charon_ml_get(range, "heightRange");
                feature->image_width_range = charon_ml_int(charon_ml_get(width, "lowerBound"), 0);
                feature->image_width = charon_ml_int(charon_ml_get(width, "upperBound"), feature->image_width);
                feature->image_height_range = charon_ml_int(charon_ml_get(height, "lowerBound"), 0);
                feature->image_height = charon_ml_int(charon_ml_get(height, "upperBound"), feature->image_height);
            }
            /* The set of sizes, which is the third way a model says what size an image is: the
             * specification writes it beside the range, and it is a set rather than a range
             * because the sizes a model will take are named ones -- the crops of a detection
             * model, each of which the caller has to be able to ask for by number. */
            if (sizes != NULL) {
                size_t total = charon_ml_count_field(sizes, "sizes");
                if (total > 0) {
                    feature->enumerated_widths = (int64_t *)calloc(total, sizeof *feature->enumerated_widths);
                    feature->enumerated_heights = (int64_t *)calloc(total, sizeof *feature->enumerated_heights);
                    if (feature->enumerated_widths != NULL && feature->enumerated_heights != NULL) {
                        for (index = 0; index < (int)total; index++) {
                            const charon_ml_node *size =
                                charon_ml_node_at_field(sizes, "sizes", (size_t)index);
                            feature->enumerated_widths[index] =
                                charon_ml_int(charon_ml_get(size, "width"), 0);
                            feature->enumerated_heights[index] =
                                charon_ml_int(charon_ml_get(size, "height"), 0);
                        }
                        feature->enumerated_count = total;
                    } else {
                        free(feature->enumerated_widths);
                        free(feature->enumerated_heights);
                        feature->enumerated_widths = feature->enumerated_heights = NULL;
                    }
                }
            }
        } else if (feature->type == CHARON_ML_FEATURE_MULTI_ARRAY) {
            const charon_ml_node *range = charon_ml_get(body, "shapeRange");
            const charon_ml_node *shapes = charon_ml_get(body, "enumeratedShapes");
            feature->data_type = charon_ml_int(charon_ml_get(body, "dataType"), CHARON_ML_ARRAY_INVALID);
            feature->rank = (int)charon_ml_count_field(body, "shape");
            if (feature->rank > 8) {
                feature->rank = 8;
            }
            for (index = 0; index < feature->rank; index++) {
                feature->shape[index] = charon_ml_int_at(body, "shape", (size_t)index, CHARON_ML_FLEXIBLE);
            }
            if (range != NULL) {
                size_t sizes = charon_ml_count_field(range, "sizeRanges");
                if (sizes > 0) {
                    feature->has_shape_range = 1;
                    feature->shape_kind = CHARON_ML_SHAPE_RANGE;
                    for (index = 0; index < (int)sizes && index < 8; index++) {
                        const charon_ml_node *bounds = charon_ml_node_at_field(range, "sizeRanges", (size_t)index);
                        /* SizeRange's lower bound is unsigned and its upper bound is signed,
                         * and -1 is the specification's "no upper bound": a dimension of no
                         * fixed length, which is flexible rather than absent. */
                        feature->shape_range[index][0] = charon_ml_int(charon_ml_get(bounds, "lowerBound"), 0);
                        feature->shape_range[index][1] = charon_ml_int(charon_ml_get(bounds, "upperBound"), CHARON_ML_FLEXIBLE);
                        if (feature->shape[index] == 0) {
                            feature->shape[index] = feature->shape_range[index][1];
                        }
                    }
                }
            }
            if (shapes != NULL) {
                size_t total = charon_ml_count_field(shapes, "shapes");
                if (total > 0) {
                    feature->enumerated_ranks = (int *)calloc(total, sizeof *feature->enumerated_ranks);
                    feature->enumerated_shapes =
                        (int64_t (*)[CHARON_ML_MAX_RANK])calloc(total, sizeof *feature->enumerated_shapes);
                    if (feature->enumerated_ranks != NULL && feature->enumerated_shapes != NULL) {
                        for (index = 0; index < (int)total; index++) {
                            const charon_ml_node *entry =
                                charon_ml_node_at_field(shapes, "shapes", (size_t)index);
                            size_t dimensions = charon_ml_count_field(entry, "shape"), axis;
                            if (dimensions > CHARON_ML_MAX_RANK) {
                                dimensions = CHARON_ML_MAX_RANK;
                            }
                            feature->enumerated_ranks[index] = (int)dimensions;
                            for (axis = 0; axis < dimensions; axis++) {
                                feature->enumerated_shapes[index][axis] =
                                    charon_ml_int_at(entry, "shape", axis, CHARON_ML_FLEXIBLE);
                            }
                        }
                        feature->enumerated_count = total;
                        /* A set of shapes and a range of them are the two the specification
                         * writes in the same oneof, so a document that carries both names both;
                         * the set is the one a caller has to be told about, and it is the one
                         * that decides. */
                        if (feature->shape_kind != CHARON_ML_SHAPE_RANGE) {
                            feature->shape_kind = CHARON_ML_SHAPE_ENUMERATED;
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

static void release_feature(charon_ml_feature *feature)
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

static size_t read_feature_list(charon_ml_feature *into, size_t room, const charon_ml_node *description,
                                const char *field)
{
    size_t total = charon_ml_count_field(description, field), index, kept = 0;
    for (index = 0; index < total && kept < room; index++) {
        read_feature(&into[kept], charon_ml_node_at_field(description, field, index));
        kept++;
    }
    return kept;
}

/* --- the class labels ------------------------------------------------------------------------- */

/* A classifier's labels live in the oneof of the model kind, in a StringVector or an
 * Int64Vector, so which vector is asked of the oneof rather than by a name. */
static size_t read_class_labels(charon_ml_model *model, const charon_ml_node *kind_node)
{
    const charon_ml_node *labels = charon_ml_oneof(kind_node, "stringClassLabels");
    size_t count, index;
    if (labels == NULL) {
        labels = charon_ml_oneof(kind_node, "int64ClassLabels");
        model->class_labels_are_numbers = 1;
    }
    if (labels == NULL) {
        model->class_labels_are_numbers = 0;
        return 0;
    }
    count = charon_ml_count_field(labels, "vector");
    if (count == 0) {
        return 0;
    }
    model->class_labels = (char **)calloc(count, sizeof *model->class_labels);
    if (model->class_labels == NULL) {
        return 0;
    }
    for (index = 0; index < count; index++) {
        const charon_ml_node *entry = charon_ml_node_at_field(labels, "vector", index);
        if (model->class_labels_are_numbers) {
            /* A whole number is written as a number on the wire and has no text to copy, so it
             * is formatted into the same string the labels are held in and read back as a
             * number by the Objective-C half: one place holds them, and the flag says which kind
             * of value each string is. */
            char text[32];
            snprintf(text, sizeof text, "%lld",
                     (long long)(entry != NULL ? entry->value.integer : 0));
            model->class_labels[index] = charon_ml_strndup(text, strlen(text));
        } else if (entry != NULL && entry->value.text.length < 4096) {
            model->class_labels[index] = charon_ml_strndup(entry->value.text.bytes, entry->value.text.length);
        } else {
            model->class_labels[index] = charon_ml_strndup("", 0);
        }
    }
    model->class_label_count = count;
    return count;
}

/* --- reading the container --------------------------------------------------------------------- */

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

/* The field of the Type oneof this document carries. The kind is asked of the document rather
 * than matched against a list of names at each call site, so the interpreter and the errors
 * read the same one. */
const char *charon_ml_node_kind_name(const charon_ml_node *document)
{
    int index;
    for (index = 0; MODEL_KINDS[index].field != NULL; index++) {
        if (charon_ml_get(document, MODEL_KINDS[index].field) != NULL) {
            return MODEL_KINDS[index].field;
        }
    }
    return NULL;
}

/* --- the model's own parameters ------------------------------------------------------------- */

/* One parameter out of the specification's own update parameters. A DoubleParameter and an
 * Int64Parameter both carry a default and a range, a BoolParameter a default and nothing else,
 * and a StringParameter a default string; the key is not in the parameter at all but in the
 * field the parameter was reached by, which is why the name is passed in rather than read. */
static void read_parameter(charon_ml_parameter *parameter, const char *key, const charon_ml_node *node)
{
    const charon_ml_node *range, *set;
    memset(parameter, 0, sizeof *parameter);
    parameter->key = strdup(key);
    if (strcmp(key, "shuffle") == 0) {
        parameter->type = CHARON_ML_FEATURE_INT64;
        parameter->number = charon_ml_int(charon_ml_get(node, "defaultValue"), 0);
        return;
    }
    if (strcmp(key, "seed") == 0 || strcmp(key, "epochs") == 0 ||
        strcmp(key, "miniBatchSize") == 0 || strcmp(key, "numberOfNeighbors") == 0) {
        parameter->type = CHARON_ML_FEATURE_INT64;
        parameter->number = (double)charon_ml_int(charon_ml_get(node, "defaultValue"), 0);
    } else {
        parameter->type = CHARON_ML_FEATURE_DOUBLE;
        parameter->number = charon_ml_double(charon_ml_get(node, "defaultValue"), 0.0);
    }
    range = charon_ml_get(node, "range");
    if (range != NULL) {
        parameter->has_range = 1;
        parameter->range_min = charon_ml_double(charon_ml_get(range, "minValue"), 0.0);
        parameter->range_max = charon_ml_double(charon_ml_get(range, "maxValue"), 0.0);
    }
    set = charon_ml_get(node, "set");
    if (set != NULL) {
        size_t total = charon_ml_count_field(set, "values"), index;
        if (total > CHARON_ML_MAX_PARAMETER_SET) {
            total = CHARON_ML_MAX_PARAMETER_SET;
        }
        for (index = 0; index < total; index++) {
            parameter->set_values[index] = charon_ml_int_at(set, "values", index, 0);
        }
        parameter->set_count = total;
        parameter->has_set = total > 0;
    }
}

static void put_parameter(charon_ml_model *model, const char *key, const charon_ml_node *node)
{
    if (node == NULL || model->parameter_count >= CHARON_ML_MAX_PARAMETERS) {
        return;
    }
    read_parameter(&model->parameters[model->parameter_count], key, node);
    if (model->parameters[model->parameter_count].key != NULL) {
        model->parameter_count++;
    }
}

/* The named functions of a model that has them. Each is a description of its own -- its own
 * name, its own inputs and its own outputs -- and the specification's own list is read in order,
 * so a caller asking for the third function of a model gets the third one it wrote. */
static void read_functions(charon_ml_model *model, const charon_ml_node *description)
{
    size_t total = charon_ml_count_field(description, "functions"), index;
    for (index = 0; index < total && model->function_count < CHARON_ML_MAX_FUNCTIONS; index++) {
        const charon_ml_node *entry = charon_ml_node_at_field(description, "functions", index);
        charon_ml_function *function = &model->functions[model->function_count];
        memset(function, 0, sizeof *function);
        function->name = charon_ml_copy_string(entry, "name");
        function->predicted_feature_name = charon_ml_copy_string(entry, "predictedFeatureName");
        function->predicted_probabilities_name = charon_ml_copy_string(entry, "predictedProbabilitiesName");
        function->input_count =
            read_feature_list(function->inputs, CHARON_ML_MAX_FUNCTION_FEATURES, entry, "input");
        function->output_count =
            read_feature_list(function->outputs, CHARON_ML_MAX_FUNCTION_FEATURES, entry, "output");
        model->function_count++;
    }
}

const charon_ml_function *charon_ml_model_function_at(const charon_ml_model *model, size_t index)
{
    if (model == NULL || index >= model->function_count) {
        return NULL;
    }
    return &model->functions[index];
}

const charon_ml_function *charon_ml_model_function_named(const charon_ml_model *model, const char *name)
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

/* The parameters of the model itself, which the specification writes beside the optimizer: the
 * number of epochs a training runs for, whether it shuffles, the seed it starts from, and -- for
 * a nearest neighbours model -- how many neighbours it looks at. A model that is not updatable
 * carries none of them, and a model whose container was written without them carries none
 * either, which is the same answer. */
static void read_update_parameters(charon_ml_model *model, const charon_ml_node *kind_node)
{
    const charon_ml_node *update = charon_ml_get(kind_node, "updateParams");
    const charon_ml_node *optimizer, *chosen;
    if (update == NULL) {
        return;
    }
    put_parameter(model, "epochs", charon_ml_get(update, "epochs"));
    put_parameter(model, "shuffle", charon_ml_get(update, "shuffle"));
    put_parameter(model, "seed", charon_ml_get(update, "seed"));
    optimizer = charon_ml_get(update, "optimizer");
    if (optimizer == NULL) {
        return;
    }
    /* The optimizer is one of two shapes, and which one decides which parameters exist: the
     * adaptive one has no momentum and two betas, the plain one the other way round. Both name
     * their learning rate and their batch the same way. */
    chosen = charon_ml_get(optimizer, "adamOptimizer");
    if (chosen != NULL) {
        put_parameter(model, "learningRate", charon_ml_get(chosen, "learningRate"));
        put_parameter(model, "miniBatchSize", charon_ml_get(chosen, "miniBatchSize"));
        put_parameter(model, "beta1", charon_ml_get(chosen, "beta1"));
        put_parameter(model, "beta2", charon_ml_get(chosen, "beta2"));
        put_parameter(model, "eps", charon_ml_get(chosen, "eps"));
        return;
    }
    chosen = charon_ml_get(optimizer, "sgdOptimizer");
    if (chosen != NULL) {
        put_parameter(model, "learningRate", charon_ml_get(chosen, "learningRate"));
        put_parameter(model, "miniBatchSize", charon_ml_get(chosen, "miniBatchSize"));
        put_parameter(model, "momentum", charon_ml_get(chosen, "momentum"));
    }
}

int charon_ml_model_from_node(charon_ml_model *model, const charon_ml_node *document, const char *bundle,
                              char *error, size_t error_size)
{
    const charon_ml_node *description, *kind_node, *metadata;
    const char *kind_field = charon_ml_node_kind_name(document);
    int index;

    memset(model, 0, sizeof *model);
    model->kind = CHARON_ML_KIND_NONE;
    model->borrowed = 1;
    model->bundle = bundle != NULL ? strdup(bundle) : NULL;
    model->document = *document;
    model->specification_version = charon_ml_int(charon_ml_get(document, "specificationVersion"), 0);
    kind_node = kind_field != NULL ? charon_ml_get(document, kind_field) : NULL;
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
    description = charon_ml_get(document, "description");
    if (description == NULL) {
        snprintf(error, error_size, "the model has no description, so it names no features");
        return 0;
    }
    model->input_count = read_feature_list(model->inputs, CHARON_ML_MAX_FEATURES, description, "input");
    model->output_count = read_feature_list(model->outputs, CHARON_ML_MAX_FEATURES, description, "output");
    model->predicted_feature_name = charon_ml_copy_string(description, "predictedFeatureName");
    model->predicted_probabilities_name = charon_ml_copy_string(description, "predictedProbabilitiesName");
    model->short_description = charon_ml_copy_string(description, "shortDescription");
    metadata = charon_ml_get(description, "metadata");
    if (metadata != NULL) {
        model->author = charon_ml_copy_string(metadata, "author");
        model->license = charon_ml_copy_string(metadata, "license");
        model->version = charon_ml_copy_string(metadata, "versionString");
        if (model->short_description == NULL) {
            model->short_description = charon_ml_copy_string(metadata, "shortDescription");
        }
    }
    model->training_input_count =
        read_feature_list(model->training_inputs, CHARON_ML_MAX_FEATURES, description, "trainingInput");
    model->is_updatable = charon_ml_int(charon_ml_get(document, "isUpdatable"), 0) != 0;
    if (metadata != NULL) {
        size_t total = charon_ml_count_field(metadata, "userDefined"), index;
        if (total > 0) {
            model->user_defined_keys = (char **)calloc(total, sizeof *model->user_defined_keys);
            model->user_defined_values = (char **)calloc(total, sizeof *model->user_defined_values);
            if (model->user_defined_keys != NULL && model->user_defined_values != NULL) {
                for (index = 0; index < total; index++) {
                    const charon_ml_node *entry =
                        charon_ml_node_at_field(metadata, "userDefined", index);
                    model->user_defined_keys[index] = charon_ml_copy_string(entry, "key");
                    model->user_defined_values[index] = charon_ml_copy_string(entry, "value");
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
    if (charon_ml_kind_is_classifier(model->kind)) {
        read_class_labels(model, kind_node);
    }
    return 1;
}

/* The same read out of bytes the caller already has, which is what a model built in memory is:
 * an asset holds a container that was never a file, and the model it makes is read out of the
 * same message a file would have held. The bytes are copied, because the model keeps its own
 * for as long as it lives: a node is a window into them, and a node that outlived a buffer the
 * caller had freed would read memory that has moved. */
int charon_ml_model_read_data(charon_ml_model *model, const void *bytes, size_t length, char *error,
                              size_t error_size)
{
    charon_ml_node document;
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
    if (!charon_ml_read(&document, copy, length, "CoreML.Specification.Model")) {
        snprintf(error, error_size,
                 "the data is not a Core ML model: it is not a message of the model type the specification declares");
        free(copy);
        return 0;
    }
    model->bytes = copy;
    if (!charon_ml_model_from_node(model, &document, NULL, error, error_size)) {
        charon_ml_free(&document);
        free(copy);
        snprintf(error, error_size, "the model in memory cannot be run: %s", error);
        return 0;
    }
    model->document = document;
    model->borrowed = 0;
    return 1;
}

int charon_ml_model_read(charon_ml_model *model, const char *path, char *error, size_t error_size)
{
    char container[1024];
    char *bytes;
    size_t length = 0;
    charon_ml_node document;

    memset(model, 0, sizeof *model);
    if (path == NULL) {
        snprintf(error, error_size, "no path to a model");
        return 0;
    }
    if (is_directory(path)) {
        /* A compiled model is a bundle, and its program is the coremldata.bin inside it. A
         * bundle that does not hold one is not a model this port can read, and the error says
         * so rather than reading whatever file is there. */
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
    if (length == 0 || !charon_ml_read(&document, bytes, length, "CoreML.Specification.Model")) {
        snprintf(error, error_size,
                 "the file at %s is not a Core ML model: it is not a message of the model type the specification declares",
                 container);
        free(bytes);
        return 0;
    }
    /* The buffer becomes the model's own: every node of the document is a window into it, so
     * the model frees the two together and a node never outlives the bytes it points into. */
    model->bytes = bytes;
    model->borrowed = 0;
    if (is_directory(path)) {
        model->bundle = strdup(path);
    }
    if (!charon_ml_model_from_node(model, &document, model->bundle, error, error_size)) {
        charon_ml_model_release(model);
        snprintf(error, error_size, "the model at %s cannot be run: %s", container, error);
        return 0;
    }
    model->document = document;
    model->borrowed = 0;
    return 1;
}

void charon_ml_model_release(charon_ml_model *model)
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
        charon_ml_free(&model->document);
        free(model->bytes);
    }
    memset(model, 0, sizeof *model);
}
