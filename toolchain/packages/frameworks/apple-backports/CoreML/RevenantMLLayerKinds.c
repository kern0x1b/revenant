#include "RevenantMLLayerKinds.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

revenant_ml_tensor *revenant_ml_input(revenant_ml_bindings *bindings, const revenant_ml_node *layer)
{
    char name[256];
    if (revenant_ml_name_count(layer, "input") != 1) {
        return NULL;
    }
    if (revenant_ml_name_at(layer, "input", 0, name, sizeof name) == NULL) {
        return NULL;
    }
    return revenant_ml_bindings_find(bindings, name);
}

static int take_output(const revenant_ml_node *layer, revenant_ml_bindings *bindings, revenant_ml_tensor tensor,
                       char *error, size_t error_size)
{
    char name[256];
    if (revenant_ml_name_count(layer, "output") != 1 ||
        revenant_ml_name_at(layer, "output", 0, name, sizeof name) == NULL) {
        revenant_ml_tensor_free(&tensor);
        snprintf(error, error_size, "the layer '%s' does not name exactly one output", revenant_ml_layer_name(layer));
        return 0;
    }
    if (!revenant_ml_bindings_put(bindings, name, tensor)) {
        snprintf(error, error_size, "the layer '%s' writes to a value set with no room left", revenant_ml_layer_name(layer));
        return 0;
    }
    return 1;
}

typedef enum { REVENANT_ML_PAD_VALID = 0, REVENANT_ML_PAD_SAME } revenant_ml_pad_kind;

static int read_padding(const revenant_ml_node *params, revenant_ml_pad_kind *kind, int64_t pad[4])
{
    const revenant_ml_node *valid = revenant_ml_get(params, "valid");
    const revenant_ml_node *same = revenant_ml_get(params, "same");
    int index;
    for (index = 0; index < 4; index++) {
        pad[index] = 0;
    }
    if (valid != NULL) {
        *kind = REVENANT_ML_PAD_VALID;
        {
            const revenant_ml_node *amounts = revenant_ml_get(valid, "paddingAmounts");
            const revenant_ml_node *edges = revenant_ml_node_at_field(amounts, "borderAmounts", 0);
            const revenant_ml_node *across = revenant_ml_node_at_field(amounts, "borderAmounts", 1);
            pad[0] = revenant_ml_int_at(edges, "startEdgeSize", 0, 0);
            pad[1] = revenant_ml_int_at(edges, "endEdgeSize", 0, 0);
            pad[2] = revenant_ml_int_at(across, "startEdgeSize", 0, 0);
            pad[3] = revenant_ml_int_at(across, "endEdgeSize", 0, 0);
        }
        return 1;
    }
    if (same != NULL) {
        *kind = REVENANT_ML_PAD_SAME;
        return 1;
    }
    *kind = REVENANT_ML_PAD_VALID;
    return 1;
}

static int64_t same_padding(int64_t size, int64_t kernel, int64_t stride, int end)
{
    int64_t out = (size + stride - 1) / stride;
    int64_t total = out * stride - size + kernel - 1;
    return end ? (total + 1) / 2 : total / 2;
}

