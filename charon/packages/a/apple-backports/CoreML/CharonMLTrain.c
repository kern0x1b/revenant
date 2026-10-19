#include "CharonMLTrain.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    LAYER_CONVOLUTION,
    LAYER_FLATTEN,
    LAYER_INNER_PRODUCT
} layer_kind;

typedef enum {
    OPTIMISER_SGD,
    OPTIMISER_ADAM
} optimiser_kind;

typedef struct {
    layer_kind kind;
    char name[256];
    int updatable;
    size_t in_channels, in_height, in_width;
    size_t out_channels, out_height, out_width;
    size_t kernel_height, kernel_width, stride_height, stride_width;
    size_t in_count, out_count;
    int has_bias;
    float *weight, *bias;
    size_t weight_count, bias_count;
    float *grad_weight, *grad_bias;
    float *state_weight, *state_bias, *state2_weight, *state2_bias;
} layer;

struct charon_ml_trainer {
    layer *layers;
    size_t layer_count;
    size_t trainable_count;
    size_t input_channels, input_height, input_width;
    size_t input_count, output_count;
    optimiser_kind optimiser;
    double learning_rate, momentum, beta1, beta2, eps;
    size_t minibatch;
    long long epochs;
    long long steps;
};

static void fail(char *error, size_t size, const char *what, const char *name)
{
    if (error && size > 0) {
        snprintf(error, size, "%s%s%s", what, name ? " " : "", name ? name : "");
    }
}

#define TRAIN_MAX_VALUES ((size_t)1 << 28)

static int dimension(int value, size_t *out)
{
    if (value <= 0 || (size_t)value > TRAIN_MAX_VALUES) {
        return 0;
    }
    *out = (size_t)value;
    return 1;
}

static int product(size_t a, size_t b, size_t *out)
{
    if (b != 0 && a > TRAIN_MAX_VALUES / b) {
        return 0;
    }
    *out = a * b;
    return 1;
}

static int volume(size_t a, size_t b, size_t c, size_t *out)
{
    size_t ab = 0;
    return product(a, b, &ab) && product(ab, c, out);
}

static int volume4(size_t a, size_t b, size_t c, size_t d, size_t *out)
{
    size_t abc = 0;
    return volume(a, b, c, &abc) && product(abc, d, out);
}

static const charon_ml_node *child(const charon_ml_node *node, const char *name)
{
    return node ? charon_ml_get(node, name) : NULL;
}

static double number_parameter(const charon_ml_node *parameter, const char *name, double fallback)
{
    const charon_ml_node *value = child(parameter, name);
    return value ? charon_ml_double(child(value, "defaultValue"), fallback) : fallback;
}

static long long integer_parameter(const charon_ml_node *parameter, const char *name, long long fallback)
{
    const charon_ml_node *value = child(parameter, name);
    return value ? charon_ml_int(child(value, "defaultValue"), fallback) : fallback;
}

static float *read_tensor(const charon_ml_node *params, size_t expected, size_t *count)
{
    if (!params) {
        return NULL;
    }
    size_t n = charon_ml_count_field(params, "floatValue");
    if (n != expected) {
        return NULL;
    }
    float *values = malloc(sizeof(float) * (n ? n : 1));
    if (!values) {
        return NULL;
    }
    for (size_t i = 0; i < n; i++) {
        values[i] = (float)charon_ml_double_at(params, "floatValue", i, 0);
    }
    *count = n;
    return values;
}

static float *zeros(size_t count)
{
    return calloc(count ? count : 1, sizeof(float));
}

static void free_layer(layer *l)
{
    free(l->weight);
    free(l->bias);
    free(l->grad_weight);
    free(l->grad_bias);
    free(l->state_weight);
    free(l->state_bias);
    free(l->state2_weight);
    free(l->state2_bias);
}

void charon_ml_trainer_free(charon_ml_trainer *trainer)
{
    if (!trainer) {
        return;
    }
    for (size_t i = 0; i < trainer->layer_count; i++) {
        free_layer(&trainer->layers[i]);
    }
    free(trainer->layers);
    free(trainer);
}

