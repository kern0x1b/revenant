#include "RevenantMLPredict.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RevenantMLLayerKinds.h"
#include "RevenantMLLayers.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void revenant_ml_features_init(revenant_ml_features *features)
{
    memset(features, 0, sizeof *features);
}

void revenant_ml_features_release(revenant_ml_features *features)
{
    size_t index;
    for (index = 0; index < features->count; index++) {
        free(features->entries[index].name);
        revenant_ml_value_free(&features->entries[index].value);
    }
    memset(features, 0, sizeof *features);
}

int revenant_ml_features_put(revenant_ml_features *features, const char *name, revenant_ml_value value)
{
    size_t index;
    if (name == NULL) {
        revenant_ml_value_free(&value);
        return 0;
    }
    for (index = 0; index < features->count; index++) {
        if (strcmp(features->entries[index].name, name) == 0) {
            revenant_ml_value_free(&features->entries[index].value);
            features->entries[index].value = value;
            return 1;
        }
    }
    if (features->count >= REVENANT_ML_MAX_FEATURES) {
        revenant_ml_value_free(&value);
        return 0;
    }
    features->entries[features->count].name = strdup(name);
    features->entries[features->count].value = value;
    features->count++;
    return 1;
}

const revenant_ml_value *revenant_ml_features_get(const revenant_ml_features *features, const char *name)
{
    size_t index;
    if (name == NULL) {
        return NULL;
    }
    for (index = 0; index < features->count; index++) {
        if (strcmp(features->entries[index].name, name) == 0) {
            return &features->entries[index].value;
        }
    }
    return NULL;
}

int revenant_ml_features_remove(revenant_ml_features *features, const char *name)
{
    size_t index;
    for (index = 0; index < features->count; index++) {
        if (strcmp(features->entries[index].name, name) == 0) {
            free(features->entries[index].name);
            revenant_ml_value_free(&features->entries[index].value);
            memmove(&features->entries[index], &features->entries[index + 1],
                    (features->count - index - 1) * sizeof *features->entries);
            features->count--;
            return 1;
        }
    }
    return 0;
}

static int value_as_vector(const revenant_ml_value *value, double **out, size_t *count)
{
    double *numbers;
    size_t index;
    if (value == NULL) {
        return 0;
    }
    if (value->kind == REVENANT_ML_VALUE_NUMBER) {
        numbers = (double *)malloc(sizeof *numbers);
        if (numbers == NULL) {
            return 0;
        }
        numbers[0] = value->number;
        *out = numbers;
        *count = 1;
        return 1;
    }
    if (value->kind != REVENANT_ML_VALUE_ARRAY || value->array.count == 0) {
        return 0;
    }
    numbers = (double *)malloc(value->array.count * sizeof *numbers);
    if (numbers == NULL) {
        return 0;
    }
    for (index = 0; index < value->array.count; index++) {
        numbers[index] = revenant_ml_array_get(&value->array, (int64_t)index);
    }
    *out = numbers;
    *count = value->array.count;
    return 1;
}

static int inputs_as_vector(const revenant_ml_model *model, const revenant_ml_features *values, double **out,
                            size_t *count, char *error, size_t error_size)
{
    double *numbers = NULL;
    size_t total = 0, index;
    for (index = 0; index < model->input_count; index++) {
        const revenant_ml_value *value = revenant_ml_features_get(values, model->inputs[index].name);
        double *one = NULL;
        size_t one_count = 0, at;
        if (!value_as_vector(value, &one, &one_count)) {
            free(numbers);
            snprintf(error, error_size, "the input '%s' is %s, which this port cannot read as numbers",
                     model->inputs[index].name != NULL ? model->inputs[index].name : "(unnamed)",
                     value == NULL ? "not there" : revenant_ml_value_name(value->kind));
            return 0;
        }
        numbers = (double *)realloc(numbers, (total + one_count + 1) * sizeof *numbers);
        if (numbers == NULL) {
            free(one);
            free(numbers);
            return 0;
        }
        for (at = 0; at < one_count; at++) {
            numbers[total++] = one[at];
        }
        free(one);
    }
    *out = numbers;
    *count = total;
    return 1;
}