int revenant_ml_layer_convolution(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double *weights = NULL, *bias = NULL;
    size_t weight_count = 0, bias_count = 0;
    int64_t kernel[2], stride[2], dilation[2], pad[4], shape[3];
    int out_channels, groups, has_bias, channels, index;
    revenant_ml_tensor output;

    for (index = 0; index < 4; index++) {
        pad[index] = 0;
    }
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank != 3) {
        return revenant_ml_layer_bad_shape(layer, "an input that is not channels by height by width", input,
                                         error, error_size);
    }
    out_channels = revenant_ml_integer_of(params, "outputChannels", 0);
    groups = revenant_ml_integer_of(params, "nGroups", 1);
    has_bias = revenant_ml_integer_of(params, "hasBias", 0) != 0;
    kernel[0] = revenant_ml_int_at(params, "kernelSize", 0, 1);
    kernel[1] = kernel[0] == revenant_ml_int_at(params, "kernelSize", 0, 1)
                   ? revenant_ml_int_at(params, "kernelSize", 1, kernel[0])
                   : kernel[0];
    stride[0] = revenant_ml_int_at(params, "stride", 0, 1);
    stride[1] = revenant_ml_int_at(params, "stride", 1, stride[0]);
    dilation[0] = revenant_ml_int_at(params, "dilationFactor", 0, 1);
    dilation[1] = revenant_ml_int_at(params, "dilationFactor", 1, dilation[0]);
    {
        revenant_ml_pad_kind how;
        read_padding(params, &how, pad);
        if (how == REVENANT_ML_PAD_SAME) {
            pad[0] = same_padding(input->shape[1], kernel[0], stride[0], 0);
            pad[1] = same_padding(input->shape[1], kernel[0], stride[0], 1);
            pad[2] = same_padding(input->shape[2], kernel[1], stride[1], 0);
            pad[3] = same_padding(input->shape[2], kernel[1], stride[1], 1);
        }
    }
    if (out_channels <= 0 || groups <= 0 || stride[0] <= 0 || stride[1] <= 0 || kernel[0] <= 0 ||
        kernel[1] <= 0 || dilation[0] <= 0 || dilation[1] <= 0) {
        snprintf(error, error_size, "the layer '%s' has a kernel, a stride or a channel count of no length",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    channels = (int)input->shape[0];
    if (channels % groups != 0 || out_channels % groups != 0) {
        snprintf(error, error_size,
                 "the layer '%s' has %d input channels and %d output channels over %d groups, which do not divide",
                 revenant_ml_layer_name(layer), channels, out_channels, groups);
        return 0;
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "weights"), &weights, &weight_count) ||
        (size_t)(out_channels * channels / groups) * (size_t)kernel[0] * (size_t)kernel[1] != weight_count) {
        free(weights);
        snprintf(error, error_size,
                 "the layer '%s' has weights for something other than %d kernels of %ld by %ld over %d channels",
                 revenant_ml_layer_name(layer), out_channels, (long)kernel[0], (long)kernel[1], channels / groups);
        return 0;
    }
    if (has_bias && !revenant_ml_read_numbers(revenant_ml_get(params, "bias"), &bias, &bias_count)) {
        free(weights);
        snprintf(error, error_size, "the layer '%s' says it has a bias and has none", revenant_ml_layer_name(layer));
        return 0;
    }
    shape[0] = out_channels;
    shape[1] = (input->shape[1] + pad[0] + pad[1] - dilation[0] * (kernel[0] - 1) - 1) / stride[0] + 1;
    shape[2] = (input->shape[2] + pad[2] + pad[3] - dilation[1] * (kernel[1] - 1) - 1) / stride[1] + 1;
    if (shape[1] <= 0 || shape[2] <= 0) {
        free(weights);
        free(bias);
        snprintf(error, error_size, "the layer '%s' has a kernel larger than its padded input",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    output = revenant_ml_tensor_make(3, shape);
    if (output.data == NULL) {
        free(weights);
        free(bias);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    {
        int64_t in_per_group = channels / groups, out_per_group = out_channels / groups;
        int64_t out_y, out_x, out_channel, group, in_channel, k_y, k_x;
        for (out_y = 0; out_y < shape[1]; out_y++) {
            for (out_x = 0; out_x < shape[2]; out_x++) {
                for (out_channel = 0; out_channel < shape[0]; out_channel++) {
                    double total = has_bias && bias_count > (size_t)out_channel ? bias[out_channel] : 0.0;
                    group = out_channel / out_per_group;
                    for (in_channel = 0; in_channel < in_per_group; in_channel++) {
                        int channel = (int)(group * in_per_group + in_channel);
                        for (k_y = 0; k_y < kernel[0]; k_y++) {
                            int64_t y = out_y * stride[0] + k_y * dilation[0] - pad[0];
                            if (y < 0 || y >= input->shape[1]) {
                                continue;
                            }
                            for (k_x = 0; k_x < kernel[1]; k_x++) {
                                int64_t x = out_x * stride[1] + k_x * dilation[1] - pad[2];
                                size_t at;
                                if (x < 0 || x >= input->shape[2]) {
                                    continue;
                                }
                                at = (size_t)(((out_channel * in_per_group + in_channel) * kernel[0] + k_y) * kernel[1] + k_x);
                                total += weights[at] *
                                         (double)input->data[(size_t)((channel * input->shape[1] + y) * input->shape[2] + x)];
                            }
                        }
                    }
                    output.data[(size_t)((out_channel * shape[1] + out_y) * shape[2] + out_x)] = (float)total;
                }
            }
        }
    }
    free(weights);
    free(bias);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_pooling(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int64_t kernel[2], stride[2], pad[4], shape[3];
    int kind, global, ceil_mode, index;
    revenant_ml_tensor output;

    for (index = 0; index < 4; index++) {
        pad[index] = 0;
    }
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank != 3) {
        return revenant_ml_layer_bad_shape(layer, "an input that is not channels by height by width", input,
                                         error, error_size);
    }
    kind = revenant_ml_integer_of(params, "type", 0);
    global = revenant_ml_integer_of(params, "globalPooling", 0) != 0;
    ceil_mode = revenant_ml_integer_of(params, "includeLastPixel", 0) != 0;
    if (global) {
        kernel[0] = input->shape[1];
        kernel[1] = input->shape[2];
        stride[0] = 1;
        stride[1] = 1;
    } else {
        revenant_ml_pad_kind how;
        kernel[0] = revenant_ml_int_at(params, "kernelSize", 0, 1);
        kernel[1] = revenant_ml_int_at(params, "kernelSize", 1, kernel[0]);
        stride[0] = revenant_ml_int_at(params, "stride", 0, 1);
        stride[1] = revenant_ml_int_at(params, "stride", 1, stride[0]);
        read_padding(params, &how, pad);
        if (how == REVENANT_ML_PAD_SAME) {
            pad[0] = same_padding(input->shape[1], kernel[0], stride[0], 0);
            pad[1] = same_padding(input->shape[1], kernel[0], stride[0], 1);
            pad[2] = same_padding(input->shape[2], kernel[1], stride[1], 0);
            pad[3] = same_padding(input->shape[2], kernel[1], stride[1], 1);
        }
    }
    if (kernel[0] <= 0 || kernel[1] <= 0 || stride[0] <= 0 || stride[1] <= 0) {
        snprintf(error, error_size, "the layer '%s' has a window or a stride of no length",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < 2; index++) {
        int64_t extent = input->shape[1 + index] + pad[2 * index] + pad[2 * index + 1] - kernel[index];
        int64_t count = ceil_mode ? (extent + stride[index]) / stride[index] : extent / stride[index];
        if (count < 1) {
            count = 1;
        }
        shape[1 + index] = count;
    }
    shape[0] = input->shape[0];
    output = revenant_ml_tensor_make(3, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    {
        int64_t channel, out_y, out_x, k_y, k_x;
        for (channel = 0; channel < shape[0]; channel++) {
            for (out_y = 0; out_y < shape[1]; out_y++) {
                for (out_x = 0; out_x < shape[2]; out_x++) {
                    double best = 0.0, total = 0.0, squares = 0.0;
                    int seen = 0;
                    for (k_y = 0; k_y < kernel[0]; k_y++) {
                        int64_t y = out_y * stride[0] + k_y - pad[0];
                        if (y < 0 || y >= input->shape[1]) {
                            continue;
                        }
                        for (k_x = 0; k_x < kernel[1]; k_x++) {
                            int64_t x = out_x * stride[1] + k_x - pad[2];
                            double value;
                            if (x < 0 || x >= input->shape[2]) {
                                continue;
                            }
                            value = (double)input->data[(size_t)((channel * input->shape[1] + y) * input->shape[2] + x)];
                            if (!seen || (kind == 0 && value > best) || (kind == 2 && value < best)) {
                                best = value;
                            }
                            total += value;
                            squares += value * value;
                            seen++;
                        }
                    }
                    if (!seen) {
                        best = 0.0;
                    }
                    output.data[(size_t)((channel * shape[1] + out_y) * shape[2] + out_x)] = (float)(kind == 0 ? best
                                                                                                         : (kind == 1 ? total / seen
                                                                                                                      : sqrt(squares / seen)));
                }
            }
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_inner_product(const revenant_ml_node *layer, const revenant_ml_node *params,
                                  revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double *weights = NULL, *bias = NULL;
    size_t weight_count = 0, bias_count = 0;
    int in_channels, out_channels, has_bias, channel, out_channel;
    int64_t shape[1];
    revenant_ml_tensor output;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    in_channels = revenant_ml_integer_of(params, "inputChannels", 0);
    out_channels = revenant_ml_integer_of(params, "outputChannels", 0);
    has_bias = revenant_ml_integer_of(params, "hasBias", 0) != 0;
    if (in_channels <= 0 || out_channels <= 0) {
        snprintf(error, error_size, "the layer '%s' has a channel count of no length",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    {
        int64_t features = 1;
        int axis;
        for (axis = 0; axis < input->rank; axis++) {
            features *= input->shape[axis];
        }
        if (features != in_channels) {
            snprintf(error, error_size,
                     "the layer '%s' takes %d features and its input has %lld", revenant_ml_layer_name(layer),
                     in_channels, (long long)features);
            return 0;
        }
        in_channels = (int)features;
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "weights"), &weights, &weight_count) ||
        weight_count != (size_t)in_channels * (size_t)out_channels) {
        free(weights);
        snprintf(error, error_size,
                 "the layer '%s' has weights for something other than %d outputs of %d features",
                 revenant_ml_layer_name(layer), out_channels, in_channels);
        return 0;
    }
    if (has_bias && !revenant_ml_read_numbers(revenant_ml_get(params, "bias"), &bias, &bias_count)) {
        free(weights);
        snprintf(error, error_size, "the layer '%s' says it has a bias and has none", revenant_ml_layer_name(layer));
        return 0;
    }
    shape[0] = out_channels;
    output = revenant_ml_tensor_make(1, shape);
    if (output.data == NULL) {
        free(weights);
        free(bias);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (out_channel = 0; out_channel < out_channels; out_channel++) {
        double total = has_bias && bias_count > (size_t)out_channel ? bias[out_channel] : 0.0;
        for (channel = 0; channel < in_channels; channel++) {
            total += weights[(size_t)out_channel * in_channels + channel] * (double)input->data[channel];
        }
        output.data[out_channel] = (float)total;
    }
    free(weights);
    free(bias);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_activation(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int kind;
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    kind = revenant_ml_activation_kind(params);
    if (kind == 0) {
        snprintf(error, error_size, "the layer '%s' has no activation the specification names",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    return take_output(layer, bindings, revenant_ml_map_unary(input, kind, params), error, error_size);
}

int revenant_ml_layer_softmax(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int axis;
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    axis = revenant_ml_integer_of(params, "axis", 0);
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    memcpy(output.data, input->data, input->count * sizeof *output.data);
    revenant_ml_softmax_axis(&output, axis);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_batchnorm(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double *gamma = NULL, *beta = NULL, *mean = NULL, *variance = NULL;
    size_t gamma_count = 0, beta_count = 0, mean_count = 0, variance_count = 0;
    double epsilon, instance_normalization;
    size_t index;
    revenant_ml_tensor output;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "gamma"), &gamma, &gamma_count) ||
        !revenant_ml_read_numbers(revenant_ml_get(params, "beta"), &beta, &beta_count) ||
        !revenant_ml_read_numbers(revenant_ml_get(params, "mean"), &mean, &mean_count) ||
        !revenant_ml_read_numbers(revenant_ml_get(params, "variance"), &variance, &variance_count)) {
        free(gamma);
        free(beta);
        free(mean);
        free(variance);
        snprintf(error, error_size,
                 "the layer '%s' does not carry all four of the gamma, beta, mean and variance a batch norm needs",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    epsilon = revenant_ml_number_of(params, "epsilon", 1e-5);
    instance_normalization = revenant_ml_integer_of(params, "instanceNormalization", 0) != 0;
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        free(gamma);
        free(beta);
        free(mean);
        free(variance);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    if (instance_normalization || input->rank < 2) {
        for (index = 0; index < input->count; index++) {
            int64_t position[REVENANT_ML_MAX_RANK];
            size_t channel, at;
            double total = 0.0, squares = 0.0, average, spread;
            int64_t area = 1;
            int axis;
            revenant_ml_unravel((int64_t)index, input->rank, input->shape, position);
            channel = (size_t)position[0];
            for (axis = 1; axis < input->rank; axis++) {
                area *= input->shape[axis];
            }
            for (at = 0; at < (size_t)area; at++) {
                int64_t offset = (int64_t)channel * area + (int64_t)at;
                total += input->data[offset];
                squares += (double)input->data[offset] * (double)input->data[offset];
            }
            average = total / (double)area;
            spread = sqrt(squares / (double)area - average * average);
            output.data[index] = (float)(((double)input->data[index] - average) *
                                            (channel < gamma_count ? gamma[channel] : 1.0) /
                                            sqrt(spread * spread + epsilon) +
                                        (channel < beta_count ? beta[channel] : 0.0));
        }
    } else {
        int64_t area = 1;
        int64_t channel;
        int axis;
        for (axis = 1; axis < input->rank; axis++) {
            area *= input->shape[axis];
        }
        for (channel = 0; channel < input->shape[0]; channel++) {
            for (index = 0; index < (size_t)area; index++) {
                int64_t at = channel * area + (int64_t)index;
                output.data[at] = (float)(((double)input->data[at] - mean[channel]) * gamma[channel] /
                                              sqrt(variance[channel] + epsilon) +
                                          beta[channel]);
            }
        }
    }
    free(gamma);
    free(beta);
    free(mean);
    free(variance);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_mvn(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                        char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int across_channels, normalize_variance;
    double epsilon;
    revenant_ml_tensor output;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank < 2) {
        return revenant_ml_layer_bad_shape(layer, "an input of one dimension, which a mean and variance has none over",
                                         input, error, error_size);
    }
    across_channels = revenant_ml_integer_of(params, "acrossChannels", 0) != 0;
    normalize_variance = revenant_ml_integer_of(params, "normalizeVariance", 0) != 0;
    epsilon = revenant_ml_number_of(params, "epsilon", 1e-5);
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    {
        size_t total = input->count, index;
        double sum = 0.0, squares = 0.0, average, spread;
        for (index = 0; index < total; index++) {
            sum += input->data[index];
            squares += (double)input->data[index] * (double)input->data[index];
        }
        average = sum / (double)total;
        spread = normalize_variance ? sqrt(squares / (double)total - average * average) : 1.0;
        for (index = 0; index < total; index++) {
            output.data[index] = (float)(((double)input->data[index] - average) / (spread + epsilon));
        }
    }
    (void)across_channels;
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_l2normalize(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    double epsilon, total = 0.0;
    size_t at;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    epsilon = revenant_ml_number_of(params, "epsilon", 1e-12);
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (at = 0; at < input->count; at++) {
        total += (double)input->data[at] * (double)input->data[at];
    }
    total = sqrt(total) + epsilon;
    for (at = 0; at < input->count && at < output.count; at++) {
        output.data[at] = (float)((double)input->data[at] / total);
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_lrn(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                       char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double alpha, beta, k;
    int local_size, channel;
    int64_t area = 1, at;
    int axis;
    revenant_ml_tensor output;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank < 3) {
        return revenant_ml_layer_bad_shape(layer, "an input with no spatial extent to reach across", input, error,
                                         error_size);
    }
    alpha = revenant_ml_number_of(params, "alpha", 0.0001);
    beta = revenant_ml_number_of(params, "beta", 0.75);
    k = revenant_ml_number_of(params, "k", 1.0);
    local_size = revenant_ml_integer_of(params, "localSize", 1);
    for (axis = 1; axis < input->rank; axis++) {
        area *= input->shape[axis];
    }
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (channel = 0; channel < (int)input->shape[0]; channel++) {
        int first = channel - local_size, last = channel + local_size, count = 0, neighbour;
        if (first < 0) {
            first = 0;
        }
        if (last > (int)input->shape[0]) {
            last = (int)input->shape[0];
        }
        for (neighbour = first; neighbour < last; neighbour++) {
            count++;
        }
        if (count < 1) {
            count = 1;
        }
        for (at = 0; at < area; at++) {
            double total = 0.0;
            for (neighbour = first; neighbour < last; neighbour++) {
                double value = input->data[(size_t)neighbour * area + at];
                total += value * value;
            }
            output.data[(size_t)channel * area + at] =
                (float)(input->data[(size_t)channel * area + at] / pow(k + alpha / count * total, beta));
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_embedding(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double *weights = NULL, *bias = NULL;
    size_t weight_count = 0, bias_count = 0;
    int input_dim, output_channels, has_bias;
    int64_t shape[2];
    revenant_ml_tensor output;
    size_t index;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    input_dim = revenant_ml_integer_of(params, "inputDim", 0);
    output_channels = revenant_ml_integer_of(params, "outputChannels", 0);
    has_bias = revenant_ml_integer_of(params, "hasBias", 0) != 0;
    if (input_dim <= 0 || output_channels <= 0) {
        snprintf(error, error_size, "the layer '%s' has a dimension of no length", revenant_ml_layer_name(layer));
        return 0;
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "weights"), &weights, &weight_count) ||
        weight_count != (size_t)input_dim * (size_t)output_channels) {
        free(weights);
        snprintf(error, error_size,
                 "the layer '%s' has weights for something other than %d rows of %d", revenant_ml_layer_name(layer),
                 input_dim, output_channels);
        return 0;
    }
    if (has_bias && !revenant_ml_read_numbers(revenant_ml_get(params, "bias"), &bias, &bias_count)) {
        free(weights);
        snprintf(error, error_size, "the layer '%s' says it has a bias and has none", revenant_ml_layer_name(layer));
        return 0;
    }
    shape[0] = input->count;
    shape[1] = output_channels;
    output = revenant_ml_tensor_make(2, shape);
    if (output.data == NULL) {
        free(weights);
        free(bias);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < input->count; index++) {
        int64_t row = (int64_t)input->data[index];
        int64_t at;
        if (row < 0 || row >= input_dim) {
            snprintf(error, error_size, "the layer '%s' is given the index %lld, which is not one of its %d rows",
                     revenant_ml_layer_name(layer), (long long)row, input_dim);
            revenant_ml_tensor_free(&output);
            free(weights);
            free(bias);
            return 0;
        }
        for (at = 0; at < output_channels; at++) {
            double value = weights[(size_t)(at * input_dim + row)];
            output.data[index * output_channels + at] =
                (float)(has_bias && bias_count > (size_t)at ? value + bias[at] : value);
        }
    }
    free(weights);
    free(bias);
    return take_output(layer, bindings, output, error, error_size);
}

static int own_numbers(const revenant_ml_node *params, const char *field, const revenant_ml_node *layer,
                       revenant_ml_bindings *bindings, size_t input_index, double **out, int *count,
                       char *error, size_t error_size)
{
    char name[256];
    revenant_ml_tensor *named = NULL;
    *out = NULL;
    *count = 0;
    if (revenant_ml_name_at(layer, "input", input_index, name, sizeof name) != NULL) {
        named = revenant_ml_bindings_find(bindings, name);
    }
    if (named != NULL) {
        *out = (double *)malloc(named->count * sizeof **out);
        if (*out == NULL) {
            snprintf(error, error_size, "the layer '%s' has values of no room for it", revenant_ml_layer_name(layer));
            return 0;
        }
        for (*count = 0; (size_t)(*count) < named->count; (*count)++) {
            (*out)[*count] = named->data[*count];
        }
        return 1;
    }
    {
        size_t total = 0;
        if (revenant_ml_read_numbers(revenant_ml_get(params, field), out, &total) && total > 0) {
            *count = (int)total;
            return 1;
        }
        free(*out);
        *out = NULL;
    }
    snprintf(error, error_size, "the layer '%s' has neither a '%s' of its own nor one named as an input",
             revenant_ml_layer_name(layer), field);
    return 0;
}

int revenant_ml_layer_scale(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                          char *error, size_t error_size)
{
    char name[256];
    revenant_ml_tensor *input = NULL;
    double *scale = NULL, *shift = NULL;
    int scale_count = 0, shift_count = 0;
    revenant_ml_tensor output;
    int64_t area = 1, at, channel;
    int axis;

    if (revenant_ml_name_at(layer, "input", 0, name, sizeof name) != NULL) {
        input = revenant_ml_bindings_find(bindings, name);
    }
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (!own_numbers(params, "scale", layer, bindings, 1, &scale, &scale_count, error, error_size)) {
        return 0;
    }
    if (revenant_ml_integer_of(params, "hasBias", 0) != 0 &&
        !own_numbers(params, "bias", layer, bindings, 2, &shift, &shift_count, error, error_size)) {
        free(scale);
        return 0;
    }
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        free(scale);
        free(shift);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (axis = 1; axis < input->rank; axis++) {
        area *= input->shape[axis];
    }
    for (channel = 0; channel < input->shape[0]; channel++) {
        double by_channel = scale_count == 1 ? scale[0] : (channel < scale_count ? scale[channel] : scale[0]);
        double add = shift_count == 0 ? 0.0
                                  : (shift_count == 1 ? shift[0] : (channel < shift_count ? shift[channel] : 0.0));
        for (at = 0; at < area; at++) {
            output.data[channel * area + at] = (float)((double)input->data[channel * area + at] * by_channel + add);
        }
    }
    free(scale);
    free(shift);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_bias(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                         char *error, size_t error_size)
{
    char name[256];
    revenant_ml_tensor *input = NULL, *offset = NULL;
    revenant_ml_tensor output;
    size_t index;
    int64_t extent;

    if (revenant_ml_name_at(layer, "input", 0, name, sizeof name) != NULL) {
        input = revenant_ml_bindings_find(bindings, name);
    }
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    extent = (int64_t)input->count;
    (void)extent;
    if (revenant_ml_name_at(layer, "input", 1, name, sizeof name) != NULL) {
        offset = revenant_ml_bindings_find(bindings, name);
    }
    if (offset == NULL) {
        double *numbers = NULL;
        size_t total = 0;
        revenant_ml_tensor own;
        if (!revenant_ml_read_numbers(revenant_ml_get(params, "bias"), &numbers, &total) || total == 0) {
            free(numbers);
            snprintf(error, error_size, "the layer '%s' has neither an offset named as an input nor one of its own",
                     revenant_ml_layer_name(layer));
            return 0;
        }
        own = revenant_ml_tensor_make(1, &(int64_t){(int64_t)total});
        for (index = 0; index < own.count; index++) {
            own.data[index] = (float)numbers[index];
        }
        free(numbers);
        offset = &own;
        output = revenant_ml_tensor_make(input->rank, input->shape);
        if (output.data == NULL) {
            snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
            return 0;
        }
        for (index = 0; index < input->count && index < offset->count; index++) {
            output.data[index] = (float)(input->data[index] + offset->data[index]);
        }
        return take_output(layer, bindings, output, error, error_size);
    }
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < input->count && index < offset->count; index++) {
        output.data[index] = (float)(input->data[index] + offset->data[index]);
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_padding(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int64_t pad[4], shape[3];
    int constant;
    revenant_ml_pad_kind how;
    double value;
    revenant_ml_tensor output;
    int64_t channel, y, x;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank != 3) {
        return revenant_ml_layer_bad_shape(layer, "an input that is not channels by height by width", input,
                                         error, error_size);
    }
    {
        const revenant_ml_node *fill = revenant_ml_get(params, "constant");
        read_padding(params, &how, pad);
        constant = fill != NULL;
        value = revenant_ml_number_of(fill, "value", 0.0);
    }
    if (pad[0] < 0 || pad[1] < 0 || pad[2] < 0 || pad[3] < 0) {
        snprintf(error, error_size, "the layer '%s' has a padding of negative length", revenant_ml_layer_name(layer));
        return 0;
    }
    shape[0] = input->shape[0];
    shape[1] = input->shape[1] + pad[0] + pad[1];
    shape[2] = input->shape[2] + pad[2] + pad[3];
    output = revenant_ml_tensor_make(3, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (channel = 0; channel < shape[0]; channel++) {
        for (y = 0; y < shape[1]; y++) {
            for (x = 0; x < shape[2]; x++) {
                int64_t from_y = y - pad[0], from_x = x - pad[2];
                int inside = from_y >= 0 && from_y < input->shape[1] && from_x >= 0 && from_x < input->shape[2];
                output.data[(size_t)((channel * shape[1] + y) * shape[2] + x)] =
                    (float)(inside ? input->data[(size_t)((channel * input->shape[1] + from_y) * input->shape[2] + from_x)]
                                   : (constant ? value : 0.0));
            }
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_load_constant(const revenant_ml_node *layer, const revenant_ml_node *params,
                                  revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    const revenant_ml_node *data = revenant_ml_get(params, "data");
    double *numbers = NULL;
    size_t count = 0, index;
    int rank = (int)revenant_ml_count_field(params, "shape");
    int64_t shape[REVENANT_ML_MAX_RANK];
    revenant_ml_tensor output;

    if (rank > REVENANT_ML_MAX_RANK) {
        snprintf(error, error_size, "the layer '%s' is a constant of more dimensions than this port holds",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < (size_t)rank; index++) {
        shape[index] = revenant_ml_int_at(params, "shape", index, 0);
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' is a constant whose shape has no room for it",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    if (data == NULL) {
        return take_output(layer, bindings, output, error, error_size);
    }
    if (revenant_ml_read_numbers(data, &numbers, &count)) {
        for (index = 0; index < count && index < output.count; index++) {
            output.data[index] = (float)numbers[index];
        }
        free(numbers);
    } else {
        const revenant_ml_node *entry = revenant_ml_get(data, "rawValue");
        if (entry == NULL) {
            entry = revenant_ml_get(data, "float16Value");
        }
        if (entry != NULL) {
            revenant_ml_tensor from;
            memset(&from, 0, sizeof from);
            for (index = 0; index < output.count; index++) {
                output.data[index] = 0.0f;
            }
            (void)from;
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_permute(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], source_strides[REVENANT_ML_MAX_RANK], position[REVENANT_ML_MAX_RANK];
    int64_t axis_strides[REVENANT_ML_MAX_RANK];
    size_t index;
    int axis;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if ((int)revenant_ml_count_field(params, "axis") != input->rank) {
        snprintf(error, error_size, "the layer '%s' is given %d axes for an input of %d dimensions",
                 revenant_ml_layer_name(layer), (int)revenant_ml_count_field(params, "axis"), input->rank);
        return 0;
    }
    for (axis = 0; axis < input->rank; axis++) {
        int source = revenant_ml_int_at(params, "axis", (size_t)axis, -1);
        if (source < 0 || source >= input->rank) {
            snprintf(error, error_size, "the layer '%s' names the axis %d, which its input does not have",
                     revenant_ml_layer_name(layer), source);
            return 0;
        }
        shape[axis] = input->shape[source];
    }
    output = revenant_ml_tensor_make(input->rank, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    revenant_ml_row_major_strides(input->shape, input->rank, source_strides);
    for (axis = 0; axis < input->rank; axis++) {
        axis_strides[axis] = source_strides[revenant_ml_int_at(params, "axis", (size_t)axis, 0)];
    }
    for (index = 0; index < output.count; index++) {
        revenant_ml_unravel((int64_t)index, output.rank, shape, position);
        output.data[index] = input->data[revenant_ml_ravel(position, output.rank, axis_strides)];
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_reshape(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], known = 1, total = 0;
    int rank, index, wildcard = -1;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    rank = (int)revenant_ml_count_field(params, "targetShape");
    if (rank > REVENANT_ML_MAX_RANK) {
        snprintf(error, error_size, "the layer '%s' reshapes to more dimensions than this port holds",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < input->rank; index++) {
        total += (int)input->shape[index];
    }
    for (index = 0; index < rank; index++) {
        shape[index] = revenant_ml_int_at(params, "targetShape", (size_t)index, -1);
        if (shape[index] < 0) {
            if (wildcard >= 0) {
                snprintf(error, error_size, "the layer '%s' leaves two of its target dimensions open",
                         revenant_ml_layer_name(layer));
                return 0;
            }
            wildcard = index;
            shape[index] = 1;
        } else {
            known *= shape[index];
        }
    }
    if (wildcard >= 0) {
        if (known <= 0) {
            snprintf(error, error_size, "the layer '%s' reshapes to a target of no length",
                     revenant_ml_layer_name(layer));
            return 0;
        }
        shape[wildcard] = total / known;
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL || output.count != input->count) {
        revenant_ml_tensor_free(&output);
        snprintf(error, error_size, "the layer '%s' reshapes %lu values into a shape that holds %lu",
                 revenant_ml_layer_name(layer), (unsigned long)input->count, (unsigned long)output.count);
        return 0;
    }
    memcpy(output.data, input->data, input->count * sizeof *output.data);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_flatten(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[1];
    int channel_last;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    channel_last = revenant_ml_integer_of(params, "order", 0) == 1;
    (void)channel_last;
    shape[0] = (int64_t)input->count;
    output = revenant_ml_tensor_make(1, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    memcpy(output.data, input->data, input->count * sizeof *output.data);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_concat(const revenant_ml_node *layer, const revenant_ml_node *params,
                           revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    size_t inputs = revenant_ml_name_count(layer, "input"), index;
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], strides[REVENANT_ML_MAX_RANK];
    int64_t offset[REVENANT_ML_MAX_RANK];
    char names[8][256];
    size_t kept;

    if (inputs < 2 || inputs > 8) {
        snprintf(error, error_size, "the layer '%s' joins %lu inputs, and this port joins two to eight",
                 revenant_ml_layer_name(layer), (unsigned long)inputs);
        return 0;
    }
    kept = 0;
    for (index = 0; index < inputs && kept < 8; index++) {
        char *name = names[kept];
        if (revenant_ml_name_at(layer, "input", index, name, 256) == NULL ||
            revenant_ml_bindings_find(bindings, name) == NULL) {
            snprintf(error, error_size, "the layer '%s' names an input that is not there", revenant_ml_layer_name(layer));
            return 0;
        }
        kept++;
    }
    {
        revenant_ml_tensor *first = revenant_ml_bindings_find(bindings, names[0]);
        int rank = first->rank;
        int position = 0;
        if (rank != 1 && rank != 3) {
            snprintf(error, error_size,
                     "the layer '%s' joins values of %d dimensions, and Core ML joins the channels of three or a whole one",
                     revenant_ml_layer_name(layer), rank);
            return 0;
        }
        for (index = 0; index < (size_t)rank; index++) {
            shape[index] = first->shape[index];
        }
        shape[position] = 0;
        for (index = 0; index < kept; index++) {
            revenant_ml_tensor *other = revenant_ml_bindings_find(bindings, names[index]);
            int axis_index;
            if (other->rank != rank) {
                snprintf(error, error_size, "the layer '%s' joins an input of %d dimensions with one of %d",
                         revenant_ml_layer_name(layer), other->rank, rank);
                return 0;
            }
            for (axis_index = 0; axis_index < rank; axis_index++) {
                if (axis_index != position && other->shape[axis_index] != shape[axis_index]) {
                    snprintf(error, error_size,
                             "the layer '%s' joins inputs whose dimension %d is %lld in one and %lld in another",
                             revenant_ml_layer_name(layer), axis_index, (long long)other->shape[axis_index],
                             (long long)shape[axis_index]);
                    return 0;
                }
            }
            shape[position] += other->shape[position];
        }
        output = revenant_ml_tensor_make(rank, shape);
        if (output.data == NULL) {
            snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
            return 0;
        }
        revenant_ml_row_major_strides(shape, rank, strides);
        memset(offset, 0, sizeof offset);
        for (index = 0; index < kept; index++) {
            revenant_ml_tensor *other = revenant_ml_bindings_find(bindings, names[index]);
            size_t at;
            for (at = 0; at < other->count; at++) {
                int64_t position_in[REVENANT_ML_MAX_RANK];
                revenant_ml_unravel((int64_t)at, rank, shape, position_in);
                position_in[position] -= offset[position];
                output.data[revenant_ml_ravel(position_in, rank, strides)] = other->data[at];
            }
            offset[position] += other->shape[position];
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_split(const revenant_ml_node *layer, const revenant_ml_node *params,
                          revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    size_t outputs = revenant_ml_name_count(layer, "output"), index;
    int axis;
    revenant_ml_tensor piece;
    char name[256];

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (outputs < 1 || outputs > 4) {
        snprintf(error, error_size, "the layer '%s' splits into %lu outputs, and this port splits into one to four",
                 revenant_ml_layer_name(layer), (unsigned long)outputs);
        return 0;
    }
    axis = revenant_ml_integer_of(params, "axis", 0);
    if (axis < 0) {
        axis += input->rank;
    }
    if (axis < 0 || axis >= input->rank) {
        snprintf(error, error_size, "the layer '%s' splits along the axis %d, which its input does not have",
                 revenant_ml_layer_name(layer), axis);
        return 0;
    }
    {
        int64_t along = input->shape[axis] / (int64_t)outputs, position[REVENANT_ML_MAX_RANK];
        int64_t strides[REVENANT_ML_MAX_RANK];
        revenant_ml_row_major_strides(input->shape, input->rank, strides);
        if (along * (int64_t)outputs != input->shape[axis]) {
            snprintf(error, error_size, "the layer '%s' splits %lld values into %lu equal parts, which does not divide",
                     revenant_ml_layer_name(layer), (long long)input->shape[axis], (unsigned long)outputs);
            return 0;
        }
        for (index = 0; index < outputs; index++) {
            int64_t shape[REVENANT_ML_MAX_RANK];
            size_t out;
            memcpy(shape, input->shape, (size_t)input->rank * sizeof *shape);
            shape[axis] = along;
            piece = revenant_ml_tensor_make(input->rank, shape);
            if (piece.data == NULL) {
                snprintf(error, error_size, "the layer '%s' has a part of no room for it", revenant_ml_layer_name(layer));
                return 0;
            }
            for (out = 0; out < piece.count; out++) {
                int64_t source[REVENANT_ML_MAX_RANK];
                revenant_ml_unravel((int64_t)out, piece.rank, shape, position);
                memcpy(source, position, (size_t)input->rank * sizeof *source);
                source[axis] += (int64_t)index * along;
                piece.data[out] = input->data[revenant_ml_ravel(source, input->rank, strides)];
            }
            if (revenant_ml_name_at(layer, "output", index, name, sizeof name) == NULL ||
                !revenant_ml_bindings_put(bindings, name, piece)) {
                revenant_ml_tensor_free(&piece);
                snprintf(error, error_size, "the layer '%s' names an output that is not there, or has no room for it",
                         revenant_ml_layer_name(layer));
                return 0;
            }
        }
    }
    return 1;
}

int revenant_ml_layer_slice(const revenant_ml_node *layer, const revenant_ml_node *params,
                          revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], position[REVENANT_ML_MAX_RANK], strides[REVENANT_ML_MAX_RANK];
    int rank, axis;
    size_t index;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    rank = input->rank;
    for (axis = 0; axis < rank; axis++) {
        int64_t start = revenant_ml_int_at(params, "startIndices", (size_t)axis, 0);
        int64_t end = revenant_ml_int_at(params, "endIndices", (size_t)axis, input->shape[axis] - 1);
        int64_t step = revenant_ml_int_at(params, "strides", (size_t)axis, 1);
        if (start < 0) {
            start += input->shape[axis];
        }
        if (end < 0) {
            end += input->shape[axis];
        }
        if (step <= 0 || start < 0 || end >= input->shape[axis] || end < start) {
            snprintf(error, error_size, "the layer '%s' takes a slice of its input that lies outside it",
                     revenant_ml_layer_name(layer));
            return 0;
        }
        shape[axis] = (end - start) / step + 1;
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    revenant_ml_row_major_strides(input->shape, rank, strides);
    for (index = 0; index < output.count; index++) {
        int64_t source[REVENANT_ML_MAX_RANK];
        revenant_ml_unravel((int64_t)index, rank, shape, position);
        for (axis = 0; axis < rank; axis++) {
            int64_t start = revenant_ml_int_at(params, "startIndices", (size_t)axis, 0);
            int64_t step = revenant_ml_int_at(params, "strides", (size_t)axis, 1);
            if (start < 0) {
                start += input->shape[axis];
            }
            source[axis] = start + position[axis] * step;
        }
        output.data[index] = input->data[revenant_ml_ravel(source, rank, strides)];
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_copy(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                         char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    memcpy(output.data, input->data, input->count * sizeof *output.data);
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_transpose(const revenant_ml_node *layer, const revenant_ml_node *params,
                              revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], source_strides[REVENANT_ML_MAX_RANK], axis_strides[REVENANT_ML_MAX_RANK];
    int64_t position[REVENANT_ML_MAX_RANK];
    int rank, axis;
    size_t index;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    rank = input->rank;
    if ((int)revenant_ml_count_field(params, "axes") != rank) {
        snprintf(error, error_size, "the layer '%s' is given %d axes for an input of %d dimensions",
                 revenant_ml_layer_name(layer), (int)revenant_ml_count_field(params, "axes"), rank);
        return 0;
    }
    for (axis = 0; axis < rank; axis++) {
        int source = revenant_ml_int_at(params, "axes", (size_t)axis, -1);
        if (source < 0 || source >= rank) {
            snprintf(error, error_size, "the layer '%s' names the axis %d, which its input does not have",
                     revenant_ml_layer_name(layer), source);
            return 0;
        }
        shape[axis] = input->shape[source];
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    revenant_ml_row_major_strides(input->shape, rank, source_strides);
    for (axis = 0; axis < rank; axis++) {
        axis_strides[axis] = source_strides[revenant_ml_int_at(params, "axes", (size_t)axis, 0)];
    }
    for (index = 0; index < output.count; index++) {
        revenant_ml_unravel((int64_t)index, rank, shape, position);
        output.data[index] = input->data[revenant_ml_ravel(position, rank, axis_strides)];
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_upsample(const revenant_ml_node *layer, const revenant_ml_node *params,
                             revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t scale_y, scale_x, shape[3], channel, y, x;
    int mode;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank != 3) {
        return revenant_ml_layer_bad_shape(layer, "an input that is not channels by height by width", input,
                                         error, error_size);
    }
    scale_y = revenant_ml_int_at(params, "scalingFactor", 0, 1);
    scale_x = revenant_ml_int_at(params, "scalingFactor", 1, 1);
    mode = revenant_ml_integer_of(params, "mode", 0);
    if (scale_y < 1 || scale_x < 1) {
        snprintf(error, error_size, "the layer '%s' scales by a factor below one", revenant_ml_layer_name(layer));
        return 0;
    }
    if (mode != 0) {
        snprintf(error, error_size, "the layer '%s' interpolates bilinearly, which this port does not do",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    shape[0] = input->shape[0];
    shape[1] = input->shape[1] * scale_y;
    shape[2] = input->shape[2] * scale_x;
    output = revenant_ml_tensor_make(3, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    for (channel = 0; channel < shape[0]; channel++) {
        for (y = 0; y < shape[1]; y++) {
            for (x = 0; x < shape[2]; x++) {
                output.data[(size_t)((channel * shape[1] + y) * shape[2] + x)] =
                    input->data[(size_t)((channel * input->shape[1] + y / scale_y) * input->shape[2] + x / scale_x)];
            }
        }
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_dot(const revenant_ml_node *layer, const revenant_ml_node *params, revenant_ml_bindings *bindings,
                        char *error, size_t error_size)
{
    char name[256];
    revenant_ml_tensor *left = NULL, *right = NULL;
    revenant_ml_tensor output;
    int64_t shape[1];
    size_t index, count;
    double total = 0.0;

    if (revenant_ml_name_at(layer, "input", 0, name, sizeof name) != NULL) {
        left = revenant_ml_bindings_find(bindings, name);
    }
    if (revenant_ml_name_at(layer, "input", 1, name, sizeof name) != NULL) {
        right = revenant_ml_bindings_find(bindings, name);
    }
    if (left == NULL || right == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    count = left->count < right->count ? left->count : right->count;
    for (index = 0; index < count; index++) {
        total += (double)left->data[index] * (double)right->data[index];
    }
    shape[0] = 1;
    output = revenant_ml_tensor_make(1, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    output.data[0] = (float)total;
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_reduce(const revenant_ml_node *layer, const revenant_ml_node *params,
                           revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int operation, axis_kind;
    int64_t shape[REVENANT_ML_MAX_RANK], strides[REVENANT_ML_MAX_RANK], outer = 1, inner, along, position[REVENANT_ML_MAX_RANK];
    int rank, kept = 0, index;
    size_t at;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    operation = revenant_ml_integer_of(params, "mode", 0);
    axis_kind = revenant_ml_integer_of(params, "axis", 0);
    rank = input->rank;
    for (index = 0; index < rank; index++) {
        int covered = (axis_kind == 0) || (axis_kind == 1 && index > 0) ||
                      (axis_kind == 2 && index == 0) || (axis_kind == 3 && index == 1) ||
                      (axis_kind == 4 && index == 2);
        if (!covered) {
            shape[kept] = input->shape[index];
            kept++;
        } else {
            outer *= input->shape[index];
        }
    }
    if (kept == 0) {
        shape[0] = 1;
        kept = 1;
    }
    output = revenant_ml_tensor_make(kept, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    revenant_ml_row_major_strides(shape, kept, strides);
    inner = kept < 2 ? 1 : strides[1];
    for (along = 0; along < (int64_t)output.count; along++) {
        double total = 0.0, best = 0.0, product = 1.0;
        int seen = 0;
        revenant_ml_unravel((int64_t)along, kept, shape, position);
        for (at = 0; at < (size_t)outer; at++) {
            int64_t flat = along * (int64_t)outer + (int64_t)at;
            double value = input->data[flat];
            if (!seen || (operation == 7 && value > best) || (operation == 8 && value < best)) {
                best = value;
            }
            switch (operation) {
            case 3:
                total += log(fabs(value) + 1e-20);
                break;
            case 4:
                total += value * value;
                break;
            case 5:
                total += fabs(value);
                break;
            case 6:
                total += value * value;
                break;
            default:
                total += value;
                break;
            }
            product *= value;
            seen++;
        }
        switch (operation) {
        case 1:
            output.data[along] = (float)(total / (seen ? seen : 1));
            break;
        case 2:
            output.data[along] = (float)product;
            break;
        case 7:
        case 8:
            output.data[along] = (float)best;
            break;
        case 6:
            output.data[along] = (float)sqrt(total);
            break;
        case 3:
            output.data[along] = (float)log1p(exp(total));
            break;
        default:
            output.data[along] = (float)total;
            break;
        }
        (void)inner;
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_reorganize(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int kind, block, index;
    int64_t shape[3];

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    if (input->rank != 3) {
        return revenant_ml_layer_bad_shape(layer, "an input that is not channels by height by width", input,
                                         error, error_size);
    }
    kind = revenant_ml_integer_of(params, "reorganizationType", 0);
    block = revenant_ml_integer_of(params, "blockSizeHeight", 2);
    if (block <= 0) {
        snprintf(error, error_size, "the layer '%s' reorganizes in blocks of no length",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    if (kind == 0) {
        shape[0] = input->shape[0] * block * block;
        shape[1] = input->shape[1] / block;
        shape[2] = input->shape[2] / block;
    } else {
        if (input->shape[0] % (block * block) != 0) {
            snprintf(error, error_size, "the layer '%s' has %lld channels, which is not a whole number of blocks",
                     revenant_ml_layer_name(layer), (long long)input->shape[0]);
            return 0;
        }
        shape[0] = input->shape[0] / (block * block);
        shape[1] = input->shape[1] * block;
        shape[2] = input->shape[2] * block;
    }
    output = revenant_ml_tensor_make(3, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    {
        int64_t channel, y, x, k_y, k_x;
        for (channel = 0; channel < input->shape[0]; channel++) {
            for (y = 0; y < input->shape[1]; y++) {
                for (x = 0; x < input->shape[2]; x++) {
                    int64_t target_c, target_y, target_x;
                    if (kind == 0) {
                        target_c = (channel * block + (y % block)) * block + (x % block);
                        target_y = y / block;
                        target_x = x / block;
                    } else {
                        int64_t blocks = input->shape[1] / block;
                        target_c = channel / (block * block);
                        target_y = (channel / block) % block * blocks + y;
                        target_x = channel % block * blocks + x;
                    }
                    (void)k_y;
                    (void)k_x;
                    if (target_c < shape[0] && target_y < shape[1] && target_x < shape[2]) {
                        output.data[(size_t)((target_c * shape[1] + target_y) * shape[2] + target_x)] =
                            input->data[(size_t)((channel * input->shape[1] + y) * input->shape[2] + x)];
                    }
                }
            }
        }
    }
    (void)index;
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_unary_math(const revenant_ml_node *layer, const revenant_ml_node *params,
                               revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    size_t index;
    int which = 0;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    output = revenant_ml_tensor_make(input->rank, input->shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    {
        size_t at, total = revenant_ml_count(layer);
        for (at = 0; at < total; at++) {
            const revenant_ml_node *entry = revenant_ml_at(layer, at);
            if (entry->field->number >= 660 && entry->field->number <= 800) {
                which = entry->field->number;
                break;
            }
        }
    }
    for (index = 0; index < input->count; index++) {
        double x = input->data[index];
        double value;
        switch (which) {
        case 660:
            value = fmin(fmax(x, revenant_ml_number_of(params, "minVal", 0.0)),
                         revenant_ml_number_of(params, "maxVal", 1.0));
            break;
        case 665:
            value = ceil(x);
            break;
        case 670:
            value = floor(x);
            break;
        case 680:
            value = x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);
            break;
        case 685:
            value = round(x);
            break;
        case 700:
            value = exp2(x);
            break;
        case 710:
            value = sin(x);
            break;
        case 715:
            value = cos(x);
            break;
        case 720:
            value = tan(x);
            break;
        case 730:
            value = asin(x);
            break;
        case 735:
            value = acos(x);
            break;
        case 740:
            value = atan(x);
            break;
        case 750:
            value = sinh(x);
            break;
        case 755:
            value = cosh(x);
            break;
        case 760:
            value = tanh(x);
            break;
        case 770:
            value = asinh(x);
            break;
        case 775:
            value = acosh(x);
            break;
        case 780:
            value = atanh(x);
            break;
        case 790:
            value = erf(x);
            break;
        case 795: {
            int mode = revenant_ml_integer_of(params, "mode", 0);
            if (mode != 0) {
                revenant_ml_tensor_free(&output);
                snprintf(error, error_size,
                         "the layer '%s' approximates the GELU in mode %d, which this port does not carry",
                         revenant_ml_layer_name(layer), mode);
                return 0;
            }
            value = x * 0.5 * (1.0 + erf(x / sqrt(2.0)));
            break;
        }
        default:
            value = x;
            break;
        }
        output.data[index] = (float)value;
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_clip(const revenant_ml_node *layer, const revenant_ml_node *params,
                         revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    return revenant_ml_layer_unary_math(layer, params, bindings, error, error_size);
}

static revenant_ml_tensor gather_axes(const revenant_ml_node *layer, const revenant_ml_bindings *bindings,
                                    const int *kept, int kept_count, int source_rank,
                                    char *error, size_t error_size)
{
    char name[256];
    revenant_ml_tensor *input = NULL;
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], strides[REVENANT_ML_MAX_RANK], position[REVENANT_ML_MAX_RANK];
    int64_t source[REVENANT_ML_MAX_RANK];
    int k;
    size_t at;

    memset(&output, 0, sizeof output);
    if (revenant_ml_name_at(layer, "input", 0, name, sizeof name) != NULL) {
        input = revenant_ml_bindings_find((revenant_ml_bindings *)bindings, name);
    }
    if (input == NULL || input->rank != source_rank) {
        snprintf(error, error_size, "the layer '%s' has no input of %d dimensions", revenant_ml_layer_name(layer),
                 source_rank);
        return output;
    }
    for (k = 0; k < kept_count; k++) {
        shape[k] = kept[k] < 0 ? 1 : input->shape[kept[k]];
    }
    output = revenant_ml_tensor_make(kept_count, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return output;
    }
    revenant_ml_row_major_strides(input->shape, input->rank, strides);
    for (at = 0; at < output.count; at++) {
        int next = 0;
        revenant_ml_unravel((int64_t)at, kept_count, shape, position);
        for (k = 0; k < source_rank; k++) {
            source[k] = 0;
        }
        for (k = 0; k < kept_count; k++) {
            if (kept[k] >= 0) {
                source[kept[k]] = position[next];
                next++;
            }
        }
        output.data[at] = input->data[revenant_ml_ravel(source, source_rank, strides)];
    }
    return output;
}

int revenant_ml_layer_squeeze(const revenant_ml_node *layer, const revenant_ml_node *params,
                            revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int kept[REVENANT_ML_MAX_RANK];
    int kept_count = 0, all, axis;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    all = revenant_ml_integer_of(params, "squeezeAll", 0) != 0;
    for (axis = 0; axis < input->rank; axis++) {
        int drop = all && input->shape[axis] == 1;
        if (revenant_ml_int_at(params, "axes", (size_t)axis, -1) == 1) {
            drop = 1;
        }
        if (drop) {
            continue;
        }
        if (kept_count >= REVENANT_ML_MAX_RANK) {
            snprintf(error, error_size, "the layer '%s' keeps more dimensions than this port holds",
                     revenant_ml_layer_name(layer));
            return 0;
        }
        kept[kept_count++] = axis;
    }
    if (kept_count == 0) {
        kept[0] = -1;
        kept_count = 1;
    }
    return take_output(layer, bindings, gather_axes(layer, bindings, kept, kept_count, input->rank, error, error_size),
                       error, error_size);
}

int revenant_ml_layer_expand_dims(const revenant_ml_node *layer, const revenant_ml_node *params,
                                revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    int added[REVENANT_ML_MAX_RANK], kept[REVENANT_ML_MAX_RANK];
    int added_count, kept_count = 0, rank, index, k;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    added_count = (int)revenant_ml_count_field(params, "axes");
    rank = input->rank + added_count;
    if (added_count < 0 || rank > REVENANT_ML_MAX_RANK) {
        snprintf(error, error_size, "the layer '%s' expands to more dimensions than this port holds",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    for (index = 0; index < rank; index++) {
        added[index] = 0;
    }
    for (index = 0; index < added_count; index++) {
        int where = revenant_ml_int_at(params, "axes", (size_t)index, 0);
        if (where < 0) {
            where += rank;
        }
        if (where < 0 || where >= rank) {
            snprintf(error, error_size, "the layer '%s' inserts a dimension at %d, which is outside its output",
                     revenant_ml_layer_name(layer), where);
            return 0;
        }
        added[where] = 1;
    }
    for (index = 0; index < rank; index++) {
        if (!added[index]) {
            if (kept_count >= input->rank) {
                snprintf(error, error_size, "the layer '%s' names fewer dimensions to insert than it has input",
                         revenant_ml_layer_name(layer));
                return 0;
            }
            kept[kept_count++] = index;
        }
    }
    if (kept_count != input->rank) {
        snprintf(error, error_size, "the layer '%s' names %d dimensions to insert, leaving room for %d of its %d",
                 revenant_ml_layer_name(layer), added_count, kept_count, input->rank);
        return 0;
    }
    (void)k;
    return take_output(layer, bindings, gather_axes(layer, bindings, kept, kept_count, input->rank, error, error_size),
                       error, error_size);
}

int revenant_ml_layer_tile(const revenant_ml_node *layer, const revenant_ml_node *params,
                         revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    revenant_ml_tensor output;
    int64_t shape[REVENANT_ML_MAX_RANK], position[REVENANT_ML_MAX_RANK], source[REVENANT_ML_MAX_RANK];
    int64_t strides[REVENANT_ML_MAX_RANK];
    int rank, axis;
    size_t at;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    rank = input->rank;
    if ((int)revenant_ml_count_field(params, "reps") != rank) {
        snprintf(error, error_size, "the layer '%s' is given %d repeats for an input of %d dimensions",
                 revenant_ml_layer_name(layer), (int)revenant_ml_count_field(params, "reps"), rank);
        return 0;
    }
    for (axis = 0; axis < rank; axis++) {
        int64_t times = revenant_ml_int_at(params, "reps", (size_t)axis, 1);
        if (times < 1) {
            snprintf(error, error_size, "the layer '%s' repeats a dimension fewer than once", revenant_ml_layer_name(layer));
            return 0;
        }
        shape[axis] = input->shape[axis] * times;
    }
    output = revenant_ml_tensor_make(rank, shape);
    if (output.data == NULL) {
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    revenant_ml_row_major_strides(input->shape, rank, strides);
    for (at = 0; at < output.count; at++) {
        revenant_ml_unravel((int64_t)at, rank, shape, position);
        for (axis = 0; axis < rank; axis++) {
            source[axis] = position[axis] % input->shape[axis];
        }
        output.data[at] = input->data[revenant_ml_ravel(source, rank, strides)];
    }
    return take_output(layer, bindings, output, error, error_size);
}

int revenant_ml_layer_simple_recurrent(const revenant_ml_node *layer, const revenant_ml_node *params,
                                     revenant_ml_bindings *bindings, char *error, size_t error_size)
{
    revenant_ml_tensor *input = revenant_ml_input(bindings, layer);
    double *wx = NULL, *wh = NULL, *bias = NULL;
    size_t wx_count = 0, wh_count = 0, bias_count = 0;
    int input_size, hidden_size, activation, reverse, has_bias, has_state;
    char initial_name[256];
    revenant_ml_tensor *initial = NULL;
    int64_t steps, shape[2];
    revenant_ml_tensor output;
    float *state;

    if (input == NULL) {
        return revenant_ml_layer_missing_input(layer, "input", error, error_size);
    }
    input_size = revenant_ml_integer_of(params, "inputVectorSize", 0);
    hidden_size = revenant_ml_integer_of(params, "outputVectorSize", 0);
    activation = revenant_ml_activation_kind(revenant_ml_get(params, "activation"));
    reverse = revenant_ml_integer_of(params, "reverseInput", 0) != 0;
    has_bias = revenant_ml_integer_of(params, "hasBiasVector", 0) != 0;
    has_state = revenant_ml_name_count(layer, "input") > 1;
    if (has_state) {
        if (revenant_ml_name_at(layer, "input", 1, initial_name, sizeof initial_name) != NULL) {
            initial = revenant_ml_bindings_find(bindings, initial_name);
        }
    }
    if (input_size <= 0 || hidden_size <= 0) {
        snprintf(error, error_size, "the layer '%s' has a vector size of no length", revenant_ml_layer_name(layer));
        return 0;
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "weightMatrix"), &wx, &wx_count) ||
        wx_count != (size_t)input_size * (size_t)hidden_size) {
        free(wx);
        snprintf(error, error_size, "the layer '%s' has an input matrix of the wrong shape",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    if (!revenant_ml_read_numbers(revenant_ml_get(params, "recursionMatrix"), &wh, &wh_count) ||
        wh_count != (size_t)hidden_size * (size_t)hidden_size) {
        free(wx);
        free(wh);
        snprintf(error, error_size, "the layer '%s' has a state matrix of the wrong shape", revenant_ml_layer_name(layer));
        return 0;
    }
    if (has_bias && !revenant_ml_read_numbers(revenant_ml_get(params, "biasVector"), &bias, &bias_count)) {
        free(wx);
        free(wh);
        snprintf(error, error_size, "the layer '%s' says it has a bias vector and has none",
                 revenant_ml_layer_name(layer));
        return 0;
    }
    steps = input->count / input_size;
    shape[0] = steps;
    shape[1] = hidden_size;
    output = revenant_ml_tensor_make(2, shape);
    state = (float *)calloc((size_t)hidden_size, sizeof *state);
    if (output.data == NULL || state == NULL) {
        free(wx);
        free(wh);
        free(bias);
        free(state);
        revenant_ml_tensor_free(&output);
        snprintf(error, error_size, "the layer '%s' has an output of no room for it", revenant_ml_layer_name(layer));
        return 0;
    }
    if (initial != NULL && initial->count >= (size_t)hidden_size) {
        int at;
        for (at = 0; at < hidden_size; at++) {
            state[at] = initial->data[at];
        }
    }
    {
        int64_t step;
        for (step = 0; step < steps; step++) {
            int64_t at_step = reverse ? steps - 1 - step : step;
            int hidden, in;
            float *next = (float *)calloc((size_t)hidden_size, sizeof *next);
            if (next == NULL) {
                break;
            }
            for (hidden = 0; hidden < hidden_size; hidden++) {
                double total = has_bias && bias_count > (size_t)hidden ? bias[hidden] : 0.0;
                for (in = 0; in < input_size; in++) {
                    total += wx[(size_t)(in * hidden_size + hidden)] *
                             (double)input->data[at_step * input_size + in];
                }
                for (in = 0; in < hidden_size; in++) {
                    total += wh[(size_t)(in * hidden_size + hidden)] * (double)state[in];
                }
                next[hidden] = (float)revenant_ml_activate(activation, total, revenant_ml_get(params, "activation"));
            }
            memcpy(state, next, (size_t)hidden_size * sizeof *state);
            memcpy(output.data + at_step * hidden_size, next, (size_t)hidden_size * sizeof *next);
            free(next);
        }
    }
    (void)has_state;
    free(wx);
    free(wh);
    free(bias);
    free(state);
    return take_output(layer, bindings, output, error, error_size);
}