static int input_shape(const charon_ml_node *document, size_t *channels, size_t *height, size_t *width)
{
    const charon_ml_node *description = child(document, "description");
    const charon_ml_node *feature = description ? charon_ml_node_at_field(description, "input", 0) : NULL;
    const charon_ml_node *multi = child(child(feature, "type"), "multiArrayType");
    size_t rank = multi ? charon_ml_count_field(multi, "shape") : 0;
    if (rank == 3) {
        return dimension(charon_ml_int_at(multi, "shape", 0, 0), channels) &&
               dimension(charon_ml_int_at(multi, "shape", 1, 0), height) &&
               dimension(charon_ml_int_at(multi, "shape", 2, 0), width);
    }
    if (rank == 1) {
        *height = 1;
        *width = 1;
        return dimension(charon_ml_int_at(multi, "shape", 0, 0), channels);
    }
    return 0;
}

charon_ml_trainer *charon_ml_trainer_new(const charon_ml_node *document, char *error, size_t error_size)
{
    const charon_ml_node *network = charon_ml_oneof(document, "neuralNetwork");
    if (!network) {
        fail(error, error_size, "the model has no neural network to train", NULL);
        return NULL;
    }
    const charon_ml_node *update = child(network, "updateParams");
    if (!update) {
        fail(error, error_size, "the neural network is not updatable: it has no update parameters", NULL);
        return NULL;
    }

    charon_ml_trainer *trainer = calloc(1, sizeof *trainer);
    if (!trainer) {
        return NULL;
    }

    const charon_ml_node *loss_layer = charon_ml_node_at_field(update, "lossLayers", 0);
    if (!charon_ml_oneof(loss_layer, "meanSquaredErrorLossLayer")) {
        fail(error, error_size, "the loss is not the mean squared error", NULL);
        free(trainer);
        return NULL;
    }

    const charon_ml_node *optimiser = child(update, "optimizer");
    const charon_ml_node *sgd = charon_ml_oneof(optimiser, "sgdOptimizer");
    const charon_ml_node *adam = charon_ml_oneof(optimiser, "adamOptimizer");
    const charon_ml_node *hyper = sgd ? sgd : adam;
    if (!hyper) {
        fail(error, error_size, "the optimiser is neither stochastic gradient descent nor Adam", NULL);
        free(trainer);
        return NULL;
    }
    trainer->optimiser = adam ? OPTIMISER_ADAM : OPTIMISER_SGD;
    trainer->learning_rate = number_parameter(hyper, "learningRate", 0);
    trainer->minibatch = (size_t)integer_parameter(hyper, "miniBatchSize", 1);
    if (trainer->optimiser == OPTIMISER_SGD) {
        trainer->momentum = number_parameter(hyper, "momentum", 0);
    } else {
        trainer->beta1 = number_parameter(hyper, "beta1", 0.9);
        trainer->beta2 = number_parameter(hyper, "beta2", 0.999);
        trainer->eps = number_parameter(hyper, "eps", 1e-8);
    }
    trainer->epochs = integer_parameter(update, "epochs", 1);
    if (trainer->minibatch == 0 || trainer->minibatch > TRAIN_MAX_VALUES || trainer->epochs <= 0) {
        fail(error, error_size, "the mini-batch size and the epoch count must be positive and within the limit", NULL);
        free(trainer);
        return NULL;
    }
    const charon_ml_node *shuffle = child(update, "shuffle");
    if (shuffle && charon_ml_int(child(shuffle, "defaultValue"), 0) != 0) {
        fail(error, error_size, "shuffled training is not implemented", NULL);
        free(trainer);
        return NULL;
    }

    if (!input_shape(document, &trainer->input_channels, &trainer->input_height, &trainer->input_width) ||
        !volume(trainer->input_channels, trainer->input_height, trainer->input_width, &trainer->input_count)) {
        fail(error, error_size, "the input is not an image or a vector the trainer can read", NULL);
        free(trainer);
        return NULL;
    }

    size_t count = charon_ml_count_field(network, "layers");
    trainer->layers = calloc(count ? count : 1, sizeof(layer));
    if (!trainer->layers) {
        free(trainer);
        return NULL;
    }

    size_t channels = trainer->input_channels, height = trainer->input_height, width = trainer->input_width;
    int vector = 0;
    size_t flat = trainer->input_count;
    for (size_t i = 0; i < count; i++) {
        const charon_ml_node *node = charon_ml_node_at_field(network, "layers", i);
        layer *l = &trainer->layers[trainer->layer_count++];
        memset(l, 0, sizeof *l);
        char name[256] = "";
        charon_ml_text(child(node, "name"), name, sizeof name);
        snprintf(l->name, sizeof l->name, "%s", name);
        l->updatable = charon_ml_int(child(node, "isUpdatable"), 0) != 0;
        const charon_ml_node *conv = charon_ml_oneof(node, "convolution");
        const charon_ml_node *flatten = charon_ml_oneof(node, "flatten");
        const charon_ml_node *ip = charon_ml_oneof(node, "innerProduct");
        if (conv) {
            if (vector || charon_ml_oneof(conv, "same") || charon_ml_int_at(conv, "dilationFactor", 0, 1) != 1 ||
                charon_ml_int_at(conv, "dilationFactor", 1, 1) != 1 || charon_ml_int(child(conv, "nGroups"), 1) != 1 ||
                charon_ml_int(child(conv, "isDeconvolution"), 0) != 0) {
                fail(error, error_size, "the convolution is not one the trainer runs (valid padding, one group, no dilation):", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->kind = LAYER_CONVOLUTION;
            l->in_channels = channels;
            l->in_height = height;
            l->in_width = width;
            l->has_bias = charon_ml_int(child(conv, "hasBias"), 0) != 0;
            if (!dimension(charon_ml_int(child(conv, "outputChannels"), 0), &l->out_channels) ||
                !dimension(charon_ml_int_at(conv, "kernelSize", 0, 0), &l->kernel_height) ||
                !dimension(charon_ml_int_at(conv, "kernelSize", 1, 0), &l->kernel_width) ||
                !dimension(charon_ml_int_at(conv, "stride", 0, 1), &l->stride_height) ||
                !dimension(charon_ml_int_at(conv, "stride", 1, 1), &l->stride_width) ||
                l->in_height < l->kernel_height || l->in_width < l->kernel_width) {
                fail(error, error_size, "the convolution's shape is not one the trainer runs:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->out_height = (l->in_height - l->kernel_height) / l->stride_height + 1;
            l->out_width = (l->in_width - l->kernel_width) / l->stride_width + 1;
            channels = l->out_channels;
            height = l->out_height;
            width = l->out_width;
            if (!volume(l->in_channels, l->in_height, l->in_width, &l->in_count) ||
                !volume(l->out_channels, l->out_height, l->out_width, &l->out_count) ||
                !volume4(l->out_channels, l->in_channels, l->kernel_height, l->kernel_width, &l->weight_count)) {
                fail(error, error_size, "the convolution is too large for the trainer:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->bias_count = l->has_bias ? l->out_channels : 0;
            l->weight = read_tensor(child(conv, "weights"), l->weight_count, &l->weight_count);
            if (!l->weight || (l->has_bias && !(l->bias = read_tensor(child(conv, "bias"), l->bias_count, &l->bias_count)))) {
                fail(error, error_size, "the convolution's weights are missing or not the size its shape says:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            flat = l->out_count;
        } else if (flatten) {
            if (charon_ml_int(child(flatten, "mode"), 0) != 0 || vector) {
                fail(error, error_size, "the flatten is not the channel-first one the trainer runs:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->kind = LAYER_FLATTEN;
            if (!volume(channels, height, width, &l->in_count)) {
                fail(error, error_size, "the flatten is too large for the trainer:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->out_count = l->in_count;
            vector = 1;
            flat = l->out_count;
        } else if (ip) {
            l->kind = LAYER_INNER_PRODUCT;
            size_t in = 0, out = 0;
            if (!dimension(charon_ml_int(child(ip, "inputChannels"), 0), &in) ||
                !dimension(charon_ml_int(child(ip, "outputChannels"), 0), &out) || in != flat) {
                fail(error, error_size, "the inner product's input size does not match the layer before it:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->has_bias = charon_ml_int(child(ip, "hasBias"), 0) != 0;
            l->in_count = in;
            l->out_count = out;
            l->out_channels = out;
            if (!product(in, out, &l->weight_count)) {
                fail(error, error_size, "the inner product is too large for the trainer:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            l->bias_count = l->has_bias ? out : 0;
            l->weight = read_tensor(child(ip, "weights"), l->weight_count, &l->weight_count);
            if (!l->weight || (l->has_bias && !(l->bias = read_tensor(child(ip, "bias"), l->bias_count, &l->bias_count)))) {
                fail(error, error_size, "the inner product's weights are missing or not the size its shape says:", l->name);
                charon_ml_trainer_free(trainer);
                return NULL;
            }
            vector = 1;
            flat = out;
        } else {
            fail(error, error_size, "a layer the trainer does not run:", l->name);
            charon_ml_trainer_free(trainer);
            return NULL;
        }
        if (l->weight_count) {
            l->grad_weight = zeros(l->weight_count);
            l->state_weight = zeros(l->weight_count);
            l->state2_weight = zeros(l->weight_count);
        }
        if (l->bias_count) {
            l->grad_bias = zeros(l->bias_count);
            l->state_bias = zeros(l->bias_count);
            l->state2_bias = zeros(l->bias_count);
        }
        if (l->weight_count) {
            trainer->trainable_count++;
        }
    }
    trainer->output_count = trainer->layer_count ? trainer->layers[trainer->layer_count - 1].out_count : 0;
    if (trainer->layer_count == 0 || trainer->output_count == 0) {
        fail(error, error_size, "the network has no layers to train", NULL);
        charon_ml_trainer_free(trainer);
        return NULL;
    }
    return trainer;
}

size_t charon_ml_trainer_minibatch_size(const charon_ml_trainer *trainer) { return trainer->minibatch; }
long long charon_ml_trainer_epochs(const charon_ml_trainer *trainer) { return trainer->epochs; }
size_t charon_ml_trainer_input_count(const charon_ml_trainer *trainer) { return trainer->input_count; }
size_t charon_ml_trainer_output_count(const charon_ml_trainer *trainer) { return trainer->output_count; }

size_t charon_ml_trainer_layer_count(const charon_ml_trainer *trainer)
{
    return trainer->trainable_count;
}

static const layer *trainable(const charon_ml_trainer *trainer, size_t which)
{
    size_t seen = 0;
    for (size_t i = 0; i < trainer->layer_count; i++) {
        if (trainer->layers[i].weight_count) {
            if (seen == which) {
                return &trainer->layers[i];
            }
            seen++;
        }
    }
    return NULL;
}

const char *charon_ml_trainer_layer_name(const charon_ml_trainer *trainer, size_t which)
{
    const layer *l = trainable(trainer, which);
    return l ? l->name : NULL;
}

const char *charon_ml_trainer_layer_kind(const charon_ml_trainer *trainer, size_t which)
{
    const layer *l = trainable(trainer, which);
    if (!l) {
        return NULL;
    }
    return l->kind == LAYER_CONVOLUTION ? "convolution" : "innerProduct";
}

const float *charon_ml_trainer_tensor(const charon_ml_trainer *trainer, size_t which, int bias, size_t *count)
{
    const layer *l = trainable(trainer, which);
    if (!l) {
        *count = 0;
        return NULL;
    }
    *count = bias ? l->bias_count : l->weight_count;
    return bias ? l->bias : l->weight;
}

static void forward(const layer *l, const float *in, float *out)
{
    switch (l->kind) {
    case LAYER_FLATTEN:
        memcpy(out, in, sizeof(float) * l->out_count);
        break;
    case LAYER_INNER_PRODUCT:
        for (size_t o = 0; o < l->out_count; o++) {
            float sum = l->has_bias ? l->bias[o] : 0;
            const float *w = l->weight + o * l->in_count;
            for (size_t k = 0; k < l->in_count; k++) {
                sum += w[k] * in[k];
            }
            out[o] = sum;
        }
        break;
    case LAYER_CONVOLUTION:
        for (size_t o = 0; o < l->out_channels; o++) {
            for (size_t i = 0; i < l->out_height; i++) {
                for (size_t j = 0; j < l->out_width; j++) {
                    float sum = l->has_bias ? l->bias[o] : 0;
                    for (size_t c = 0; c < l->in_channels; c++) {
                        for (size_t ky = 0; ky < l->kernel_height; ky++) {
                            for (size_t kx = 0; kx < l->kernel_width; kx++) {
                                size_t y = i * l->stride_height + ky, x = j * l->stride_width + kx;
                                sum += l->weight[((o * l->in_channels + c) * l->kernel_height + ky) * l->kernel_width + kx] *
                                       in[(c * l->in_height + y) * l->in_width + x];
                            }
                        }
                    }
                    out[(o * l->out_height + i) * l->out_width + j] = sum;
                }
            }
        }
        break;
    }
}

static void backward(layer *l, const float *in, const float *grad_out, float *grad_in)
{
    switch (l->kind) {
    case LAYER_FLATTEN:
        if (grad_in) {
            memcpy(grad_in, grad_out, sizeof(float) * l->in_count);
        }
        break;
    case LAYER_INNER_PRODUCT:
        if (grad_in) {
            memset(grad_in, 0, sizeof(float) * l->in_count);
        }
        for (size_t o = 0; o < l->out_count; o++) {
            float g = grad_out[o];
            float *gw = l->grad_weight + o * l->in_count;
            const float *w = l->weight + o * l->in_count;
            for (size_t k = 0; k < l->in_count; k++) {
                gw[k] += g * in[k];
                if (grad_in) {
                    grad_in[k] += w[k] * g;
                }
            }
            if (l->has_bias) {
                l->grad_bias[o] += g;
            }
        }
        break;
    case LAYER_CONVOLUTION:
        if (grad_in) {
            memset(grad_in, 0, sizeof(float) * l->in_count);
        }
        for (size_t o = 0; o < l->out_channels; o++) {
            for (size_t i = 0; i < l->out_height; i++) {
                for (size_t j = 0; j < l->out_width; j++) {
                    float g = grad_out[(o * l->out_height + i) * l->out_width + j];
                    if (l->has_bias) {
                        l->grad_bias[o] += g;
                    }
                    for (size_t c = 0; c < l->in_channels; c++) {
                        for (size_t ky = 0; ky < l->kernel_height; ky++) {
                            for (size_t kx = 0; kx < l->kernel_width; kx++) {
                                size_t y = i * l->stride_height + ky, x = j * l->stride_width + kx;
                                size_t wi = ((o * l->in_channels + c) * l->kernel_height + ky) * l->kernel_width + kx;
                                size_t xi = (c * l->in_height + y) * l->in_width + x;
                                l->grad_weight[wi] += g * in[xi];
                                if (grad_in) {
                                    grad_in[xi] += l->weight[wi] * g;
                                }
                            }
                        }
                    }
                }
            }
        }
        break;
    }
}

static size_t boundary_size(const charon_ml_trainer *trainer, size_t index)
{
    return index == 0 ? trainer->input_count : trainer->layers[index - 1].out_count;
}

static void apply(float *value, float *velocity, float *second, const float *gradient, size_t count,
                  const charon_ml_trainer *trainer)
{
    if (trainer->optimiser == OPTIMISER_SGD) {
        float lr = (float)trainer->learning_rate;
        float mu = (float)trainer->momentum;
        for (size_t i = 0; i < count; i++) {
            velocity[i] = mu * velocity[i] + gradient[i];
            value[i] -= lr * velocity[i];
        }
        return;
    }
    double b1 = trainer->beta1, b2 = trainer->beta2, eps = trainer->eps, rate = trainer->learning_rate;
    double t = (double)trainer->steps;
    double c1 = 1.0 - pow(b1, t), c2 = 1.0 - pow(b2, t);
    for (size_t i = 0; i < count; i++) {
        velocity[i] = (float)(b1 * velocity[i] + (1.0 - b1) * gradient[i]);
        second[i] = (float)(b2 * second[i] + (1.0 - b2) * gradient[i] * gradient[i]);
        double mhat = velocity[i] / c1, vhat = second[i] / c2;
        value[i] = (float)((double)value[i] - rate * mhat / (sqrt(vhat) + eps));
    }
}

int charon_ml_trainer_step(charon_ml_trainer *trainer, const float *inputs, const float *targets, size_t samples,
                           char *error, size_t error_size)
{
    if (samples == 0) {
        return 1;
    }
    float **act = calloc(trainer->layer_count + 1, sizeof(float *));
    float **grad = calloc(trainer->layer_count + 1, sizeof(float *));
    if (!act || !grad) {
        free(act);
        free(grad);
        fail(error, error_size, "out of memory for the mini-batch", NULL);
        return 0;
    }
    int ok = 1, fits = 1;
    for (size_t i = 0; ok && i <= trainer->layer_count; i++) {
        size_t size = 0;
        if (!product(samples, boundary_size(trainer, i), &size)) {
            fits = 0;
            break;
        }
        act[i] = malloc(sizeof(float) * size);
        grad[i] = malloc(sizeof(float) * size);
        ok = act[i] && grad[i];
    }
    if (!fits) {
        fail(error, error_size, "the mini-batch is too large for the trainer", NULL);
        ok = 0;
        goto done;
    }
    if (!ok) {
        fail(error, error_size, "out of memory for the mini-batch", NULL);
        goto done;
    }
    memcpy(act[0], inputs, sizeof(float) * samples * trainer->input_count);

    for (size_t s = 0; s < samples; s++) {
        for (size_t l = 0; l < trainer->layer_count; l++) {
            const layer *ly = &trainer->layers[l];
            forward(ly, act[l] + s * boundary_size(trainer, l), act[l + 1] + s * boundary_size(trainer, l + 1));
        }
    }

    size_t last = trainer->layer_count;
    float scale = 2.0f / (float)(samples * trainer->output_count);
    for (size_t s = 0; s < samples; s++) {
        for (size_t o = 0; o < trainer->output_count; o++) {
            float y = act[last][s * trainer->output_count + o];
            grad[last][s * trainer->output_count + o] = scale * (y - targets[s * trainer->output_count + o]);
        }
    }

    for (size_t l = trainer->layer_count; l-- > 0;) {
        layer *ly = &trainer->layers[l];
        for (size_t s = 0; s < samples; s++) {
            backward(ly, act[l] + s * boundary_size(trainer, l), grad[l + 1] + s * boundary_size(trainer, l + 1),
                     l == 0 ? NULL : grad[l] + s * boundary_size(trainer, l));
        }
    }

    trainer->steps++;
    for (size_t l = 0; l < trainer->layer_count; l++) {
        layer *ly = &trainer->layers[l];
        if (!ly->updatable || !ly->weight_count) {
            continue;
        }
        apply(ly->weight, ly->state_weight, ly->state2_weight, ly->grad_weight, ly->weight_count, trainer);
        if (ly->bias_count) {
            apply(ly->bias, ly->state_bias, ly->state2_bias, ly->grad_bias, ly->bias_count, trainer);
        }
    }
    for (size_t l = 0; l < trainer->layer_count; l++) {
        layer *ly = &trainer->layers[l];
        if (ly->grad_weight) {
            memset(ly->grad_weight, 0, sizeof(float) * ly->weight_count);
        }
        if (ly->grad_bias) {
            memset(ly->grad_bias, 0, sizeof(float) * ly->bias_count);
        }
    }

done:
    for (size_t l = 0; l <= trainer->layer_count; l++) {
        free(act[l]);
        free(grad[l]);
    }
    free(act);
    free(grad);
    return ok;
}

static int store_tensor(const charon_ml_node *params, const float *values, size_t count)
{
    if (!params || charon_ml_count_field(params, "floatValue") != count) {
        return 0;
    }
    for (size_t i = 0; i < count; i++) {
        charon_ml_node *entry = (charon_ml_node *)charon_ml_node_at_field(params, "floatValue", i);
        if (!entry) {
            return 0;
        }
        entry->value.number = (double)values[i];
    }
    return 1;
}

int charon_ml_trainer_store(const charon_ml_trainer *trainer, charon_ml_node *document)
{
    const charon_ml_node *network = charon_ml_oneof(document, "neuralNetwork");
    if (!network) {
        return 0;
    }
    size_t index = 0;
    for (size_t i = 0; i < trainer->layer_count; i++) {
        const layer *l = &trainer->layers[i];
        if (!l->weight_count) {
            continue;
        }
        const charon_ml_node *node = charon_ml_node_at_field(network, "layers", i);
        if (!node) {
            return 0;
        }
        const charon_ml_node *params = charon_ml_oneof(node, l->kind == LAYER_CONVOLUTION ? "convolution" : "innerProduct");
        if (!params) {
            return 0;
        }
        if (!store_tensor(child(params, "weights"), l->weight, l->weight_count)) {
            return 0;
        }
        if (l->bias_count && !store_tensor(child(params, "bias"), l->bias, l->bias_count)) {
            return 0;
        }
        index++;
    }
    return index == trainer->trainable_count;
}