int revenant_ml_features_satisfy(const revenant_ml_model *model, const revenant_ml_features *values, char *missing,
                               size_t missing_size, char *mismatched, size_t mismatched_size)
{
    size_t index;
    if (missing != NULL && missing_size > 0) {
        missing[0] = 0;
    }
    if (mismatched != NULL && mismatched_size > 0) {
        mismatched[0] = 0;
    }
    for (index = 0; index < model->input_count; index++) {
        const revenant_ml_feature *described = &model->inputs[index];
        const revenant_ml_value *value = revenant_ml_features_get(values, described->name);
        int axis;
        if (value == NULL || value->kind == REVENANT_ML_VALUE_NONE) {
            if (described->optional) {
                continue;
            }
            if (missing != NULL && described->name != NULL) {
                snprintf(missing, missing_size, "%s", described->name);
            }
            return 0;
        }
        if (described->type == REVENANT_ML_FEATURE_MULTI_ARRAY) {
            if (value->kind == REVENANT_ML_VALUE_NUMBER) {
                continue;
            }
            if (value->kind != REVENANT_ML_VALUE_ARRAY) {
                goto mismatched;
            }
            for (axis = 0; axis < described->rank && axis < value->array.rank; axis++) {
                if (described->shape[axis] > 0 && described->shape[axis] != value->array.shape[axis]) {
                    goto mismatched;
                }
            }
            continue;
        }
        if (described->type == REVENANT_ML_FEATURE_IMAGE && value->kind == REVENANT_ML_VALUE_IMAGE) {
            continue;
        }
    mismatched:
        if (mismatched != NULL && described->name != NULL) {
            snprintf(mismatched, mismatched_size, "%s", described->name);
        }
        return 0;
    }
    return 1;
}

int revenant_ml_features_take_outputs(const revenant_ml_model *model, revenant_ml_features *inputs,
                                    revenant_ml_features *outputs)
{
    size_t index;
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        const revenant_ml_value *value;
        if (name == NULL) {
            continue;
        }
        value = revenant_ml_features_get(inputs, name);
        if (value == NULL) {
            return 0;
        }
        if (!revenant_ml_features_put(outputs, name, *value)) {
            return 0;
        }
        memset((void *)value, 0, sizeof *value);
        revenant_ml_features_remove(inputs, name);
    }
    return 1;
}

enum {
    REVENANT_ML_TREE_NO_TRANSFORM = 0,
    REVENANT_ML_TREE_SOFTMAX = 1,
    REVENANT_ML_TREE_LOGISTIC = 2,
    REVENANT_ML_TREE_SOFTMAX_WITH_ZERO_CLASS = 3
};

static double logistic(double x)
{
    return x >= 0.0 ? 1.0 / (1.0 + exp(-x)) : exp(x) / (1.0 + exp(x));
}

static double probit(double x)
{
    return 0.5 * (1.0 + erf(x / sqrt(2.0)));
}

static void softmax_over(double *values, size_t count)
{
    size_t index;
    double largest = -HUGE_VAL, total = 0.0;
    for (index = 0; index < count; index++) {
        if (values[index] > largest) {
            largest = values[index];
        }
    }
    for (index = 0; index < count; index++) {
        values[index] = exp(values[index] - largest);
        total += values[index];
    }
    if (total == 0.0) {
        for (index = 0; index < count; index++) {
            values[index] = 0.0;
        }
        return;
    }
    for (index = 0; index < count; index++) {
        values[index] /= total;
    }
}

static void apply_tree_transform(int transform, double *values, size_t count)
{
    size_t index;
    switch (transform) {
    case REVENANT_ML_TREE_SOFTMAX:
        softmax_over(values, count);
        break;
    case REVENANT_ML_TREE_LOGISTIC:
        for (index = 0; index < count; index++) {
            values[index] = logistic(values[index]);
        }
        break;
    case REVENANT_ML_TREE_SOFTMAX_WITH_ZERO_CLASS:
        if (count > 1) {
            softmax_over(values + 1, count - 1);
            values[0] = 0.0;
        }
        break;
    default:
        break;
    }
}

static void apply_glm_transform(int transform, double *values, size_t count)
{
    size_t index;
    switch (transform) {
    case 1:
        for (index = 0; index < count; index++) {
            values[index] = logistic(values[index]);
        }
        break;
    case 2:
        for (index = 0; index < count; index++) {
            values[index] = probit(values[index]);
        }
        break;
    default:
        break;
    }
}

static const revenant_ml_feature *model_feature_named(const revenant_ml_model *model, const char *name)
{
    size_t index;
    if (model == NULL || name == NULL) {
        return NULL;
    }
    for (index = 0; index < model->output_count; index++) {
        if (model->outputs[index].name != NULL && strcmp(model->outputs[index].name, name) == 0) {
            return &model->outputs[index];
        }
    }
    return NULL;
}

static int answer_shape(const revenant_ml_feature *described, size_t count, int64_t *shape)
{
    if (described != NULL && described->rank > 0 && described->rank <= REVENANT_ML_MAX_RANK &&
        revenant_ml_count_of_shape(described->shape, described->rank) == (int64_t)count) {
        memcpy(shape, described->shape, sizeof(int64_t) * (size_t)described->rank);
        return described->rank;
    }
    shape[0] = (int64_t)count;
    return 1;
}

