/* The layers of a Core ML neural network, each one as the specification describes it.
 * CharonMLLayers.h says what it is for; this is the layer by layer reading of it.
 *
 * A layer's kind is the case of the specification's NeuralNetworkLayer oneof the document
 * carries, and the field number of that case is what the dispatch at the bottom is written
 * against: 100 is convolution, 140 is an inner product, 175 a softmax, by the specification's
 * own numbering rather than by a name matched at run time. A kind this file does not carry is
 * refused by name and number, so the caller can say which one it is -- a network that quietly
 * skipped a layer would answer something other than what the model says.
 */
#include "CharonMLLayerKinds.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* --- the bindings ---------------------------------------------------------------------------- */

void charon_ml_bindings_init(charon_ml_bindings *bindings, size_t room)
{
    size_t index;
    bindings->tensors = room ? (charon_ml_tensor *)calloc(room, sizeof *bindings->tensors) : NULL;
    bindings->names = room ? (char **)calloc(room, sizeof *bindings->names) : NULL;
    bindings->count = 0;
    bindings->room = room;
    for (index = 0; index < room; index++) {
        bindings->names[index] = NULL;
    }
}

void charon_ml_bindings_release(charon_ml_bindings *bindings)
{
    size_t index;
    for (index = 0; index < bindings->count; index++) {
        charon_ml_tensor_free(&bindings->tensors[index]);
        free(bindings->names[index]);
    }
    free(bindings->tensors);
    free(bindings->names);
    bindings->tensors = NULL;
    bindings->names = NULL;
    bindings->count = 0;
    bindings->room = 0;
}

charon_ml_tensor *charon_ml_bindings_find(charon_ml_bindings *bindings, const char *name)
{
    size_t index;
    if (name == NULL) {
        return NULL;
    }
    for (index = 0; index < bindings->count; index++) {
        if (bindings->names[index] != NULL && strcmp(bindings->names[index], name) == 0) {
            return &bindings->tensors[index];
        }
    }
    return NULL;
}

int charon_ml_bindings_put(charon_ml_bindings *bindings, const char *name, charon_ml_tensor tensor)
{
    charon_ml_tensor *existing = charon_ml_bindings_find(bindings, name);
    if (existing != NULL) {
        /* A name written twice is the later value: a network's output may share a name with an
         * intermediate, and the last layer to write it is the one that counts. */
        charon_ml_tensor_free(existing);
        *existing = tensor;
        return 1;
    }
    if (bindings->count >= bindings->room) {
        charon_ml_tensor_free(&tensor);
        return 0;
    }
    bindings->tensors[bindings->count] = tensor;
    bindings->names[bindings->count] = strdup(name != NULL ? name : "");
    bindings->count++;
    return 1;
}

/* --- reading the specification's own messages -------------------------------------------------- */

const char *charon_ml_layer_name(const charon_ml_node *layer)
{
    static char buffer[256];
    const char *name = charon_ml_text(charon_ml_get(layer, "name"), buffer, sizeof buffer);
    return name != NULL ? name : "(unnamed)";
}

/* A layer that cannot be run: the error names the layer, the kind and the specification's
 * number for that kind, so an application is told what is missing rather than only that
 * something is. */
int charon_ml_layer_refuse(const charon_ml_node *layer, const char *kind, int number, char *error, size_t error_size)
{
    snprintf(error, error_size, "the layer '%s' is a %s, kind %d of the specification's layer oneof, "
                               "which this port does not run",
             charon_ml_layer_name(layer), kind, number);
    return 0;
}

/* A layer that names an input no earlier layer wrote: the name is in the message, because
 * which name is missing is what tells a caller what to fix. */
int charon_ml_layer_missing_input(const charon_ml_node *layer, const char *what, char *error,
                                  size_t error_size)
{
    snprintf(error, error_size, "the layer '%s' names an %s that is not there", charon_ml_layer_name(layer), what);
    return 0;
}

/* A layer whose inputs or outputs are not the shape the layer needs: the error names the
 * layer and the shapes, because "a convolution failed" says nothing an application can act on. */
int charon_ml_layer_bad_shape(const charon_ml_node *layer, const char *what, const charon_ml_tensor *found,
                              char *error, size_t error_size)
{
    char described[160];
    charon_ml_shape_describe(found != NULL ? found->shape : NULL, found != NULL ? found->rank : 0, described,
                             sizeof described);
    snprintf(error, error_size, "the layer '%s' has %s%s%s, which this port cannot use", charon_ml_layer_name(layer), what,
             described[0] ? " of shape " : "", described);
    return 0;
}

