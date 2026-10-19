/* Running a model: the values in, the values out.
 * CharonMLPredict.h says what it is for; this is the kind by kind reading of it.
 *
 * A model is run over a set of values named by their own names, and a pipeline runs each of
 * its sub-models over the same set in turn: the output of one is the input of the next, found
 * by name, which is how a converted tabular or text classifier is put together. A model is
 * read out of its message for each run rather than kept beside it, so a sub-model is a model
 * in every respect but where its bytes live.
 */
#include "CharonMLPredict.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "CharonMLLayerKinds.h"
#include "CharonMLLayers.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* --- the set of values ------------------------------------------------------------------------- */

void charon_ml_features_init(charon_ml_features *features)
{
    memset(features, 0, sizeof *features);
}

void charon_ml_features_release(charon_ml_features *features)
{
    size_t index;
    for (index = 0; index < features->count; index++) {
        free(features->entries[index].name);
        charon_ml_value_free(&features->entries[index].value);
    }
    memset(features, 0, sizeof *features);
}

int charon_ml_features_put(charon_ml_features *features, const char *name, charon_ml_value value)
{
    size_t index;
    if (name == NULL) {
        charon_ml_value_free(&value);
        return 0;
    }
    for (index = 0; index < features->count; index++) {
        if (strcmp(features->entries[index].name, name) == 0) {
            charon_ml_value_free(&features->entries[index].value);
            features->entries[index].value = value;
            return 1;
        }
    }
    if (features->count >= CHARON_ML_MAX_FEATURES) {
        charon_ml_value_free(&value);
        return 0;
    }
    features->entries[features->count].name = strdup(name);
    features->entries[features->count].value = value;
    features->count++;
    return 1;
}

const charon_ml_value *charon_ml_features_get(const charon_ml_features *features, const char *name)
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

int charon_ml_features_remove(charon_ml_features *features, const char *name)
{
    size_t index;
    for (index = 0; index < features->count; index++) {
        if (strcmp(features->entries[index].name, name) == 0) {
            free(features->entries[index].name);
            charon_ml_value_free(&features->entries[index].value);
            memmove(&features->entries[index], &features->entries[index + 1],
                    (features->count - index - 1) * sizeof *features->entries);
            features->count--;
            return 1;
        }
    }
    return 0;
}

/* --- the values as numbers ---------------------------------------------------------------------- */

/* One value as a vector of numbers, which is what every model that is not a neural network
 * works in: a tree, a GLM and each of the preprocessing models take one number per feature. */
static int value_as_vector(const charon_ml_value *value, double **out, size_t *count)
{
    double *numbers;
    size_t index;
    if (value == NULL) {
        return 0;
    }
    if (value->kind == CHARON_ML_VALUE_NUMBER) {
        numbers = (double *)malloc(sizeof *numbers);
        if (numbers == NULL) {
            return 0;
        }
        numbers[0] = value->number;
        *out = numbers;
        *count = 1;
        return 1;
    }
    if (value->kind != CHARON_ML_VALUE_ARRAY || value->array.count == 0) {
        return 0;
    }
    numbers = (double *)malloc(value->array.count * sizeof *numbers);
    if (numbers == NULL) {
        return 0;
    }
    for (index = 0; index < value->array.count; index++) {
        numbers[index] = charon_ml_array_get(&value->array, (int64_t)index);
    }
    *out = numbers;
    *count = value->array.count;
    return 1;
}

/* Every input of a model as one vector of numbers, in the order the description names them,
 * which is the order a tree's branchFeatureIndex and a GLM's weights count in. */