static int answer_with_scores(const revenant_ml_model *model, const double *scores, size_t count,
                              revenant_ml_features *outputs, char *error, size_t error_size)
{
    size_t index, best = 0;
    const char *label_name = model->predicted_feature_name;
    const char *probability_name = model->predicted_probabilities_name;
    int classifier = revenant_ml_kind_is_classifier(model->kind);

    if (!classifier) {
        const char *name = model->output_count > 0 ? model->outputs[0].name : NULL;
        int64_t shape[REVENANT_ML_MAX_RANK];
        int rank;
        revenant_ml_array array;
        if (name == NULL) {
            snprintf(error, error_size, "the model has no output to answer in");
            return 0;
        }
        if (model->output_count == 1 && model->outputs[0].type == REVENANT_ML_FEATURE_DOUBLE && count == 1) {
            if (!revenant_ml_features_put(outputs, name, revenant_ml_value_number(scores[0]))) {
                snprintf(error, error_size, "the model's answers have no room for '%s'", name);
                return 0;
            }
            return 1;
        }
        rank = answer_shape(model->output_count > 0 ? &model->outputs[0] : NULL, count, shape);
        array = revenant_ml_array_alloc(REVENANT_ML_ARRAY_DOUBLE, shape, rank);
        for (index = 0; index < count; index++) {
            revenant_ml_array_set(&array, (int64_t)index, scores[index]);
        }
        if (!revenant_ml_features_put(outputs, name, revenant_ml_value_array(array))) {
            snprintf(error, error_size, "the model's answers have no room for '%s'", name);
            return 0;
        }
        return 1;
    }
    for (index = 1; index < count; index++) {
        if (scores[index] > scores[best]) {
            best = index;
        }
    }
    if (label_name == NULL && model->output_count > 0) {
        label_name = model->outputs[0].name;
    }
    if (probability_name == NULL && model->output_count > 1) {
        probability_name = model->outputs[1].name;
    }
    if (label_name != NULL) {
        char text[64];
        if (best < model->class_label_count && model->class_labels[best] != NULL) {
            snprintf(text, sizeof text, "%s", model->class_labels[best]);
        } else {
            snprintf(text, sizeof text, "%lu", (unsigned long)best);
        }
        if (!revenant_ml_features_put(outputs, label_name, revenant_ml_value_string_copy(text, strlen(text)))) {
            snprintf(error, error_size, "the model's answers have no room for the class label");
            return 0;
        }
    }
    if (probability_name != NULL) {
        revenant_ml_value probabilities = revenant_ml_value_dictionary();
        for (index = 0; index < count; index++) {
            char key[32];
            if (index < model->class_label_count && model->class_labels[index] != NULL) {
                if (!revenant_ml_dictionary_put(&probabilities, model->class_labels[index], scores[index])) {
                    revenant_ml_value_free(&probabilities);
                    snprintf(error, error_size, "the model's probabilities have no room for %lu classes",
                             (unsigned long)count);
                    return 0;
                }
            } else {
                snprintf(key, sizeof key, "%lu", (unsigned long)index);
                if (!revenant_ml_dictionary_put(&probabilities, key, scores[index])) {
                    revenant_ml_value_free(&probabilities);
                    snprintf(error, error_size, "the model's probabilities have no room for %lu classes",
                             (unsigned long)count);
                    return 0;
                }
            }
        }
        if (!revenant_ml_features_put(outputs, probability_name, probabilities)) {
            snprintf(error, error_size, "the model's answers have no room for the probabilities");
            return 0;
        }
    }
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        const revenant_ml_feature *described = &model->outputs[index];
        int64_t shape[REVENANT_ML_MAX_RANK];
        int rank;
        revenant_ml_array array;
        size_t which;
        if (name == NULL) {
            continue;
        }
        if ((label_name != NULL && strcmp(name, label_name) == 0) ||
            (probability_name != NULL && strcmp(name, probability_name) == 0)) {
            continue;
        }
        if (revenant_ml_features_get(outputs, name) != NULL) {
            continue;
        }
        if (described->type != REVENANT_ML_FEATURE_MULTI_ARRAY && described->type != REVENANT_ML_FEATURE_DICTIONARY) {
            continue;
        }
        rank = answer_shape(described, count, shape);
        array = revenant_ml_array_alloc(REVENANT_ML_ARRAY_DOUBLE, shape, rank);
        for (which = 0; which < count; which++) {
            revenant_ml_array_set(&array, (int64_t)which, scores[which]);
        }
        if (!revenant_ml_features_put(outputs, name, revenant_ml_value_array(array))) {
            snprintf(error, error_size, "the model's answers have no room for '%s'", name);
            return 0;
        }
    }
    return 1;
}