double charon_ml_number_of(const charon_ml_node *node, const char *field, double fallback)
{
    return charon_ml_double(charon_ml_get(node, field), fallback);
}

int charon_ml_integer_of(const charon_ml_node *node, const char *field, int fallback)
{
    return charon_ml_int(charon_ml_get(node, field), fallback);
}

/* The numbers of a weights field, out of whichever case of its oneof the document holds. The
 * cases are four ways of writing the same numbers -- packed floats, packed halves, the same
 * as bytes, or 8-bit integers beside a scale -- and a converter picks between them, so the
 * case is read and not assumed. `out` is malloc'd and the caller frees it. */
int charon_ml_read_numbers(const charon_ml_node *params, double **out, size_t *count)
{
    size_t index, total;
    const charon_ml_node *entry = NULL;
    double *numbers;

    if (params == NULL) {
        return 0;
    }
    total = charon_ml_count(params);
    for (index = 0; index < total; index++) {
        const charon_ml_node *candidate = charon_ml_at(params, index);
        const char *name = candidate->field->name;
        if (strcmp(name, "floatValue") == 0 || strcmp(name, "float16Value") == 0 ||
            strcmp(name, "rawValue") == 0 || strcmp(name, "int8RawValue") == 0) {
            entry = candidate;
            break;
        }
    }
    if (entry == NULL) {
        return 0;
    }
    if (strcmp(entry->field->name, "floatValue") == 0) {
        size_t values = charon_ml_count_field(params, "floatValue");
        numbers = (double *)malloc((values + 1) * sizeof *numbers);
        if (numbers == NULL) {
            return 0;
        }
        for (index = 0; index < values; index++) {
            numbers[index] = charon_ml_double_at(params, "floatValue", index, 0.0);
        }
        *out = numbers;
        *count = values;
        return 1;
    }
    {
        const unsigned char *bytes = (const unsigned char *)entry->value.text.bytes;
        size_t length = entry->value.text.length, stride = 1, at, written = 0;
        double scale = 1.0;
        if (strcmp(entry->field->name, "float16Value") == 0) {
            stride = 2;
        } else if (strcmp(entry->field->name, "rawValue") == 0) {
            stride = 4;
        } else {
            const charon_ml_node *quantization = charon_ml_get(params, "quantization");
            if (quantization != NULL) {
                scale = charon_ml_number_of(quantization, "scale", 1.0);
            }
        }
        numbers = (double *)malloc((length / stride + 1) * sizeof *numbers);
        if (numbers == NULL) {
            return 0;
        }
        for (at = 0; at + stride <= length; at += stride) {
            if (stride == 1) {
                numbers[written++] = scale * (double)(int8_t)bytes[at];
            } else if (stride == 2) {
                uint16_t half = (uint16_t)((uint16_t)bytes[at] | ((uint16_t)bytes[at + 1] << 8));
                numbers[written++] = (double)charon_ml_half_to_float(half);
            } else {
                uint32_t bits = (uint32_t)bytes[at] | ((uint32_t)bytes[at + 1] << 8) |
                                ((uint32_t)bytes[at + 2] << 16) | ((uint32_t)bytes[at + 3] << 24);
                float value;
                memcpy(&value, &bits, sizeof value);
                numbers[written++] = (double)value;
            }
        }
        *out = numbers;
        *count = written;
        return 1;
    }
}

/* The name of an input or an output, copied out into the caller's buffer: a layer reads
 * several names in a row and one buffer per name would overwrite the last with the last. */
const char *charon_ml_name_at(const charon_ml_node *layer, const char *field, size_t index, char *buffer,
                              size_t size)
{
    const charon_ml_node *entry = charon_ml_node_at_field(layer, field, index);
    if (entry == NULL || charon_ml_text(entry, buffer, size) == NULL) {
        return NULL;
    }
    return buffer;
}

size_t charon_ml_name_count(const charon_ml_node *layer, const char *field)
{
    return charon_ml_count_field(layer, field);
}

/* --- the arithmetic the layers share ----------------------------------------------------------- */