static int inputs_as_vector(const charon_ml_model *model, const charon_ml_features *values, double **out,
                            size_t *count, char *error, size_t error_size)
{
    double *numbers = NULL;
    size_t total = 0, index;
    for (index = 0; index < model->input_count; index++) {
        const charon_ml_value *value = charon_ml_features_get(values, model->inputs[index].name);
        double *one = NULL;
        size_t one_count = 0, at;
        if (!value_as_vector(value, &one, &one_count)) {
            free(numbers);
            snprintf(error, error_size, "the input '%s' is %s, which this port cannot read as numbers",
                     model->inputs[index].name != NULL ? model->inputs[index].name : "(unnamed)",
                     value == NULL ? "not there" : charon_ml_value_name(value->kind));
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

int charon_ml_features_satisfy(const charon_ml_model *model, const charon_ml_features *values, char *missing,
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
        const charon_ml_feature *described = &model->inputs[index];
        const charon_ml_value *value = charon_ml_features_get(values, described->name);
        int axis;
        if (value == NULL || value->kind == CHARON_ML_VALUE_NONE) {
            if (described->optional) {
                continue; /* an optional input may be absent, which is what optional means */
            }
            if (missing != NULL && described->name != NULL) {
                snprintf(missing, missing_size, "%s", described->name);
            }
            return 0;
        }
        if (described->type == CHARON_ML_FEATURE_MULTI_ARRAY) {
            if (value->kind == CHARON_ML_VALUE_NUMBER) {
                continue; /* a scalar stands for an array of one, which is what a SizeRange of 1 says */
            }
            if (value->kind != CHARON_ML_VALUE_ARRAY) {
                goto mismatched;
            }
            for (axis = 0; axis < described->rank && axis < value->array.rank; axis++) {
                if (described->shape[axis] > 0 && described->shape[axis] != value->array.shape[axis]) {
                    goto mismatched;
                }
            }
            continue;
        }
        if (described->type == CHARON_ML_FEATURE_IMAGE && value->kind == CHARON_ML_VALUE_IMAGE) {
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

int charon_ml_features_take_outputs(const charon_ml_model *model, charon_ml_features *inputs,
                                    charon_ml_features *outputs)
{
    size_t index;
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        const charon_ml_value *value;
        if (name == NULL) {
            continue;
        }
        value = charon_ml_features_get(inputs, name);
        if (value == NULL) {
            return 0;
        }
        /* The value moves, it is not copied: the struct is copied and the original is cleared
         * without being freed, because the copy now owns the same buffer and freeing the
         * original would free it out from under the answer. */
        if (!charon_ml_features_put(outputs, name, *value)) {
            return 0;
        }
        memset((void *)value, 0, sizeof *value);
        charon_ml_features_remove(inputs, name);
    }
    return 1;
}

/* --- the post-evaluation transforms ------------------------------------------------------------ */

/* The specification's own enumerations, by their own numbers: the tree ensemble's four. A
 * transform is what turns the numbers a model accumulates into the numbers an application
 * reads, and each is the arithmetic its name is. */
enum {
    CHARON_ML_TREE_NO_TRANSFORM = 0,
    CHARON_ML_TREE_SOFTMAX = 1,
    CHARON_ML_TREE_LOGISTIC = 2,
    CHARON_ML_TREE_SOFTMAX_WITH_ZERO_CLASS = 3
};

static double logistic(double x)
{
    return x >= 0.0 ? 1.0 / (1.0 + exp(-x)) : exp(x) / (1.0 + exp(x));
}

static double probit(double x)
{
    return 0.5 * (1.0 + erf(x / sqrt(2.0)));
}

/* A softmax over a whole set, in place, with the largest value taken out first so that no
 * exponential of it can overflow. */
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
    case CHARON_ML_TREE_SOFTMAX:
        softmax_over(values, count);
        break;
    case CHARON_ML_TREE_LOGISTIC:
        for (index = 0; index < count; index++) {
            values[index] = logistic(values[index]);
        }
        break;
    case CHARON_ML_TREE_SOFTMAX_WITH_ZERO_CLASS:
        /* The softmax over every class but the first, which is the reference class: it keeps a
         * score of its own rather than taking one from the others, so it is 1 - the rest. */
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

/* --- the answers a model gives -------------------------------------------------------------------- */

/* A vector of scores as the values a model's description asks for. A classifier's two answers
 * are the name of the class with the largest score and the scores themselves, under the two
 * names the description gives; a regressor answers with the numbers under the name of its
 * output. Both are written, and a description that names an output which is neither of those
 * is answered with the numbers too, so a caller that asked for the scores by their own name
 * finds them. */
/* The feature of the model a name belongs to, or NULL when it names none: an answer takes the
 * shape of the feature it answers, and a name the model does not declare has no shape to take. */
static const charon_ml_feature *model_feature_named(const charon_ml_model *model, const char *name)
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

/* The shape an answer of `count` numbers has for a feature the model describes.
 *
 * The numbers are the same however they are shaped, but the shape is part of what the model said
 * and part of what a caller reads: a caller that asked for an output of shape 1x1x2 and is handed
 * a flat vector of two has to unwrap it, and one that is handed 1x1x2 where the model named 2 has to
 * guess. So the declared shape is used whenever its element count is the count of numbers there
 * are -- which is the only case where the two can both be true -- and the flat shape otherwise. */
static int answer_shape(const charon_ml_feature *described, size_t count, int64_t *shape)
{
    if (described != NULL && described->rank > 0 && described->rank <= CHARON_ML_MAX_RANK &&
        charon_ml_count_of_shape(described->shape, described->rank) == (int64_t)count) {
        memcpy(shape, described->shape, sizeof(int64_t) * (size_t)described->rank);
        return described->rank;
    }
    shape[0] = (int64_t)count;
    return 1;
}

static int answer_with_scores(const charon_ml_model *model, const double *scores, size_t count,
                              charon_ml_features *outputs, char *error, size_t error_size)
{
    size_t index, best = 0;
    const char *label_name = model->predicted_feature_name;
    const char *probability_name = model->predicted_probabilities_name;
    int classifier = charon_ml_kind_is_classifier(model->kind);

    if (!classifier) {
        const char *name = model->output_count > 0 ? model->outputs[0].name : NULL;
        int64_t shape[CHARON_ML_MAX_RANK];
        int rank;
        charon_ml_array array;
        if (name == NULL) {
            snprintf(error, error_size, "the model has no output to answer in");
            return 0;
        }
        /* A description that calls its output a double and not an array wants one number, and
         * not an array of one: a GLM regressor's output is a scalar, and an application that
         * reads the value would otherwise have to unwrap an array the model never named. */
        if (model->output_count == 1 && model->outputs[0].type == CHARON_ML_FEATURE_DOUBLE && count == 1) {
            if (!charon_ml_features_put(outputs, name, charon_ml_value_number(scores[0]))) {
                snprintf(error, error_size, "the model's answers have no room for '%s'", name);
                return 0;
            }
            return 1;
        }
        rank = answer_shape(model->output_count > 0 ? &model->outputs[0] : NULL, count, shape);
        array = charon_ml_array_alloc(CHARON_ML_ARRAY_DOUBLE, shape, rank);
        for (index = 0; index < count; index++) {
            charon_ml_array_set(&array, (int64_t)index, scores[index]);
        }
        if (!charon_ml_features_put(outputs, name, charon_ml_value_array(array))) {
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
        /* The label is a copy: the answer outlives the frame that wrote it, and a string over
         * that frame's buffer would be read after the frame is gone. */
        if (!charon_ml_features_put(outputs, label_name, charon_ml_value_string_copy(text, strlen(text)))) {
            snprintf(error, error_size, "the model's answers have no room for the class label");
            return 0;
        }
    }
    if (probability_name != NULL) {
        /* The probabilities are a dictionary of the class labels to their scores, which is the
         * type the specification gives that output and the one MLFeatureProvider's
         * dictionaryValue reads. A model that names no labels of its own is answered with the
         * class numbers as the keys, which is what the specification's own fallback is. */
        charon_ml_value probabilities = charon_ml_value_dictionary();
        for (index = 0; index < count; index++) {
            char key[32];
            if (index < model->class_label_count && model->class_labels[index] != NULL) {
                if (!charon_ml_dictionary_put(&probabilities, model->class_labels[index], scores[index])) {
                    charon_ml_value_free(&probabilities);
                    snprintf(error, error_size, "the model's probabilities have no room for %lu classes",
                             (unsigned long)count);
                    return 0;
                }
            } else {
                snprintf(key, sizeof key, "%lu", (unsigned long)index);
                if (!charon_ml_dictionary_put(&probabilities, key, scores[index])) {
                    charon_ml_value_free(&probabilities);
                    snprintf(error, error_size, "the model's probabilities have no room for %lu classes",
                             (unsigned long)count);
                    return 0;
                }
            }
        }
        if (!charon_ml_features_put(outputs, probability_name, probabilities)) {
            snprintf(error, error_size, "the model's answers have no room for the probabilities");
            return 0;
        }
    }
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        const charon_ml_feature *described = &model->outputs[index];
        int64_t shape[CHARON_ML_MAX_RANK];
        int rank;
        charon_ml_array array;
        size_t which;
        if (name == NULL) {
            continue;
        }
        if ((label_name != NULL && strcmp(name, label_name) == 0) ||
            (probability_name != NULL && strcmp(name, probability_name) == 0)) {
            continue;
        }
        if (charon_ml_features_get(outputs, name) != NULL) {
            continue;
        }
        if (described->type != CHARON_ML_FEATURE_MULTI_ARRAY && described->type != CHARON_ML_FEATURE_DICTIONARY) {
            continue;
        }
        rank = answer_shape(described, count, shape);
        array = charon_ml_array_alloc(CHARON_ML_ARRAY_DOUBLE, shape, rank);
        for (which = 0; which < count; which++) {
            charon_ml_array_set(&array, (int64_t)which, scores[which]);
        }
        if (!charon_ml_features_put(outputs, name, charon_ml_value_array(array))) {
            snprintf(error, error_size, "the model's answers have no room for '%s'", name);
            return 0;
        }
    }
    return 1;
}

/* --- the models ------------------------------------------------------------------------------------ */

/* A tree ensemble: the base prediction, then the value of the leaf each tree reaches, added
 * per class, and the post-evaluation transform over the result. The nodes are one flat list
 * for all the trees and are found by their nodeId within their own treeId, which is how the
 * specification writes them. */
static int run_tree_ensemble(const charon_ml_node *kind_node, const charon_ml_model *model,
                             const charon_ml_features *values, charon_ml_features *outputs, char *error,
                             size_t error_size)
{
    const charon_ml_node *ensemble = charon_ml_get(kind_node, "treeEnsemble");
    double *features = NULL, *scores = NULL;
    size_t feature_count = 0, node_count, base_count;
    if (ensemble == NULL) {
        snprintf(error, error_size, "the tree ensemble has no trees in it");
        return 0;
    }
    /* The nodes, the base prediction and a leaf's evaluations are all repeated fields, so each
     * is reached by its own name on the message that holds it rather than as a child of the
     * first entry: the entries are siblings in that message's list. */
    node_count = charon_ml_count_field(ensemble, "nodes");
    base_count = charon_ml_count_field(ensemble, "basePredictionValue");
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
        scores[index] = charon_ml_double_at(ensemble, "basePredictionValue", index, 0.0);
    }
    for (index = 0; index < node_count; index++) {
        const charon_ml_node *root = charon_ml_node_at_field(ensemble, "nodes", index);
        int64_t tree = charon_ml_int(charon_ml_get(root, "treeId"), 0);
        int64_t current = charon_ml_int(charon_ml_get(root, "nodeId"), 0);
        int64_t steps;
        int is_root = 1;
        /* A node that some other node of the same tree names as a true or a false child is an
         * interior node, not the root of that tree: the walk from it would add a leaf the tree
         * never reaches. The root is the one nothing else in its tree points at. */
        for (steps = 0; steps < (int64_t)node_count; steps++) {
            const charon_ml_node *other = charon_ml_node_at_field(ensemble, "nodes", (size_t)steps);
            if (other == root || charon_ml_int(charon_ml_get(other, "treeId"), 0) != tree) {
                continue;
            }
            if (charon_ml_int(charon_ml_get(other, "trueChildNodeId"), -1) == current ||
                charon_ml_int(charon_ml_get(other, "falseChildNodeId"), -1) == current) {
                is_root = 0;
                break;
            }
        }
        if (!is_root) {
            continue;
        }
        for (steps = 0; steps <= (int64_t)node_count; steps++) {
            const charon_ml_node *node = NULL;
            int behaviour;
            size_t at;
            for (at = 0; at < node_count; at++) {
                const charon_ml_node *candidate = charon_ml_node_at_field(ensemble, "nodes", at);
                if (charon_ml_int(charon_ml_get(candidate, "treeId"), 0) == tree &&
                    charon_ml_int(charon_ml_get(candidate, "nodeId"), 0) == current) {
                    node = candidate;
                    break;
                }
            }
            if (node == NULL) {
                break; /* a child that is not in the list: the walk ends where the model does */
            }
            behaviour = charon_ml_int(charon_ml_get(node, "nodeBehavior"), 0);
            if (behaviour == 6) { /* LeafNode */
                size_t evaluations = charon_ml_count_field(node, "evaluationInfo"), which;
                for (which = 0; which < evaluations; which++) {
                    const charon_ml_node *entry = charon_ml_node_at_field(node, "evaluationInfo", which);
                    size_t class_index = (size_t)charon_ml_int(charon_ml_get(entry, "evaluationIndex"), 0);
                    if (class_index < classes) {
                        scores[class_index] += charon_ml_double(charon_ml_get(entry, "evaluationValue"), 0.0);
                    }
                }
                break;
            }
            {
                size_t feature_index = (size_t)charon_ml_int(charon_ml_get(node, "branchFeatureIndex"), 0);
                double value = feature_index < feature_count ? features[feature_index] : 0.0;
                double threshold = charon_ml_double(charon_ml_get(node, "branchFeatureValue"), 0.0);
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
                default: /* 1 is BranchOnValueLessThan */
                    go_true = value < threshold;
                    break;
                }
                current = charon_ml_int(charon_ml_get(node, go_true ? "trueChildNodeId" : "falseChildNodeId"), -1);
                if (current < 0) {
                    break;
                }
            }
        }
    }
    free(features);
    apply_tree_transform(charon_ml_int(charon_ml_get(kind_node, "postEvaluationTransform"), 0), scores, classes);
    {
        int answered = answer_with_scores(model, scores, classes, outputs, error, error_size);
        free(scores);
        return answered;
    }
}

/* A GLM: the weights are one vector per class, the offset is the intercept beside it, and a
 * class's score is the dot product with the input plus that offset. A classifier that names
 * the reference class encoding has one weight vector fewer than it has classes, and the first
 * class scores the total of the rest, which is the one-against-rest reading that encoding is. */
static int run_glm(const charon_ml_node *kind_node, const charon_ml_model *model,
                   const charon_ml_features *values, charon_ml_features *outputs, char *error,
                   size_t error_size)
{
    double *features = NULL, *scores = NULL;
    size_t feature_count = 0, vectors = charon_ml_count_field(kind_node, "weights");
    size_t offsets = charon_ml_count_field(kind_node, "offset");
    size_t index, at, classes;
    int classifier = charon_ml_kind_is_classifier(model->kind);
    /* The encoding's own first case is ReferenceClass and a field set to it is not written at
     * all, so absent and ReferenceClass are the same value here: reading the absent one as
     * OneVsRest is what a converter's default would be, and it is not the specification's. */
    int reference_class = charon_ml_int(charon_ml_get(kind_node, "classEncoding"), 0) == 0;

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
        const charon_ml_node *vector_node = charon_ml_node_at_field(kind_node, "weights", index);
        size_t length = charon_ml_count_field(vector_node, "value");
        double total = index < offsets ? charon_ml_double_at(kind_node, "offset", index, 0.0) : 0.0;
        for (at = 0; at < length && at < feature_count; at++) {
            total += charon_ml_double_at(vector_node, "value", at, 0.0) * features[at];
        }
        if (index < classes) {
            scores[index] = total;
        }
    }
    free(features);
    if (classifier && reference_class) {
        /* The reference class has no weight vector of its own: it is the one every other
         * class is measured against, and it scores zero. The vectors then fill the classes
         * after it in order. Measured against coremltools' own runtime over four inputs of a
         * two-vector, three-class model: softmax over (0, v0.x + o0, v1.x + o1) is that
         * runtime's answer to the last digit, and the sum of what it answers is one.
         *
         * The score the reference class is given is the zero above, and the answer is a
         * softmax over the whole set -- not the per-class logistic the post-evaluation
         * transform names, which on these inputs gives (0.5, 0.525, 0.475) and would not sum
         * to one. That is what was measured, and it is what is written here. */
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
    apply_glm_transform(charon_ml_int(charon_ml_get(kind_node, "postEvaluationTransform"), 0), scores, classes);
    {
        int answered = answer_with_scores(model, scores, classes, outputs, error, error_size);
        free(scores);
        return answered;
    }
}

/* The preprocessing models, each of which is one arithmetic over the values it is given, and
 * the identity, which is the one that passes them on. */
static int run_preprocessing(const charon_ml_model *model, const charon_ml_node *kind_node,
                             const charon_ml_features *values, charon_ml_features *outputs, char *error,
                             size_t error_size)
{
    double *numbers = NULL;
    size_t count = 0, index;
    const char *output_name = model->output_count > 0 ? model->outputs[0].name : NULL;
    int64_t shape[CHARON_ML_MAX_RANK];
    int rank;
    charon_ml_array array;

    if (!inputs_as_vector(model, values, &numbers, &count, error, error_size)) {
        return 0;
    }
    switch (model->kind) {
    case CHARON_ML_KIND_SCALER: {
        size_t scales = charon_ml_count_field(kind_node, "scaleValue");
        size_t shifts = charon_ml_count_field(kind_node, "shiftValue");
        /* The scaler is (x + shift) * scale, measured against coremltools' own runtime on a
         * two-feature model over four inputs (facts/CoreML/CoreML.md); the name "shift" reads
         * the other way round, and x * scale + shift is not what it does. A feature with no
         * scale or shift of its own is passed through as the value 1 and 0 give. */
        for (index = 0; index < count; index++) {
            double by_scale = index < scales ? charon_ml_double_at(kind_node, "scaleValue", index, 1.0) : 1.0;
            double by_shift = index < shifts ? charon_ml_double_at(kind_node, "shiftValue", index, 0.0) : 0.0;
            numbers[index] = (numbers[index] + by_shift) * by_scale;
        }
        break;
    }
    case CHARON_ML_KIND_NORMALIZER: {
        /* The normalizer divides the whole vector by one norm: L2 for 1, the largest absolute
         * value for 0, and a sum of the absolute values for 2. */
        int64_t norm = charon_ml_int_at(kind_node, "norm", 0, 1);
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
    case CHARON_ML_KIND_ONE_HOT_ENCODER: {
        /* One output per input, a one where the input names a category of the model and a zero
         * where it does not. The categories are the integers the model lists. */
        size_t listed = charon_ml_count_field(kind_node, "categories");
        if (listed == 0) {
            free(numbers);
            snprintf(error, error_size, "the one-hot encoder lists no categories, so it has nothing to encode");
            return 0;
        }
        for (index = 0; index < count; index++) {
            size_t which;
            for (which = 0; which < listed; which++) {
                if (fabs(charon_ml_double_at(kind_node, "categories", which, 0.0) - numbers[index]) < 1e-9) {
                    numbers[index] = 1.0;
                    break;
                }
                numbers[index] = 0.0;
            }
        }
        break;
    }
    case CHARON_ML_KIND_IDENTITY:
    case CHARON_ML_KIND_IMPUTER:
        /* The imputer replaces what a model cannot hold with the value the model names, and
         * this port's inputs arrive already without one: a value a caller hands over that is
         * not a number is the only thing an imputer is asked for, and the port refuses to read
         * one rather than guessing what it should become. Saying so is the honest answer, and
         * it is the caller's own arithmetic to do first. */
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
                 charon_ml_kind_name(model->kind));
        return 0;
    }
    if (output_name == NULL) {
        free(numbers);
        snprintf(error, error_size, "the model has no output to answer in");
        return 0;
    }
    rank = answer_shape(model->output_count > 0 ? &model->outputs[0] : NULL, count, shape);
    array = charon_ml_array_alloc(CHARON_ML_ARRAY_DOUBLE, shape, rank);
    for (index = 0; index < count; index++) {
        charon_ml_array_set(&array, (int64_t)index, numbers[index]);
    }
    free(numbers);
    if (!charon_ml_features_put(outputs, output_name, charon_ml_value_array(array))) {
        snprintf(error, error_size, "the model's answers have no room for '%s'", output_name);
        return 0;
    }
    return 1;
}

/* The preprocessing a network's specification declares for one of its features, and the feature type
 * that decides whether the scale is put through at all. */
static int input_is_image(const charon_ml_model *model, const char *feature)
{
    size_t index;
    for (index = 0; index < model->input_count; index++) {
        const char *name = model->inputs[index].name;
        if (name != NULL && strcmp(name, feature) == 0) {
            return model->inputs[index].type == CHARON_ML_FEATURE_IMAGE;
        }
    }
    /* A feature the description does not name is not an image's pixels, and a scaler named for the
     * colours of a picture is not a scaler an array of numbers is put through. */
    return 0;
}

/* A neural network: the values its inputs name are put in, its layers are run in order, and
 * its outputs are read out. A classifier's scores are the output the description names as its
 * probabilities, or the one output that is a vector of more than one number. */
static int run_neural_network(const charon_ml_node *kind_node, const charon_ml_model *model,
                              charon_ml_features *values, char *error, size_t error_size)
{
    charon_ml_bindings bindings;
    size_t index, total = charon_ml_count_field(kind_node, "layers");
    int classifier = charon_ml_kind_is_classifier(model->kind);
    const char *score_name = NULL;
    int ok = 0;

    charon_ml_bindings_init(&bindings, total + model->input_count + model->output_count + 8);
    if (bindings.tensors == NULL) {
        snprintf(error, error_size, "the network has no room for its %lu layers", (unsigned long)total);
        return 0;
    }
    for (index = 0; index < model->input_count; index++) {
        const char *name = model->inputs[index].name;
        const charon_ml_value *value = charon_ml_features_get(values, name);
        charon_ml_tensor tensor;
        if (name == NULL || value == NULL || !charon_ml_tensor_from_value(&tensor, value)) {
            charon_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the input '%s' is not an array this port can read",
                     name != NULL ? name : "(unnamed)");
            return 0;
        }
        if (!charon_ml_bindings_put(&bindings, name, tensor)) {
            charon_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the network has no room for its inputs");
            return 0;
        }
    }
    {
        /* The network's own preprocessing, which runs before its first layer: the scale and the
         * per-channel bias an image's pixels are put through, or a mean to take off them. It is
         * named per feature, and a network that names none has none.
         *
         * The scale is a picture's, and it goes through for a feature the specification declares
         * as an image and not for an array. Measured on macOS 27.0 build 26A428 against
         * nn_image.mlmodel - a convolution, a ReLU and a global pool over a 3x8x8 feature, declared
         * as an array and carrying exactly this scale and these three colour biases - over the
         * input pattern tests/backports/host/coreml/cases.m feeds, a five-element pattern repeated
         * over the elements: the release answers 0.3570, 0.3338, 0.3595, 0.3827, which is the
         * global maximum of the convolution over the values as they were fed, and this port
         * answered 0.4189, 0.0000, 0.0000, 0.0000, which is the same convolution over the values
         * after the scale. coremltools 9.0's own runtime answers the same four numbers for the
         * container's own input, so neither runtime puts an array through the scale and this one
         * did. facts/CoreML/CoreML.md carries the tables and the port's own numbers.
         */
        size_t steps = charon_ml_count_field(kind_node, "preprocessing"), step;
        for (step = 0; step < steps; step++) {
            const charon_ml_node *step_node = charon_ml_node_at_field(kind_node, "preprocessing", step);
            const charon_ml_node *scaler = charon_ml_get(step_node, "scaler");
            const charon_ml_node *mean = charon_ml_get(step_node, "meanImage");
            char feature[256];
            charon_ml_tensor *value;
            if (charon_ml_text(charon_ml_get(step_node, "featureName"), feature, sizeof feature) == NULL) {
                continue;
            }
            value = charon_ml_bindings_find(&bindings, feature);
            if (value == NULL || value->data == NULL) {
                continue;
            }
            if (scaler != NULL && input_is_image(model, feature)) {
                double scale = charon_ml_number_of(scaler, "channelScale", 1.0);
                double red = charon_ml_number_of(scaler, "redBias", 0.0);
                double green = charon_ml_number_of(scaler, "greenBias", 0.0);
                double blue = charon_ml_number_of(scaler, "blueBias", 0.0);
                double gray = charon_ml_number_of(scaler, "grayBias", 0.0);
                int64_t area = 1, channel;
                int axis;
                for (axis = 1; axis < value->rank; axis++) {
                    area *= value->shape[axis];
                }
                for (channel = 0; channel < value->shape[0]; channel++) {
                    /* The bias is named for the colour the channel is: the first is red, the
                     * second green and the third blue, and a one-channel value is gray. */
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
                const charon_ml_node *channels = charon_ml_get(mean, "meanImage");
                size_t at, count = charon_ml_count(channels);
                for (at = 0; at < count && at < value->count; at++) {
                    value->data[at] = (float)((double)value->data[at] - charon_ml_double(charon_ml_at(channels, at), 0.0));
                }
            }
        }
    }
    for (index = 0; index < total; index++) {
        if (!charon_ml_run_layer(charon_ml_node_at_field(kind_node, "layers", index), &bindings, error,
                                 error_size)) {
            charon_ml_bindings_release(&bindings);
            return 0;
        }
    }
    if (classifier) {
        charon_ml_tensor *scores = NULL;
        double *numbers;
        if (model->predicted_probabilities_name != NULL) {
            scores = charon_ml_bindings_find(&bindings, model->predicted_probabilities_name);
            score_name = model->predicted_probabilities_name;
        }
        if (scores == NULL) {
            /* The scores are the one output that holds one number per class. A network that
             * ends in a global pool leaves them as an array of channels by one by one, which
             * is one number per class written in three dimensions, so a candidate is judged by
             * how many values it has and not by its rank. */
            for (index = 0; index < model->output_count; index++) {
                charon_ml_tensor *candidate = charon_ml_bindings_find(&bindings, model->outputs[index].name);
                if (candidate != NULL && candidate->data != NULL && candidate->count > 1 &&
                    (model->class_label_count == 0 || candidate->count == model->class_label_count)) {
                    scores = candidate;
                    score_name = model->outputs[index].name;
                    break;
                }
            }
        }
        if (scores == NULL || scores->data == NULL || scores->count == 0) {
            charon_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the network produced no scores for its classes");
            return 0;
        }
        numbers = (double *)malloc(scores->count * sizeof *numbers);
        if (numbers == NULL) {
            charon_ml_bindings_release(&bindings);
            return 0;
        }
        for (index = 0; index < scores->count; index++) {
            numbers[index] = scores->data[index];
        }
        /* The scores are answered under their own name first, so a description that names them
         * is answered from the number the network produced, and the label is read off them. */
        if (score_name != NULL) {
            int64_t shape[CHARON_ML_MAX_RANK];
            int rank = answer_shape(model_feature_named(model, score_name), scores->count, shape);
            charon_ml_array array;
            array = charon_ml_array_alloc(CHARON_ML_ARRAY_DOUBLE, shape, rank);
            for (index = 0; index < scores->count; index++) {
                charon_ml_array_set(&array, (int64_t)index, numbers[index]);
            }
            if (!charon_ml_features_put(values, score_name, charon_ml_value_array(array))) {
                free(numbers);
                charon_ml_bindings_release(&bindings);
                snprintf(error, error_size, "the model's answers have no room for '%s'", score_name);
                return 0;
            }
        }
        ok = answer_with_scores(model, numbers, scores->count, values, error, error_size);
        free(numbers);
        charon_ml_bindings_release(&bindings);
        return ok;
    }
    for (index = 0; index < model->output_count; index++) {
        const char *name = model->outputs[index].name;
        charon_ml_tensor *tensor = name != NULL ? charon_ml_bindings_find(&bindings, name) : NULL;
        charon_ml_value value;
        if (tensor == NULL || tensor->data == NULL) {
            continue;
        }
        value = charon_ml_tensor_to_value(tensor, CHARON_ML_ARRAY_FLOAT32);
        /* The tensor carries the shape the layers produced, which is not always the shape the
         * model declared: a layer that squeezes or flattens leaves a rank the description does not
         * name. The declared shape is the one an application reads and the one it built its input
         * for, so where the two hold the same number of elements the declared one is answered. */
        if (model->outputs[index].rank > 0 &&
            charon_ml_count_of_shape(model->outputs[index].shape, model->outputs[index].rank) ==
                (int64_t)value.array.count) {
            charon_ml_array reshaped =
                charon_ml_array_alloc(value.array.data_type, model->outputs[index].shape,
                                      model->outputs[index].rank);
            size_t element;
            for (element = 0; element < reshaped.count && element < value.array.count; element++) {
                charon_ml_array_set(&reshaped, (int64_t)element, charon_ml_array_get(&value.array, (int64_t)element));
            }
            charon_ml_value_free(&value);
            value = charon_ml_value_array(reshaped);
        }
        if (!charon_ml_features_put(values, name, value)) {
            charon_ml_bindings_release(&bindings);
            snprintf(error, error_size, "the model's answers have no room for '%s'", name);
            return 0;
        }
    }
    charon_ml_bindings_release(&bindings);
    return 1;
}

/* One model message run over a set of values. The kind decides; the values are whatever the
 * model wrote, so a pipeline's second model finds the first one's output by name. */
static int run_one(const charon_ml_node *document, const char *bundle, charon_ml_features *values,
                   char *error, size_t error_size)
{
    /* A model is 326 KB of struct and a set of values is 1.1 MB, so neither is an automatic
     * variable here: a device's main thread has a fraction of that, and a pipeline's run_one is
     * recursive, so the stack a pipeline needs is the sum over its stages. The host, whose stack is
     * eight megabytes, never noticed; the emulated iPad 2 faulted on the first prediction. */
    charon_ml_model *model = calloc(1, sizeof *model);
    const char *kind_field = charon_ml_node_kind_name(document);
    const charon_ml_node *kind_node;
    int ok;

    if (kind_field == NULL) {
        snprintf(error, error_size, "the model names no kind of model the specification declares");
        free(model);
        return 0;
    }
    if (!charon_ml_model_from_node(model, document, bundle, error, error_size)) {
        free(model);
        return 0;
    }
    kind_node = charon_ml_get(document, kind_field);
    switch (model->kind) {
    case CHARON_ML_KIND_NEURAL_NETWORK:
    case CHARON_ML_KIND_NEURAL_NETWORK_CLASSIFIER:
    case CHARON_ML_KIND_NEURAL_NETWORK_REGRESSOR:
        ok = run_neural_network(kind_node, model, values, error, error_size);
        break;
    case CHARON_ML_KIND_TREE_ENSEMBLE_CLASSIFIER:
    case CHARON_ML_KIND_TREE_ENSEMBLE_REGRESSOR:
        ok = run_tree_ensemble(kind_node, model, values, values, error, error_size);
        break;
    case CHARON_ML_KIND_GLM_CLASSIFIER:
    case CHARON_ML_KIND_GLM_REGRESSOR:
        ok = run_glm(kind_node, model, values, values, error, error_size);
        break;
    case CHARON_ML_KIND_SCALER:
    case CHARON_ML_KIND_IMPUTER:
    case CHARON_ML_KIND_NORMALIZER:
    case CHARON_ML_KIND_ONE_HOT_ENCODER:
    case CHARON_ML_KIND_IDENTITY:
        ok = run_preprocessing(model, kind_node, values, values, error, error_size);
        break;
    case CHARON_ML_KIND_PIPELINE:
    case CHARON_ML_KIND_PIPELINE_CLASSIFIER:
    case CHARON_ML_KIND_PIPELINE_REGRESSOR: {
        size_t index, total = charon_ml_count_field(kind_node, "models");
        if (total == 0) {
            charon_ml_model_release(model);
            snprintf(error, error_size, "the pipeline has no models in it");
            return 0;
        }
        ok = 1;
        for (index = 0; index < total; index++) {
            char sub_error[512];
            if (!run_one(charon_ml_node_at_field(kind_node, "models", index), bundle, values, sub_error,
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
                 charon_ml_kind_name(model->kind));
        ok = 0;
        break;
    }
    charon_ml_model_release(model);
    return ok;
}

int charon_ml_predict(const charon_ml_model *model, charon_ml_features *inputs,
                      charon_ml_features *outputs, char *error, size_t error_size)
{
    /* The working set is 1.1 MB, so it is on the heap for the same reason run_one's model is. */
    charon_ml_features *working = calloc(1, sizeof *working);
    char missing[256], mismatched[256];
    size_t index;

    if (working == NULL) {
        snprintf(error, error_size, "there was no room for the values a run works in");
        return 0;
    }
    charon_ml_features_init(working);
    if (!charon_ml_features_satisfy(model, inputs, missing, sizeof missing, mismatched, sizeof mismatched)) {
        if (missing[0] != 0) {
            snprintf(error, error_size, "the model needs the input '%s', which is not there", missing);
        } else {
            snprintf(error, error_size, "the model needs the input '%s' to be a different shape or kind",
                     mismatched);
        }
        free(working);
        return 0;
    }
    charon_ml_features_init(working);
    for (index = 0; index < inputs->count; index++) {
        /* The caller's values are borrowed: the set inside is a view of them, not a second
         * owner, so releasing it frees nothing the caller still holds. */
        charon_ml_value borrowed = inputs->entries[index].value;
        borrowed.array.owns_data = 0;
        if (!charon_ml_features_put(working, inputs->entries[index].name, borrowed)) {
            charon_ml_features_release(working);
            free(working);
            snprintf(error, error_size, "the model's inputs have no room for all of them");
            return 0;
        }
    }
    if (!run_one(&model->document, model->bundle, working, error, error_size) ||
        !charon_ml_features_take_outputs(model, working, outputs)) {
        if (error[0] == 0) {
            snprintf(error, error_size, "the model produced no value for one of the outputs it names");
        }
        charon_ml_features_release(working);
        free(working);
        return 0;
    }
    charon_ml_features_release(working);
    free(working);
    return 1;
}