static int run_tree_ensemble(const revenant_ml_node *kind_node, const revenant_ml_model *model,
                             const revenant_ml_features *values, revenant_ml_features *outputs, char *error,
                             size_t error_size)
{
    const revenant_ml_node *ensemble = revenant_ml_get(kind_node, "treeEnsemble");
    double *features = NULL, *scores = NULL;
    size_t feature_count = 0, node_count, base_count;
    if (ensemble == NULL) {
        snprintf(error, error_size, "the tree ensemble has no trees in it");
        return 0;
    }
    node_count = revenant_ml_count_field(ensemble, "nodes");
    base_count = revenant_ml_count_field(ensemble, "basePredictionValue");
    size_t classes, index;

    if (!inputs_as_vector(model, values, &features, &feature_count, error, error_size)) {
        return 0;
    }
    classes = base_count > 0 ? base_count : (model->class_label_count > 0 ? model->class_label_count : 1);
    scores = (double *)calloc(classes, sizeof *scores);
    if (scores == NULL) {
        free(features);
        snprintf(error, error_size, "the model's scores have no room for %lu classes", (unsigned long)classes);
        return 0;
    }
    for (index = 0; index < base_count && index < classes; index++) {
        scores[index] = revenant_ml_double_at(ensemble, "basePredictionValue", index, 0.0);
    }
    for (index = 0; index < node_count; index++) {
        const revenant_ml_node *root = revenant_ml_node_at_field(ensemble, "nodes", index);
        int64_t tree = revenant_ml_int(revenant_ml_get(root, "treeId"), 0);
        int64_t current = revenant_ml_int(revenant_ml_get(root, "nodeId"), 0);
        int64_t steps;
        int is_root = 1;
        for (steps = 0; steps < (int64_t)node_count; steps++) {
            const revenant_ml_node *other = revenant_ml_node_at_field(ensemble, "nodes", (size_t)steps);
            if (other == root || revenant_ml_int(revenant_ml_get(other, "treeId"), 0) != tree) {
                continue;
            }
            if (revenant_ml_int(revenant_ml_get(other, "trueChildNodeId"), -1) == current ||
                revenant_ml_int(revenant_ml_get(other, "falseChildNodeId"), -1) == current) {
                is_root = 0;
                break;
            }
        }
        if (!is_root) {
            continue;
        }
        for (steps = 0; steps <= (int64_t)node_count; steps++) {
            const revenant_ml_node *node = NULL;
            int behaviour;
            size_t at;
            for (at = 0; at < node_count; at++) {
                const revenant_ml_node *candidate = revenant_ml_node_at_field(ensemble, "nodes", at);
                if (revenant_ml_int(revenant_ml_get(candidate, "treeId"), 0) == tree &&
                    revenant_ml_int(revenant_ml_get(candidate, "nodeId"), 0) == current) {
                    node = candidate;
                    break;
                }
            }
            if (node == NULL) {
                break;
            }
            behaviour = revenant_ml_int(revenant_ml_get(node, "nodeBehavior"), 0);
            if (behaviour == 6) {
                size_t evaluations = revenant_ml_count_field(node, "evaluationInfo"), which;
                for (which = 0; which < evaluations; which++) {
                    const revenant_ml_node *entry = revenant_ml_node_at_field(node, "evaluationInfo", which);
                    size_t class_index = (size_t)revenant_ml_int(revenant_ml_get(entry, "evaluationIndex"), 0);
                    if (class_index < classes) {
                        scores[class_index] += revenant_ml_double(revenant_ml_get(entry, "evaluationValue"), 0.0);
                    }
                }
                break;
            }
            {
                size_t feature_index = (size_t)revenant_ml_int(revenant_ml_get(node, "branchFeatureIndex"), 0);
                double value = feature_index < feature_count ? features[feature_index] : 0.0;
                double threshold = revenant_ml_double(revenant_ml_get(node, "branchFeatureValue"), 0.0);
                int go_true;
                switch (behaviour) {
                case 0:
                    go_true = value <= threshold;
                    break;
                case 2:
                    go_true = value >= threshold;
                    break;
                case 3:
                    go_true = value > threshold;
                    break;
                case 4:
                    go_true = value == threshold;
                    break;
                case 5:
                    go_true = value != threshold;
                    break;
                default:
                    go_true = value < threshold;
                    break;
                }
                current = revenant_ml_int(revenant_ml_get(node, go_true ? "trueChildNodeId" : "falseChildNodeId"), -1);
                if (current < 0) {
                    break;
                }
            }
        }
    }
    free(features);
    apply_tree_transform(revenant_ml_int(revenant_ml_get(kind_node, "postEvaluationTransform"), 0), scores, classes);
    {
        int answered = answer_with_scores(model, scores, classes, outputs, error, error_size);
        free(scores);
        return answered;
    }
}

