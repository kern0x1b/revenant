#include "RevenantMLLayerKinds.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void revenant_ml_bindings_init(revenant_ml_bindings *bindings, size_t room)
{
    size_t index;
    bindings->tensors = room ? (revenant_ml_tensor *)calloc(room, sizeof *bindings->tensors) : NULL;
    bindings->names = room ? (char **)calloc(room, sizeof *bindings->names) : NULL;
    bindings->count = 0;
    bindings->room = room;
    for (index = 0; index < room; index++) {
        bindings->names[index] = NULL;
    }
}

void revenant_ml_bindings_release(revenant_ml_bindings *bindings)
{
    size_t index;
    for (index = 0; index < bindings->count; index++) {
        revenant_ml_tensor_free(&bindings->tensors[index]);
        free(bindings->names[index]);
    }
    free(bindings->tensors);
    free(bindings->names);
    bindings->tensors = NULL;
    bindings->names = NULL;
    bindings->count = 0;
    bindings->room = 0;
}

revenant_ml_tensor *revenant_ml_bindings_find(revenant_ml_bindings *bindings, const char *name)
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

int revenant_ml_bindings_put(revenant_ml_bindings *bindings, const char *name, revenant_ml_tensor tensor)
{
    revenant_ml_tensor *existing = revenant_ml_bindings_find(bindings, name);
    if (existing != NULL) {
        revenant_ml_tensor_free(existing);
        *existing = tensor;
        return 1;
    }
    if (bindings->count >= bindings->room) {
        revenant_ml_tensor_free(&tensor);
        return 0;
    }
    bindings->tensors[bindings->count] = tensor;
    bindings->names[bindings->count] = strdup(name != NULL ? name : "");
    bindings->count++;
    return 1;
}

const char *revenant_ml_layer_name(const revenant_ml_node *layer)
{
    static char buffer[256];
    const char *name = revenant_ml_text(revenant_ml_get(layer, "name"), buffer, sizeof buffer);
    return name != NULL ? name : "(unnamed)";
}

int revenant_ml_layer_refuse(const revenant_ml_node *layer, const char *kind, int number, char *error, size_t error_size)
{
    snprintf(error, error_size, "the layer '%s' is a %s, kind %d of the specification's layer oneof, "
                               "which this port does not run",
             revenant_ml_layer_name(layer), kind, number);
    return 0;
}

int revenant_ml_layer_missing_input(const revenant_ml_node *layer, const char *what, char *error,
                                  size_t error_size)
{
    snprintf(error, error_size, "the layer '%s' names an %s that is not there", revenant_ml_layer_name(layer), what);
    return 0;
}

int revenant_ml_layer_bad_shape(const revenant_ml_node *layer, const char *what, const revenant_ml_tensor *found,
                              char *error, size_t error_size)
{
    char described[160];
    revenant_ml_shape_describe(found != NULL ? found->shape : NULL, found != NULL ? found->rank : 0, described,
                             sizeof described);
    snprintf(error, error_size, "the layer '%s' has %s%s%s, which this port cannot use", revenant_ml_layer_name(layer), what,
             described[0] ? " of shape " : "", described);
    return 0;
}

double revenant_ml_number_of(const revenant_ml_node *node, const char *field, double fallback)
{
    return revenant_ml_double(revenant_ml_get(node, field), fallback);
}

int revenant_ml_integer_of(const revenant_ml_node *node, const char *field, int fallback)
{
    return revenant_ml_int(revenant_ml_get(node, field), fallback);
}