/* The activation cases of the specification's ActivationParams oneof, by their own numbers. */
int charon_ml_activation_kind(const charon_ml_node *params)
{
    size_t index, total = charon_ml_count(params);
    for (index = 0; index < total; index++) {
        const charon_ml_node *entry = charon_ml_at(params, index);
        if (strcmp(entry->field->name, "linear") == 0) {
            return 5;
        }
        if (strcmp(entry->field->name, "ReLU") == 0) {
            return 10;
        }
        if (strcmp(entry->field->name, "leakyReLU") == 0) {
            return 15;
        }
        if (strcmp(entry->field->name, "thresholdedReLU") == 0) {
            return 20;
        }
        if (strcmp(entry->field->name, "PReLU") == 0) {
            return 25;
        }
        if (strcmp(entry->field->name, "tanh") == 0) {
            return 30;
        }
        if (strcmp(entry->field->name, "scaledTanh") == 0) {
            return 31;
        }
        if (strcmp(entry->field->name, "sigmoid") == 0) {
            return 40;
        }
        if (strcmp(entry->field->name, "sigmoidHard") == 0) {
            return 41;
        }
        if (strcmp(entry->field->name, "ELU") == 0) {
            return 50;
        }
        if (strcmp(entry->field->name, "softsign") == 0) {
            return 60;
        }
        if (strcmp(entry->field->name, "softplus") == 0) {
            return 70;
        }
        if (strcmp(entry->field->name, "parametricSoftplus") == 0) {
            return 71;
        }
    }
    return 0;
}

double charon_ml_activate(int kind, double x, const charon_ml_node *params)
{
    switch (kind) {
    case 5:
        return charon_ml_number_of(params, "alpha", 1.0) * x + charon_ml_number_of(params, "beta", 0.0);
    case 10:
        return x > 0.0 ? x : 0.0;
    case 15: {
        double alpha = charon_ml_number_of(params, "alpha", 0.0);
        return x >= 0.0 ? x : alpha * x;
    }
    case 20: {
        double alpha = charon_ml_number_of(params, "alpha", 1.0);
        return x > alpha ? x : 0.0;
    }
    case 25: {
        double *slope = NULL;
        size_t count = 0, channel = 0;
        double alpha = 0.0;
        if (charon_ml_read_numbers(params, &slope, &count) && count > 0) {
            alpha = slope[channel];
            free(slope);
        }
        return x >= 0.0 ? x : alpha * x;
    }
    case 30:
        return tanh(x);
    case 31:
        return charon_ml_number_of(params, "alpha", 1.0) * tanh(charon_ml_number_of(params, "beta", 1.0) * x);
    case 40:
        /* The logistic 1/(1+e^-x), with the two halves each written so that neither
         * exponential overflows: e^-x above zero, e^x below. */
        return x >= 0.0 ? 1.0 / (1.0 + exp(-x)) : exp(x) / (1.0 + exp(x));
    case 41:
        return x > charon_ml_number_of(params, "beta", 0.0) ? 1.0 : 0.0;
    case 50: {
        double alpha = charon_ml_number_of(params, "alpha", 1.0);
        return x >= 0.0 ? x : alpha * (exp(x) - 1.0);
    }
    case 60:
        return x / (1.0 + fabs(x));
    case 70:
        return x > 30.0 ? x : log1p(exp(x));
    case 71: {
        double alpha = charon_ml_number_of(params, "alpha", 1.0);
        double beta = charon_ml_number_of(params, "beta", -30.0);
        return x * alpha > beta ? x : log1p(exp(x * alpha)) / alpha;
    }
    default:
        return x;
    }
}

void charon_ml_row_major_strides(const int64_t *shape, int rank, int64_t *strides)
{
    int index;
    int64_t stride = 1;
    for (index = rank - 1; index >= 0; index--) {
        strides[index] = stride;
        stride *= shape[index] > 0 ? shape[index] : 1;
    }
}

/* A softmax along one axis, as CoreML's softmax layer does it: the largest value on the axis
 * is taken out first, so that no exponential of it can overflow, and the sum is over the same
 * exponentials. */