static int run_glm(const revenant_ml_node *kind_node, const revenant_ml_model *model,
                   const revenant_ml_features *values, revenant_ml_features *outputs, char *error,
                   size_t error_size)
{
    double *features = NULL, *scores = NULL;
    size_t feature_count = 0, vectors = revenant_ml_count_field(kind_node, "weights");
    size_t offsets = revenant_ml_count_field(kind_node, "offset");
    size_t index, at, classes;
    int classifier = revenant_ml_kind_is_classifier(model->kind);
    int reference_class = revenant_ml_int(revenant_ml_get(kind_node, "classEncoding"), 0) == 0;

    if (!inputs_as_vector(model, values, &features, &feature_count, error, error_size)) {
        return 0;
    }
    if (vectors == 0) {
        free(features);
        snprintf(error, error_size, "the model is a GLM with no weights");
        return 0;
    }
    if (classifier && reference_class) {
        classes = model->class_label_count > 0 ? model->class_label_count : vectors + 1;
    } else {
        classes = vectors;
    }
    scores = (double *)calloc(classes, sizeof *scores);
    if (scores == NULL) {
        free(features);
        return 0;
    }
    for (index = 0; index < vectors; index++) {
        const revenant_ml_node *vector_node = revenant_ml_node_at_field(kind_node, "weights", index);
        size_t length = revenant_ml_count_field(vector_node, "value");
        double total = index < offsets ? revenant_ml_double_at(kind_node, "offset", index, 0.0) : 0.0;
        for (at = 0; at < length && at < feature_count; at++) {
            total += revenant_ml_double_at(vector_node, "value", at, 0.0) * features[at];
        }
        if (index < classes) {
            scores[index] = total;
        }
    }
    free(features);
    if (classifier && reference_class) {
        double *shifted = (double *)calloc(classes, sizeof *shifted);
        int answered;
        if (shifted == NULL) {
            free(scores);
            return 0;
        }
        for (index = 1; index < classes && index - 1 < vectors; index++) {
            shifted[index] = scores[index - 1];
        }
        shifted[0] = 0.0;
        free(scores);
        softmax_over(shifted, classes);
        answered = answer_with_scores(model, shifted, classes, outputs, error, error_size);
        free(shifted);
        return answered;
    }
    apply_glm_transform(revenant_ml_int(revenant_ml_get(kind_node, "postEvaluationTransform"), 0), scores, classes);
    {
        int answered = answer_with_scores(model, scores, classes, outputs, error, error_size);
        free(scores);
        return answered;
    }
}