int revenant_ml_read_numbers(const revenant_ml_node *params, double **out, size_t *count)
{
    size_t index, total;
    const revenant_ml_node *entry = NULL;
    double *numbers;

    if (params == NULL) {
        return 0;
    }
    total = revenant_ml_count(params);
    for (index = 0; index < total; index++) {
        const revenant_ml_node *candidate = revenant_ml_at(params, index);
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
        size_t values = revenant_ml_count_field(params, "floatValue");
        numbers = (double *)malloc((values + 1) * sizeof *numbers);
        if (numbers == NULL) {
            return 0;
        }
        for (index = 0; index < values; index++) {
            numbers[index] = revenant_ml_double_at(params, "floatValue", index, 0.0);
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
            const revenant_ml_node *quantization = revenant_ml_get(params, "quantization");
            if (quantization != NULL) {
                scale = revenant_ml_number_of(quantization, "scale", 1.0);
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
                numbers[written++] = (double)revenant_ml_half_to_float(half);
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

const char *revenant_ml_name_at(const revenant_ml_node *layer, const char *field, size_t index, char *buffer,
                              size_t size)
{
    const revenant_ml_node *entry = revenant_ml_node_at_field(layer, field, index);
    if (entry == NULL || revenant_ml_text(entry, buffer, size) == NULL) {
        return NULL;
    }
    return buffer;
}

size_t revenant_ml_name_count(const revenant_ml_node *layer, const char *field)
{
    return revenant_ml_count_field(layer, field);
}

int revenant_ml_activation_kind(const revenant_ml_node *params)
{
    size_t index, total = revenant_ml_count(params);
    for (index = 0; index < total; index++) {
        const revenant_ml_node *entry = revenant_ml_at(params, index);
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

double revenant_ml_activate(int kind, double x, const revenant_ml_node *params)
{
    switch (kind) {
    case 5:
        return revenant_ml_number_of(params, "alpha", 1.0) * x + revenant_ml_number_of(params, "beta", 0.0);
    case 10:
        return x > 0.0 ? x : 0.0;
    case 15: {
        double alpha = revenant_ml_number_of(params, "alpha", 0.0);
        return x >= 0.0 ? x : alpha * x;
    }
    case 20: {
        double alpha = revenant_ml_number_of(params, "alpha", 1.0);
        return x > alpha ? x : 0.0;
    }
    case 25: {
        double *slope = NULL;
        size_t count = 0, channel = 0;
        double alpha = 0.0;
        if (revenant_ml_read_numbers(params, &slope, &count) && count > 0) {
            alpha = slope[channel];
            free(slope);
        }
        return x >= 0.0 ? x : alpha * x;
    }
    case 30:
        return tanh(x);
    case 31:
        return revenant_ml_number_of(params, "alpha", 1.0) * tanh(revenant_ml_number_of(params, "beta", 1.0) * x);
    case 40:
        return x >= 0.0 ? 1.0 / (1.0 + exp(-x)) : exp(x) / (1.0 + exp(x));
    case 41:
        return x > revenant_ml_number_of(params, "beta", 0.0) ? 1.0 : 0.0;
    case 50: {
        double alpha = revenant_ml_number_of(params, "alpha", 1.0);
        return x >= 0.0 ? x : alpha * (exp(x) - 1.0);
    }
    case 60:
        return x / (1.0 + fabs(x));
    case 70:
        return x > 30.0 ? x : log1p(exp(x));
    case 71: {
        double alpha = revenant_ml_number_of(params, "alpha", 1.0);
        double beta = revenant_ml_number_of(params, "beta", -30.0);
        return x * alpha > beta ? x : log1p(exp(x * alpha)) / alpha;
    }
    default:
        return x;
    }
}

void revenant_ml_row_major_strides(const int64_t *shape, int rank, int64_t *strides)
{
    int index;
    int64_t stride = 1;
    for (index = rank - 1; index >= 0; index--) {
        strides[index] = stride;
        stride *= shape[index] > 0 ? shape[index] : 1;
    }
}

void revenant_ml_softmax_axis(revenant_ml_tensor *tensor, int axis)
{
    int64_t strides[REVENANT_ML_MAX_RANK];
    int64_t outer = 1, inner, along;
    int index;

    if (axis < 0) {
        axis += tensor->rank;
    }
    if (axis < 0 || axis >= tensor->rank || tensor->data == NULL) {
        return;
    }
    revenant_ml_row_major_strides(tensor->shape, tensor->rank, strides);
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

revenant_ml_tensor revenant_ml_map_unary(const revenant_ml_tensor *input, int kind, const revenant_ml_node *params)
{
    revenant_ml_tensor output = revenant_ml_tensor_make(input->rank, input->shape);
    size_t index;
    if (output.data == NULL) {
        return output;
    }
    for (index = 0; index < input->count && index < output.count; index++) {
        output.data[index] = (float)revenant_ml_activate(kind, (double)input->data[index], params);
    }
    return output;
}

double revenant_ml_apply_binary(int operation, double a, double b, double alpha)
{
    switch (operation) {
    case REVENANT_ML_BINARY_ADD:
        return a + b;
    case REVENANT_ML_BINARY_MULTIPLY:
        return a * b;
    case REVENANT_ML_BINARY_SUBTRACT:
        return a - b;
    case REVENANT_ML_BINARY_DIVIDE:
        return a / b;
    case REVENANT_ML_BINARY_MAX:
        return a > b ? a : b;
    case REVENANT_ML_BINARY_MIN:
        return a < b ? a : b;
    case REVENANT_ML_BINARY_POW:
        return pow(a, b);
    case REVENANT_ML_BINARY_FLOOR_DIV:
        return floor(a / b);
    case REVENANT_ML_BINARY_MOD:
        return fmod(a, b);
    case REVENANT_ML_BINARY_EQUAL:
        return a == b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_NOT_EQUAL:
        return a != b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_LESS:
        return a < b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_LESS_EQUAL:
        return a <= b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_GREATER:
        return a > b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_GREATER_EQUAL:
        return a >= b ? 1.0 : 0.0;
    case REVENANT_ML_BINARY_ADD_ALPHA:
        return a + alpha * b;
    default:
        return a;
    }
}

revenant_ml_tensor revenant_ml_binary(int operation, const revenant_ml_tensor *left, const revenant_ml_tensor *right,
                               double alpha)
{
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK];
    int64_t left_strides[REVENANT_ML_MAX_RANK], right_strides[REVENANT_ML_MAX_RANK];
    int64_t position[REVENANT_ML_MAX_RANK];
    int rank = 0;
    size_t index;
    int axis;

    memset(&output, 0, sizeof output);
    if (left->rank != right->rank ||
        !revenant_ml_broadcast_shape(left->shape, left->rank, right->shape, right->rank, shape, &rank)) {
        return output;
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        return output;
    }
    {
        int64_t base[REVENANT_ML_MAX_RANK];
        revenant_ml_row_major_strides(left->shape, rank, base);
        for (axis = 0; axis < rank; axis++) {
            left_strides[axis] = left->shape[axis] == shape[axis] ? base[axis] : 0;
        }
        revenant_ml_row_major_strides(right->shape, rank, base);
        for (axis = 0; axis < rank; axis++) {
            right_strides[axis] = right->shape[axis] == shape[axis] ? base[axis] : 0;
        }
    }
    for (index = 0; index < output.count; index++) {
        double a, b;
        revenant_ml_unravel((int64_t)index, rank, shape, position);
        a = left->data[revenant_ml_ravel(position, rank, left_strides)];
        b = right->data[revenant_ml_ravel(position, rank, right_strides)];
        output.data[index] = (float)revenant_ml_apply_binary(operation, a, b, alpha);
    }
    return output;
}


static int elementwise(int operation, const revenant_ml_node *layer, revenant_ml_bindings *bindings,
                       char *error, size_t error_size)
{
    char left[256], right[256], output[256];
    revenant_ml_tensor *a, *b, result;
    double alpha = 0.0;

    if (revenant_ml_name_at(layer, "input", 0, left, sizeof left) == NULL ||
        revenant_ml_name_at(layer, "input", 1, right, sizeof right) == NULL) {
        snprintf(error, error_size, "the layer '%s' does not name two inputs", revenant_ml_layer_name(layer));
        return 0;
    }
    if (revenant_ml_name_count(layer, "output") != 1 ||
        revenant_ml_name_at(layer, "output", 0, output, sizeof output) == NULL) {
        snprintf(error, error_size, "the layer '%s' does not name exactly one output", revenant_ml_layer_name(layer));
        return 0;
    }
    a = revenant_ml_bindings_find(bindings, left);
    b = revenant_ml_bindings_find(bindings, right);
    if (a == NULL || b == NULL) {
        snprintf(error, error_size, "the layer '%s' names an input that is not there", revenant_ml_layer_name(layer));
        return 0;
    }
    if (revenant_ml_name_count(layer, "input") > 2) {
        char third[256];
        if (revenant_ml_name_at(layer, "input", 2, third, sizeof third) != NULL &&
            revenant_ml_bindings_find(bindings, third) == NULL) {
            snprintf(error, error_size,
                     "the layer '%s' takes a third input of a shape this port does not carry",
                     revenant_ml_layer_name(layer));
            return 0;
        }
    }
    {
        const revenant_ml_node *params = layer;
        alpha = revenant_ml_number_of(params, "alpha", 0.0);
    }
    result = revenant_ml_binary(operation, a, b, alpha);
    if (result.data == NULL) {
        char described_a[128], described_b[128];
        revenant_ml_shape_describe(a->shape, a->rank, described_a, sizeof described_a);
        revenant_ml_shape_describe(b->shape, b->rank, described_b, sizeof described_b);
        snprintf(error, error_size,
                 "the layer '%s' combines an input of %s with one of %s, which do not combine",
                 revenant_ml_layer_name(layer), described_a, described_b);
        return 0;
    }
    if (!revenant_ml_bindings_put(bindings, output, result)) {
        snprintf(error, error_size, "the layer '%s' writes to a value set with no room left",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    return 1;
}

int revenant_ml_run_layer(const revenant_ml_node *layer, revenant_ml_bindings *bindings, char *error,
                        size_t error_size)
{
    static const struct {
        int number;
        revenant_ml_layer_fn run;
    } carried[] = {
        {100, revenant_ml_layer_convolution}, {120, revenant_ml_layer_pooling},
        {130, revenant_ml_layer_activation}, {140, revenant_ml_layer_inner_product},
        {150, revenant_ml_layer_embedding}, {160, revenant_ml_layer_batchnorm},
        {165, revenant_ml_layer_mvn}, {170, revenant_ml_layer_l2normalize},
        {175, revenant_ml_layer_softmax}, {180, revenant_ml_layer_lrn},
        {200, revenant_ml_layer_padding}, {210, revenant_ml_layer_upsample},
        {245, revenant_ml_layer_scale}, {250, revenant_ml_layer_bias},
        {270, revenant_ml_layer_dot}, {280, revenant_ml_layer_reduce},
        {290, revenant_ml_layer_load_constant}, {300, revenant_ml_layer_reshape},
        {301, revenant_ml_layer_flatten}, {310, revenant_ml_layer_permute},
        {320, revenant_ml_layer_concat}, {330, revenant_ml_layer_split},
        {345, revenant_ml_layer_reorganize}, {350, revenant_ml_layer_slice},
        {400, revenant_ml_layer_simple_recurrent}, {600, revenant_ml_layer_copy},
        {660, revenant_ml_layer_clip}, {920, revenant_ml_layer_tile},
        {985, revenant_ml_layer_transpose}, {1120, revenant_ml_layer_squeeze},
        {1125, revenant_ml_layer_expand_dims}, {0, NULL}};

    size_t index, total = revenant_ml_count(layer);
    const revenant_ml_node *kind = NULL;
    int which;

    for (index = 0; index < total; index++) {
        const revenant_ml_node *entry = revenant_ml_at(layer, index);
        unsigned flags = entry->field->flags & ~REVENANT_ML_REPEATED;
        if (flags != 0 && flags >= REVENANT_ML_ONEOF(0)) {
            kind = entry;
            break;
        }
    }
    if (kind == NULL) {
        snprintf(error, error_size, "the layer '%s' names no kind of layer", revenant_ml_layer_name(layer));
        return 0;
    }
    for (which = 0; carried[which].run != NULL; which++) {
        if (carried[which].number == kind->field->number) {
            return carried[which].run(layer, kind, bindings, error, error_size);
        }
    }
    switch (kind->field->number) {
    case 665: case 670: case 680: case 685: case 700: case 710: case 715: case 720:
    case 730: case 735: case 740: case 750: case 755: case 760: case 770: case 775:
    case 780: case 790: case 795:
        return revenant_ml_layer_unary_math(layer, kind, bindings, error, error_size);
    case 230:
        return elementwise(REVENANT_ML_BINARY_ADD, layer, bindings, error, error_size);
    case 231:
        return elementwise(REVENANT_ML_BINARY_MULTIPLY, layer, bindings, error, error_size);
    case 240:
        return elementwise(REVENANT_ML_BINARY_ADD_ALPHA, layer, bindings, error, error_size);
    case 260:
        return elementwise(REVENANT_ML_BINARY_MAX, layer, bindings, error, error_size);
    case 261:
        return elementwise(REVENANT_ML_BINARY_MIN, layer, bindings, error, error_size);
    case 815:
        return elementwise(REVENANT_ML_BINARY_EQUAL, layer, bindings, error, error_size);
    case 820:
        return elementwise(REVENANT_ML_BINARY_NOT_EQUAL, layer, bindings, error, error_size);
    case 825:
        return elementwise(REVENANT_ML_BINARY_LESS, layer, bindings, error, error_size);
    case 827:
        return elementwise(REVENANT_ML_BINARY_LESS_EQUAL, layer, bindings, error, error_size);
    case 830:
        return elementwise(REVENANT_ML_BINARY_GREATER, layer, bindings, error, error_size);
    case 832:
        return elementwise(REVENANT_ML_BINARY_GREATER_EQUAL, layer, bindings, error, error_size);
    case 865:
        return elementwise(REVENANT_ML_BINARY_MOD, layer, bindings, error, error_size);
    case 870:
        return elementwise(REVENANT_ML_BINARY_MIN, layer, bindings, error, error_size);
    case 875:
        return elementwise(REVENANT_ML_BINARY_MAX, layer, bindings, error, error_size);
    case 880:
        return elementwise(REVENANT_ML_BINARY_ADD, layer, bindings, error, error_size);
    case 885:
        return elementwise(REVENANT_ML_BINARY_POW, layer, bindings, error, error_size);
    case 890:
        return elementwise(REVENANT_ML_BINARY_DIVIDE, layer, bindings, error, error_size);
    case 895:
        return elementwise(REVENANT_ML_BINARY_FLOOR_DIV, layer, bindings, error, error_size);
    case 900:
        return elementwise(REVENANT_ML_BINARY_MULTIPLY, layer, bindings, error, error_size);
    case 905:
        return elementwise(REVENANT_ML_BINARY_SUBTRACT, layer, bindings, error, error_size);
    default:
        break;
    }
    return revenant_ml_layer_refuse(layer, kind->field->name, kind->field->number, error, error_size);
}