void charon_ml_softmax_axis(charon_ml_tensor *tensor, int axis)
{
    int64_t strides[CHARON_ML_MAX_RANK];
    int64_t outer = 1, inner, along;
    int index;

    if (axis < 0) {
        axis += tensor->rank;
    }
    if (axis < 0 || axis >= tensor->rank || tensor->data == NULL) {
        return;
    }
    charon_ml_row_major_strides(tensor->shape, tensor->rank, strides);
    for (index = 0; index < axis; index++) {
        outer *= tensor->shape[index];
    }
    inner = axis + 1 < tensor->rank ? strides[axis + 1] : 1;
    for (along = 0; along < outer; along++) {
        int64_t base = along * inner, at, count = tensor->shape[axis], step = strides[axis];
        double largest = -HUGE_VAL, total = 0.0;
        for (at = 0; at < count; at++) {
            double value = tensor->data[base + at * step];
            if (value > largest) {
                largest = value;
            }
        }
        for (at = 0; at < count; at++) {
            double value = exp((double)tensor->data[base + at * step] - largest);
            tensor->data[base + at * step] = (float)value;
            total += value;
        }
        if (total == 0.0) {
            for (at = 0; at < count; at++) {
                tensor->data[base + at * step] = 0.0f;
            }
            continue;
        }
        for (at = 0; at < count; at++) {
            tensor->data[base + at * step] = (float)(tensor->data[base + at * step] / total);
        }
    }
}

/* The activation of every value of a tensor, into a new one of the same shape. */
charon_ml_tensor charon_ml_map_unary(const charon_ml_tensor *input, int kind, const charon_ml_node *params)
{
    charon_ml_tensor output = charon_ml_tensor_make(input->rank, input->shape);
    size_t index;
    if (output.data == NULL) {
        return output;
    }
    for (index = 0; index < input->count && index < output.count; index++) {
        output.data[index] = (float)charon_ml_activate(kind, (double)input->data[index], params);
    }
    return output;
}

double charon_ml_apply_binary(int operation, double a, double b, double alpha)
{
    switch (operation) {
    case CHARON_ML_BINARY_ADD:
        return a + b;
    case CHARON_ML_BINARY_MULTIPLY:
        return a * b;
    case CHARON_ML_BINARY_SUBTRACT:
        return a - b;
    case CHARON_ML_BINARY_DIVIDE:
        return a / b;
    case CHARON_ML_BINARY_MAX:
        return a > b ? a : b;
    case CHARON_ML_BINARY_MIN:
        return a < b ? a : b;
    case CHARON_ML_BINARY_POW:
        return pow(a, b);
    case CHARON_ML_BINARY_FLOOR_DIV:
        return floor(a / b);
    case CHARON_ML_BINARY_MOD:
        return fmod(a, b);
    case CHARON_ML_BINARY_EQUAL:
        return a == b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_NOT_EQUAL:
        return a != b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_LESS:
        return a < b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_LESS_EQUAL:
        return a <= b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_GREATER:
        return a > b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_GREATER_EQUAL:
        return a >= b ? 1.0 : 0.0;
    case CHARON_ML_BINARY_ADD_ALPHA:
        return a + alpha * b;
    default:
        return a;
    }
}

charon_ml_tensor charon_ml_binary(int operation, const charon_ml_tensor *left, const charon_ml_tensor *right,
                               double alpha)
{
    charon_ml_tensor output;
    int64_t shape[CHARON_ML_MAX_RANK];
    int64_t left_strides[CHARON_ML_MAX_RANK], right_strides[CHARON_ML_MAX_RANK];
    int64_t position[CHARON_ML_MAX_RANK];
    int rank = 0;
    size_t index;
    int axis;

    memset(&output, 0, sizeof output);
    if (left->rank != right->rank ||
        !charon_ml_broadcast_shape(left->shape, left->rank, right->shape, right->rank, shape, &rank)) {
        return output;
    }
    output = charon_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        return output;
    }
    /* A dimension of 1 in an operand gets a stride of 0, which is what stretches that
     * operand's single value along the whole dimension. */
    {
        int64_t base[CHARON_ML_MAX_RANK];
        charon_ml_row_major_strides(left->shape, rank, base);
        for (axis = 0; axis < rank; axis++) {
            left_strides[axis] = left->shape[axis] == shape[axis] ? base[axis] : 0;
        }
        charon_ml_row_major_strides(right->shape, rank, base);
        for (axis = 0; axis < rank; axis++) {
            right_strides[axis] = right->shape[axis] == shape[axis] ? base[axis] : 0;
        }
    }
    for (index = 0; index < output.count; index++) {
        double a, b;
        charon_ml_unravel((int64_t)index, rank, shape, position);
        a = left->data[charon_ml_ravel(position, rank, left_strides)];
        b = right->data[charon_ml_ravel(position, rank, right_strides)];
        output.data[index] = (float)charon_ml_apply_binary(operation, a, b, alpha);
    }
    return output;
}