static int run_preprocessing(const revenant_ml_model *model, const revenant_ml_node *kind_node,
                             const revenant_ml_features *values, revenant_ml_features *outputs, char *error,
                             size_t error_size)
{
    double *numbers = NULL;
    size_t count = 0, index;
    const char *output_name = model->output_count > 0 ? model->outputs[0].name : NULL;
    int64_t shape[REVENANT_ML_MAX_RANK];
    int rank;
    revenant_ml_array array;

    if (!inputs_as_vector(model, values, &numbers, &count, error, error_size)) {
        return 0;
    }
    switch (model->kind) {
    case REVENANT_ML_KIND_SCALER: {
        size_t scales = revenant_ml_count_field(kind_node, "scaleValue");
        size_t shifts = revenant_ml_count_field(kind_node, "shiftValue");
        for (index = 0; index < count; index++) {
            double by_scale = index < scales ? revenant_ml_double_at(kind_node, "scaleValue", index, 1.0) : 1.0;
            double by_shift = index < shifts ? revenant_ml_double_at(kind_node, "shiftValue", index, 0.0) : 0.0;
            numbers[index] = (numbers[index] + by_shift) * by_scale;
        }
        break;
    }
    case REVENANT_ML_KIND_NORMALIZER: {
        int64_t norm = revenant_ml_int_at(kind_node, "norm", 0, 1);
        double total = 0.0;
        for (index = 0; index < count; index++) {
            if (norm == 0) {
                if (fabs(numbers[index]) > total) {
                    total = fabs(numbers[index]);
                }
            } else if (norm == 2) {
                total += fabs(numbers[index]);
            } else {
                total += numbers[index] * numbers[index];
            }
        }
        if (norm != 0) {
            total = sqrt(total);
        }
        if (total > 0.0) {
            for (index = 0; index < count; index++) {
                numbers[index] /= total;
            }
        }
        break;
    }
    case REVENANT_ML_KIND_ONE_HOT_ENCODER: {
        size_t listed = revenant_ml_count_field(kind_node, "categories");
        if (listed == 0) {
            free(numbers);
            snprintf(error, error_size, "the one-hot encoder lists no categories, so it has nothing to encode");
            return 0;
        }
        for (index = 0; index < count; index++) {
            size_t which;
            for (which = 0; which < listed; which++) {
                if (fabs(revenant_ml_double_at(kind_node, "categories", which, 0.0) - numbers[index]) < 1e-9) {
                    numbers[index] = 1.0;
                    break;
                }
                numbers[index] = 0.0;
            }
        }
        break;
    }
    case REVENANT_ML_KIND_IDENTITY:
    case REVENANT_ML_KIND_IMPUTER:
        for (index = 0; index < count; index++) {
            if (numbers[index] != numbers[index]) {
                free(numbers);
                snprintf(error, error_size,
                         "the imputer was given a value that is not a number, which this port does not replace for it");
                return 0;
            }
        }
        break;
    default:
        free(numbers);
        snprintf(error, error_size, "the model is a %s, which this port does not run",
                 revenant_ml_kind_name(model->kind));
        return 0;
    }
    if (output_name == NULL) {
        free(numbers);
        snprintf(error, error_size, "the model has no output to answer in");
        return 0;
    }
    rank = answer_shape(model->output_count > 0 ? &model->outputs[0] : NULL, count, shape);
    array = revenant_ml_array_alloc(REVENANT_ML_ARRAY_DOUBLE, shape, rank);
    for (index = 0; index < count; index++) {
        revenant_ml_array_set(&array, (int64_t)index, numbers[index]);
    }
    free(numbers);
    if (!revenant_ml_features_put(outputs, output_name, revenant_ml_value_array(array))) {
        snprintf(error, error_size, "the model's answers have no room for '%s'", output_name);
        return 0;
    }
    return 1;
}

static int input_is_image(const revenant_ml_model *model, const char *feature)
{
    size_t index;
    for (index = 0; index < model->input_count; index++) {
        const char *name = model->inputs[index].name;
        if (name != NULL && strcmp(name, feature) == 0) {
            return model->inputs[index].type == REVENANT_ML_FEATURE_IMAGE;
        }
    }
    return 0;
}

static int run_neural_network(const revenant_ml_node *kind_node, const revenant_ml_model *model,
                              revenant_ml_features *values, char *error, size_t error_size)
{
    revenant_ml_bindings bindings;
    size_t index, total = revenant_ml_count_field(kind_node, "layers");
    int classifier = revenant_ml_kind_is_classifier(model->kind);
    const char *score_name = NULL;
    int ok = 0;

    revenant_ml_bindings_init(&bindings, total + model->input_count + model->output_count + 8);
    if (bindings.tensors == NULL) {
        snprintf(error, error_size, "the network has no room for its %lu layers", (unsigned long)total);
        return 0;
    }
    for (index = 0; index < model->input_count; index++) {
        const char *name = model->inputs[index].name;
        const revenant_ml_value *value = revenant_ml_features_get(values, name);
        revenant_ml_tensor tensor;
        if (name == NULL || value == NULL || !revenant_ml_tensor_from_value(&tensor, value)) {
            revenant_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the input '%s' is not an array this port can read",
                     name != NULL ? name : "(unnamed)");
            return 0;
        }
        if (!revenant_ml_bindings_put(&bindings, name, tensor)) {
            revenant_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the network has no room for its inputs");
            return 0;
        }
    }
    {
        size_t steps = revenant_ml_count_field(kind_node, "preprocessing"), step;
        for (step = 0; step < steps; step++) {
            const revenant_ml_node *step_node = revenant_ml_node_at_field(kind_node, "preprocessing", step);
            const revenant_ml_node *scaler = revenant_ml_get(step_node, "scaler");
            const revenant_ml_node *mean = revenant_ml_get(step_node, "meanImage");
            char feature[256];
            revenant_ml_tensor *value;
            if (revenant_ml_text(revenant_ml_get(step_node, "featureName"), feature, sizeof feature) == NULL) {
                continue;
            }
            value = revenant_ml_bindings_find(&bindings, feature);
            if (value == NULL || value->data == NULL) {
                continue;
            }
            if (scaler != NULL && input_is_image(model, feature)) {
                double scale = revenant_ml_number_of(scaler, "channelScale", 1.0);
                double red = revenant_ml_number_of(scaler, "redBias", 0.0);
                double green = revenant_ml_number_of(scaler, "greenBias", 0.0);
                double blue = revenant_ml_number_of(scaler, "blueBias", 0.0);
                double gray = revenant_ml_number_of(scaler, "grayBias", 0.0);
                int64_t area = 1, channel;
                int axis;
                for (axis = 1; axis < value->rank; axis++) {
                    area *= value->shape[axis];
                }
                for (channel = 0; channel < value->shape[0]; channel++) {
                    double add = value->shape[0] == 1 ? gray
                                   : value->shape[0] == 2 ? (channel == 0 ? red : green)
                                   : (channel == 0 ? red : (channel == 1 ? green : blue));
                    int64_t at;
                    for (at = 0; at < area; at++) {
                        double pixel = value->data[channel * area + at];
                        value->data[channel * area + at] = (float)(pixel * scale + add);
                    }
                }
            } else if (mean != NULL) {
                const revenant_ml_node *channels = revenant_ml_get(mean, "meanImage");
                size_t at, count = revenant_ml_count(channels);
                for (at = 0; at < count && at < value->count; at++) {
                    value->data[at] = (float)((double)value->data[at] - revenant_ml_double(revenant_ml_at(channels, at), 0.0));
                }
            }
        }
    }
    for (index = 0; index < total; index++) {
        if (!revenant_ml_run_layer(revenant_ml_node_at_field(kind_node, "layers", index), &bindings, error,
                                 error_size)) {
            revenant_ml_bindings_release(&bindings);
            return 0;
        }
    }
    if (classifier) {
        revenant_ml_tensor *scores = NULL;
        double *numbers;
        if (model->predicted_probabilities_name != NULL) {
            scores = revenant_ml_bindings_find(&bindings, model->predicted_probabilities_name);
            score_name = model->predicted_probabilities_name;
        }
        if (scores == NULL) {
            for (index = 0; index < model->output_count; index++) {
                revenant_ml_tensor *candidate = revenant_ml_bindings_find(&bindings, model->outputs[index].name);
                if (candidate != NULL && candidate->data != NULL && candidate->count > 1 &&
                    (model->class_label_count == 0 || candidate->count == model->class_label_count)) {
                    scores = candidate;
                    score_name = model->outputs[index].name;
                    break;
                }
            }
        }
        if (scores == NULL || scores->data == NULL || scores->count == 0) {
            revenant_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the network produced no scores for its classes");
            return 0;
        }
        numbers = (double *)malloc(scores->count * sizeof *numbers);
        if (numbers == NULL) {
            revenant_ml_bindings_release(&bindings);
            return 0;
        }
        for (index = 0; index < scores->count; index++) {
            numbers[index] = scores->data[index];
        }
        if (score_name != NULL) {
            int64_t shape[REVENANT_ML_MAX_RANK];
            int rank = answer_shape(model_feature_named(model, score_name), scores->count, shape);
            revenant_ml_array array;
            array = revenant_ml_array_alloc(REVENANT_ML_ARRAY_DOUBLE, shape, rank);
            for (index = 0; index < scores->count; index++) {
                revenant_ml_array_set(&array, (int64_t)index, numbers[index]);
            }
            if (!revenant_ml_features_put(values, score_name, revenant_ml_value_array(array))) {
                free(numbers);
                revenant_ml_bindings_release(&bindings);
                snprintf(error, error_size, "the model's answers have no room for '%s'", score_name);
                return 0;
            }
        }
        ok = answer_with_scores(model, numbers, scores->count, values, error, error_size);
        free(numbers);
        revenant_ml_bindings_release(&bindings);
        return ok;
    }
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        revenant_ml_tensor *tensor = name != NULL ? revenant_ml_bindings_find(&bindings, name) : NULL;
        revenant_ml_value value;
        if (tensor == NULL || tensor->data == NULL) {
            continue;
        }
        value = revenant_ml_tensor_to_value(tensor, REVENANT_ML_ARRAY_FLOAT32);
        if (model->outputs[index].rank > 0 &&
            revenant_ml_count_of_shape(model->outputs[index].shape, model->outputs[index].rank) ==
                (int64_t)value.array.count) {
            revenant_ml_array reshaped =
                revenant_ml_array_alloc(value.array.data_type, model->outputs[index].shape,
                                      model->outputs[index].rank);
            size_t element;
            for (element = 0; element < reshaped.count && element < value.array.count; element++) {
                revenant_ml_array_set(&reshaped, (int64_t)element, revenant_ml_array_get(&value.array, (int64_t)element));
            }
            revenant_ml_value_free(&value);
            value = revenant_ml_value_array(reshaped);
        }
        if (!revenant_ml_features_put(values, name, value)) {
            revenant_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the model's answers have no room for '%s'", name);
            return 0;
        }
    }
    revenant_ml_bindings_release(&bindings);
    return 1;
}