/* The two-input elementwise layers: the plain ones read two tensors, the broadcastable ones
 * read shapes that differ by dimensions of one, which the binary operation already stretches.
 * A layer the port cannot combine says so rather than reading past an end. */
static int elementwise(int operation, const charon_ml_node *layer, charon_ml_bindings *bindings,
                       char *error, size_t error_size)
{
    char left[256], right[256], output[256];
    charon_ml_tensor *a, *b, result;
    double alpha = 0.0;

    if (charon_ml_name_at(layer, "input", 0, left, sizeof left) == NULL ||
        charon_ml_name_at(layer, "input", 1, right, sizeof right) == NULL) {
        snprintf(error, error_size, "the layer '%s' does not name two inputs", charon_ml_layer_name(layer));
        return 0;
    }
    if (charon_ml_name_count(layer, "output") != 1 ||
        charon_ml_name_at(layer, "output", 0, output, sizeof output) == NULL) {
        snprintf(error, error_size, "the layer '%s' does not name exactly one output", charon_ml_layer_name(layer));
        return 0;
    }
    a = charon_ml_bindings_find(bindings, left);
    b = charon_ml_bindings_find(bindings, right);
    if (a == NULL || b == NULL) {
        snprintf(error, error_size, "the layer '%s' names an input that is not there", charon_ml_layer_name(layer));
        return 0;
    }
    /* The specification gives some of these layers a third input, the other operand of a
     * combination such as a + alpha*b where it is a number rather than a whole array. This
     * port takes that shape as not carried, and says so, rather than reading a tensor's first
     * value as though the model had written a number there. */
    if (charon_ml_name_count(layer, "input") > 2) {
        char third[256];
        if (charon_ml_name_at(layer, "input", 2, third, sizeof third) != NULL &&
            charon_ml_bindings_find(bindings, third) == NULL) {
            snprintf(error, error_size,
                     "the layer '%s' takes a third input of a shape this port does not carry",
                     charon_ml_layer_name(layer));
            return 0;
        }
    }
    {
        const charon_ml_node *params = layer;
        alpha = charon_ml_number_of(params, "alpha", 0.0);
    }
    result = charon_ml_binary(operation, a, b, alpha);
    if (result.data == NULL) {
        char described_a[128], described_b[128];
        charon_ml_shape_describe(a->shape, a->rank, described_a, sizeof described_a);
        charon_ml_shape_describe(b->shape, b->rank, described_b, sizeof described_b);
        snprintf(error, error_size,
                 "the layer '%s' combines an input of %s with one of %s, which do not combine",
                 charon_ml_layer_name(layer), described_a, described_b);
        return 0;
    }
    if (!charon_ml_bindings_put(bindings, output, result)) {
        snprintf(error, error_size, "the layer '%s' writes to a value set with no room left",
                 charon_ml_layer_name(layer));
        return 0;
    }
    return 1;
}

/* --- the dispatch ------------------------------------------------------------------------------ */

/* The kinds this port runs, by the field number of the case of the specification's
 * NeuralNetworkLayer oneof that is the kind. A number not listed is a kind the port does not
 * carry, and is refused with its name read off the field itself. */
int charon_ml_run_layer(const charon_ml_node *layer, charon_ml_bindings *bindings, char *error,
                        size_t error_size)
{
    static const struct {
        int number;
        charon_ml_layer_fn run;
    } carried[] = {
        {100, charon_ml_layer_convolution}, {120, charon_ml_layer_pooling},
        {130, charon_ml_layer_activation}, {140, charon_ml_layer_inner_product},
        {150, charon_ml_layer_embedding}, {160, charon_ml_layer_batchnorm},
        {165, charon_ml_layer_mvn}, {170, charon_ml_layer_l2normalize},
        {175, charon_ml_layer_softmax}, {180, charon_ml_layer_lrn},
        {200, charon_ml_layer_padding}, {210, charon_ml_layer_upsample},
        {245, charon_ml_layer_scale}, {250, charon_ml_layer_bias},
        {270, charon_ml_layer_dot}, {280, charon_ml_layer_reduce},
        {290, charon_ml_layer_load_constant}, {300, charon_ml_layer_reshape},
        {301, charon_ml_layer_flatten}, {310, charon_ml_layer_permute},
        {320, charon_ml_layer_concat}, {330, charon_ml_layer_split},
        {345, charon_ml_layer_reorganize}, {350, charon_ml_layer_slice},
        {400, charon_ml_layer_simple_recurrent}, {600, charon_ml_layer_copy},
        {660, charon_ml_layer_clip}, {920, charon_ml_layer_tile},
        {985, charon_ml_layer_transpose}, {1120, charon_ml_layer_squeeze},
        {1125, charon_ml_layer_expand_dims}, {0, NULL}};

    size_t index, total = charon_ml_count(layer);
    const charon_ml_node *kind = NULL;
    int which;

    for (index = 0; index < total; index++) {
        const charon_ml_node *entry = charon_ml_at(layer, index);
        unsigned flags = entry->field->flags & ~CHARON_ML_REPEATED;
        /* The name, the input and output lists and the weight fields are not the kind: the kind
         * is a case of the oneof, and the oneof's cases carry a oneof flag. */
        if (flags != 0 && flags >= CHARON_ML_ONEOF(0)) {
            kind = entry;
            break;
        }
    }
    if (kind == NULL) {
        snprintf(error, error_size, "the layer '%s' names no kind of layer", charon_ml_layer_name(layer));
        return 0;
    }
    for (which = 0; carried[which].run != NULL; which++) {
        if (carried[which].number == kind->field->number) {
            return carried[which].run(layer, kind, bindings, error, error_size);
        }
    }
    switch (kind->field->number) {
    /* The mathematics layers, one function over the case that names them. */
    case 665: case 670: case 680: case 685: case 700: case 710: case 715: case 720:
    case 730: case 735: case 740: case 750: case 755: case 760: case 770: case 775:
    case 780: case 790: case 795:
        return charon_ml_layer_unary_math(layer, kind, bindings, error, error_size);
    /* The two-input elementwise layers, the plain and the broadcasting kinds alike. */
    case 230:
        return elementwise(CHARON_ML_BINARY_ADD, layer, bindings, error, error_size);
    case 231:
        return elementwise(CHARON_ML_BINARY_MULTIPLY, layer, bindings, error, error_size);
    case 240:
        return elementwise(CHARON_ML_BINARY_ADD_ALPHA, layer, bindings, error, error_size);
    case 260:
        return elementwise(CHARON_ML_BINARY_MAX, layer, bindings, error, error_size);
    case 261:
        return elementwise(CHARON_ML_BINARY_MIN, layer, bindings, error, error_size);
    case 815:
        return elementwise(CHARON_ML_BINARY_EQUAL, layer, bindings, error, error_size);
    case 820:
        return elementwise(CHARON_ML_BINARY_NOT_EQUAL, layer, bindings, error, error_size);
    case 825:
        return elementwise(CHARON_ML_BINARY_LESS, layer, bindings, error, error_size);
    case 827:
        return elementwise(CHARON_ML_BINARY_LESS_EQUAL, layer, bindings, error, error_size);
    case 830:
        return elementwise(CHARON_ML_BINARY_GREATER, layer, bindings, error, error_size);
    case 832:
        return elementwise(CHARON_ML_BINARY_GREATER_EQUAL, layer, bindings, error, error_size);
    case 865:
        return elementwise(CHARON_ML_BINARY_MOD, layer, bindings, error, error_size);
    case 870:
        return elementwise(CHARON_ML_BINARY_MIN, layer, bindings, error, error_size);
    case 875:
        return elementwise(CHARON_ML_BINARY_MAX, layer, bindings, error, error_size);
    case 880:
        return elementwise(CHARON_ML_BINARY_ADD, layer, bindings, error, error_size);
    case 885:
        return elementwise(CHARON_ML_BINARY_POW, layer, bindings, error, error_size);
    case 890:
        return elementwise(CHARON_ML_BINARY_DIVIDE, layer, bindings, error, error_size);
    case 895:
        return elementwise(CHARON_ML_BINARY_FLOOR_DIV, layer, bindings, error, error_size);
    case 900:
        return elementwise(CHARON_ML_BINARY_MULTIPLY, layer, bindings, error, error_size);
    case 905:
        return elementwise(CHARON_ML_BINARY_SUBTRACT, layer, bindings, error, error_size);
    default:
        break;
    }
    return charon_ml_layer_refuse(layer, kind->field->name, kind->field->number, error, error_size);
}