static int run_one(const revenant_ml_node *document, const char *bundle, revenant_ml_features *values,
                   char *error, size_t error_size)
{
    revenant_ml_model *model = calloc(1, sizeof *model);
    const char *kind_field = revenant_ml_node_kind_name(document);
    const revenant_ml_node *kind_node;
    int ok;

    if (kind_field == NULL) {
        snprintf(error, error_size, "the model names no kind of model the specification declares");
        free(model);
        return 0;
    }
    if (!revenant_ml_model_from_node(model, document, bundle, error, error_size)) {
        free(model);
        return 0;
    }
    kind_node = revenant_ml_get(document, kind_field);
    switch (model->kind) {
    case REVENANT_ML_KIND_NEURAL_NETWORK:
    case REVENANT_ML_KIND_NEURAL_NETWORK_CLASSIFIER:
    case REVENANT_ML_KIND_NEURAL_NETWORK_REGRESSOR:
        ok = run_neural_network(kind_node, model, values, error, error_size);
        break;
    case REVENANT_ML_KIND_TREE_ENSEMBLE_CLASSIFIER:
    case REVENANT_ML_KIND_TREE_ENSEMBLE_REGRESSOR:
        ok = run_tree_ensemble(kind_node, model, values, values, error, error_size);
        break;
    case REVENANT_ML_KIND_GLM_CLASSIFIER:
    case REVENANT_ML_KIND_GLM_REGRESSOR:
        ok = run_glm(kind_node, model, values, values, error, error_size);
        break;
    case REVENANT_ML_KIND_SCALER:
    case REVENANT_ML_KIND_IMPUTER:
    case REVENANT_ML_KIND_NORMALIZER:
    case REVENANT_ML_KIND_ONE_HOT_ENCODER:
    case REVENANT_ML_KIND_IDENTITY:
        ok = run_preprocessing(model, kind_node, values, values, error, error_size);
        break;
    case REVENANT_ML_KIND_PIPELINE:
    case REVENANT_ML_KIND_PIPELINE_CLASSIFIER:
    case REVENANT_ML_KIND_PIPELINE_REGRESSOR: {
        size_t index, total = revenant_ml_count_field(kind_node, "models");
        if (total == 0) {
            revenant_ml_model_release(model);
            snprintf(error, error_size, "the pipeline has no models in it");
            return 0;
        }
        ok = 1;
        for (index = 0; index < total; index++) {
            char sub_error[512];
            if (!run_one(revenant_ml_node_at_field(kind_node, "models", index), bundle, values, sub_error,
                         sizeof sub_error)) {
                snprintf(error, error_size, "the model at position %lu of the pipeline: %s", (unsigned long)index,
                         sub_error);
                ok = 0;
                break;
            }
        }
        break;
    }
    default:
        snprintf(error, error_size, "the model is a %s, which this port does not run",
                 revenant_ml_kind_name(model->kind));
        ok = 0;
        break;
    }
    revenant_ml_model_release(model);
    return ok;
}

int revenant_ml_predict(const revenant_ml_model *model, revenant_ml_features *inputs,
                      revenant_ml_features *outputs, char *error, size_t error_size)
{
    revenant_ml_features *working = calloc(1, sizeof *working);
    char missing[256], mismatched[256];
    size_t index;

    if (working == NULL) {
        snprintf(error, error_size, "there was no room for the values a run works in");
        return 0;
    }
    revenant_ml_features_init(working);
    if (!revenant_ml_features_satisfy(model, inputs, missing, sizeof missing, mismatched, sizeof mismatched)) {
        if (missing[0] != 0) {
            snprintf(error, error_size, "the model needs the input '%s', which is not there", missing);
        } else {
            snprintf(error, error_size, "the model needs the input '%s' to be a different shape or kind",
                     mismatched);
        }
        free(working);
        return 0;
    }
    revenant_ml_features_init(working);
    for (index = 0; index < inputs->count; index++) {
        revenant_ml_value borrowed = inputs->entries[index].value;
        borrowed.array.owns_data = 0;
        if (!revenant_ml_features_put(working, inputs->entries[index].name, borrowed)) {
            revenant_ml_features_release(working);
            free(working);
            snprintf(error, error_size, "the model's inputs have no room for all of them");
            return 0;
        }
    }
    if (!run_one(&model->document, model->bundle, working, error, error_size) ||
        !revenant_ml_features_take_outputs(model, working, outputs)) {
        if (error[0] == 0) {
            snprintf(error, error_size, "the model produced no value for one of the outputs it names");
        }
        revenant_ml_features_release(working);
        free(working);
        return 0;
    }
    revenant_ml_features_release(working);
    free(working);
    return 1;
}
