#import "check.h"
#import "RevenantMLProto.h"
#import "RevenantMLTrain.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    unsigned char *bytes;
    size_t length;
} buffer;

static void put(buffer *b, const void *data, size_t count)
{
    b->bytes = realloc(b->bytes, b->length + count);
    memcpy(b->bytes + b->length, data, count);
    b->length += count;
}

static void put_varint(buffer *b, uint64_t value)
{
    while (value >= 0x80) {
        unsigned char byte = (unsigned char)(value | 0x80);
        put(b, &byte, 1);
        value >>= 7;
    }
    unsigned char last = (unsigned char)value;
    put(b, &last, 1);
}

static void field_varint(buffer *b, int field, uint64_t value)
{
    put_varint(b, (uint64_t)field << 3);
    put_varint(b, value);
}

static void field_double(buffer *b, int field, double value)
{
    put_varint(b, ((uint64_t)field << 3) | 1);
    put(b, &value, sizeof value);
}

static void field_bytes(buffer *b, int field, const void *data, size_t count)
{
    put_varint(b, ((uint64_t)field << 3) | 2);
    put_varint(b, count);
    put(b, data, count);
}

static void field_string(buffer *b, int field, const char *text)
{
    field_bytes(b, field, text, strlen(text));
}

static void field_message(buffer *b, int field, buffer *child)
{
    field_bytes(b, field, child->bytes, child->length);
    free(child->bytes);
    child->bytes = NULL;
    child->length = 0;
}

static void field_floats(buffer *b, int field, const float *values, size_t count)
{
    field_bytes(b, field, values, sizeof(float) * count);
}

static void parameter_int(buffer *b, int field, int64_t value)
{
    buffer parameter = {0};
    field_varint(&parameter, 1, (uint64_t)value);
    field_message(b, field, &parameter);
}

static void parameter_double(buffer *b, int field, double value)
{
    buffer parameter = {0};
    field_double(&parameter, 1, value);
    field_message(b, field, &parameter);
}

static buffer weights_of(const float *values, size_t count)
{
    buffer weights = {0};
    field_floats(&weights, 1, values, count);
    return weights;
}

static buffer model(size_t minibatch, int64_t epochs, int shuffle, int64_t seed)
{
    static const float weight[2] = {0.1f, -0.2f};
    static const float bias[1] = {0.05f};

    buffer product = {0};
    field_varint(&product, 1, 2);
    field_varint(&product, 2, 1);
    field_varint(&product, 10, 1);
    buffer w = weights_of(weight, 2);
    field_message(&product, 20, &w);
    buffer b = weights_of(bias, 1);
    field_message(&product, 21, &b);

    buffer layer = {0};
    field_string(&layer, 1, "ip");
    field_string(&layer, 2, "x");
    field_string(&layer, 3, "y");
    field_varint(&layer, 10, 1);
    field_message(&layer, 140, &product);

    buffer mse = {0};
    field_string(&mse, 1, "y");
    field_string(&mse, 2, "t");
    buffer loss = {0};
    field_string(&loss, 1, "loss");
    field_message(&loss, 11, &mse);

    buffer sgd = {0};
    parameter_double(&sgd, 1, 0.1);
    parameter_int(&sgd, 2, (int64_t)minibatch);
    parameter_double(&sgd, 3, 0.0);
    buffer optimizer = {0};
    field_message(&optimizer, 10, &sgd);

    buffer update = {0};
    field_message(&update, 1, &loss);
    field_message(&update, 2, &optimizer);
    parameter_int(&update, 3, epochs);
    parameter_int(&update, 10, shuffle);
    parameter_int(&update, 20, seed);

    buffer network = {0};
    field_message(&network, 1, &layer);
    field_message(&network, 10, &update);

    buffer shape = {0};
    put_varint(&shape, 2);
    buffer array = {0};
    field_bytes(&array, 1, shape.bytes, shape.length);
    free(shape.bytes);
    field_varint(&array, 2, 65568);
    buffer type = {0};
    field_message(&type, 5, &array);
    buffer input = {0};
    field_string(&input, 1, "x");
    field_message(&input, 3, &type);
    buffer description = {0};
    field_message(&description, 1, &input);

    buffer document = {0};
    field_varint(&document, 1, 8);
    field_message(&document, 2, &description);
    field_varint(&document, 10, 1);
    field_message(&document, 500, &network);
    return document;
}

static revenant_ml_trainer *trainer_of(size_t minibatch, int64_t epochs, int shuffle, int64_t seed, char *error, size_t error_size)
{
    buffer bytes = model(minibatch, epochs, shuffle, seed);
    revenant_ml_node document;
    if (!revenant_ml_read(&document, bytes.bytes, bytes.length, "CoreML.Specification.Model")) {
        free(bytes.bytes);
        snprintf(error, error_size, "the test model does not parse");
        return NULL;
    }
    free(bytes.bytes);
    revenant_ml_trainer *trainer = revenant_ml_trainer_new(&document, error, error_size);
    revenant_ml_free(&document);
    return trainer;
}

#define SAMPLES 6

static const float inputs[SAMPLES * 2] = {1, 0.5f, -0.5f, 1, 0.25f, -1, 1.5f, 0.75f, -1, -0.5f, 0.5f, 1.25f};
static const float targets[SAMPLES] = {1, -0.5f, 2, 0.25f, -1.5f, 0.75f};

static void train(revenant_ml_trainer *trainer, int64_t epochs, size_t minibatch)
{
    char error[256] = "";
    for (int64_t epoch = 0; epoch < epochs; epoch++) {
        for (size_t first = 0; first < SAMPLES; first += minibatch) {
            if (!revenant_ml_trainer_batch(trainer, epoch, first, inputs, targets, SAMPLES, error, sizeof error)) {
                printf("batch failed: %s\n", error);
                return;
            }
        }
    }
}

static void reference(const revenant_ml_trainer *order_source, int64_t epochs, size_t minibatch, double *parameters)
{
    parameters[0] = 0.1f;
    parameters[1] = -0.2f;
    parameters[2] = 0.05f;
    for (int64_t epoch = 0; epoch < epochs; epoch++) {
        size_t order[SAMPLES];
        for (size_t i = 0; i < SAMPLES; i++) {
            order[i] = i;
        }
        if (order_source) {
            revenant_ml_trainer_order(order_source, epoch, SAMPLES, order);
        }
        for (size_t first = 0; first < SAMPLES; first += minibatch) {
            size_t count = SAMPLES - first < minibatch ? SAMPLES - first : minibatch;
            double gradient[3] = {0, 0, 0};
            for (size_t s = 0; s < count; s++) {
                size_t row = order[first + s];
                double y = parameters[0] * inputs[row * 2] + parameters[1] * inputs[row * 2 + 1] + parameters[2];
                double g = 2.0 * (y - targets[row]) / (double)count;
                gradient[0] += g * inputs[row * 2];
                gradient[1] += g * inputs[row * 2 + 1];
                gradient[2] += g;
            }
            for (int k = 0; k < 3; k++) {
                parameters[k] -= 0.1 * gradient[k];
            }
        }
    }
}

static void read_parameters(const revenant_ml_trainer *trainer, double *parameters)
{
    size_t count = 0;
    const float *w = revenant_ml_trainer_tensor(trainer, 0, 0, &count);
    parameters[0] = w[0];
    parameters[1] = w[1];
    const float *b = revenant_ml_trainer_tensor(trainer, 0, 1, &count);
    parameters[2] = b[0];
}

static double distance(const double *a, const double *b)
{
    double worst = 0;
    for (int k = 0; k < 3; k++) {
        worst = fmax(worst, fabs(a[k] - b[k]));
    }
    return worst;
}

static int is_permutation(const size_t *order, size_t count)
{
    unsigned char seen[64] = {0};
    for (size_t i = 0; i < count; i++) {
        if (order[i] >= count || seen[order[i]]) {
            return 0;
        }
        seen[order[i]] = 1;
    }
    return 1;
}

static int same(const size_t *a, const size_t *b, size_t count)
{
    return memcmp(a, b, sizeof(size_t) * count) == 0;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    char error[256] = "";

    revenant_ml_trainer *plain = trainer_of(1, 2, 0, 0, error, sizeof error);
    revenant_ml_trainer *shuffled = trainer_of(1, 2, 1, 7, error, sizeof error);
    revenant_check(plain != NULL && shuffled != NULL, "a model with shuffle on gives a trainer",
                   [NSString stringWithUTF8String:error]);
    if (!plain || !shuffled) {
        return revenant_finish() + 1;
    }

    size_t order[SAMPLES], again[SAMPLES], other[SAMPLES];
    revenant_ml_trainer_order(plain, 0, SAMPLES, order);
    BOOL identity = YES;
    for (size_t i = 0; i < SAMPLES; i++) {
        identity = identity && order[i] == i;
    }
    revenant_check(identity, "without shuffle the order is the order of the data", @"the order moved");

    BOOL permutations = YES, moved = NO;
    for (int64_t epoch = 0; epoch < 32; epoch++) {
        revenant_ml_trainer_order(shuffled, epoch, SAMPLES, order);
        permutations = permutations && is_permutation(order, SAMPLES);
        for (size_t i = 0; i < SAMPLES; i++) {
            moved = moved || order[i] != i;
        }
    }
    revenant_check(permutations, "every epoch visits each sample exactly once", @"an epoch repeats or drops a sample");
    revenant_check(moved, "with shuffle the order differs from the order of the data", @"every epoch kept the order");

    revenant_ml_trainer_order(shuffled, 3, SAMPLES, order);
    revenant_ml_trainer_order(shuffled, 3, SAMPLES, again);
    revenant_check(same(order, again, SAMPLES), "the same seed and epoch give the same order", @"the order changed between calls");

    BOOL epochs_differ = NO;
    for (int64_t epoch = 0; epoch < 16 && !epochs_differ; epoch++) {
        revenant_ml_trainer_order(shuffled, epoch, SAMPLES, order);
        revenant_ml_trainer_order(shuffled, epoch + 1, SAMPLES, other);
        epochs_differ = !same(order, other, SAMPLES);
    }
    revenant_check(epochs_differ, "the epochs are shuffled apart from one another", @"every epoch had the same order");

    revenant_ml_trainer *low = trainer_of(1, 1, 1, 1, error, sizeof error);
    revenant_ml_trainer *high = trainer_of(1, 1, 1, ((int64_t)1 << 32) + 1, error, sizeof error);
    BOOL seeds_differ = NO;
    for (int64_t epoch = 0; epoch < 16 && !seeds_differ; epoch++) {
        revenant_ml_trainer_order(low, epoch, SAMPLES, order);
        revenant_ml_trainer_order(high, epoch, SAMPLES, other);
        seeds_differ = !same(order, other, SAMPLES);
    }
    revenant_check(seeds_differ, "a seed beyond 32 bits is read whole", @"the seed was cut to 32 bits");
    revenant_ml_trainer_free(low);
    revenant_ml_trainer_free(high);

    revenant_ml_trainer *fair = trainer_of(1, 1, 1, 42, error, sizeof error);
    enum { EPOCHS = 12000, KINDS = 256, PERMUTATIONS = 24 };
    unsigned counts[KINDS] = {0};
    for (int64_t epoch = 0; epoch < EPOCHS; epoch++) {
        size_t four[4];
        revenant_ml_trainer_order(fair, epoch, 4, four);
        counts[four[0] * 64 + four[1] * 16 + four[2] * 4 + four[3]]++;
    }
    int kinds = 0;
    double chi = 0, expected = (double)EPOCHS / PERMUTATIONS;
    for (int k = 0; k < KINDS; k++) {
        if (counts[k]) {
            kinds++;
            chi += (counts[k] - expected) * (counts[k] - expected) / expected;
        }
    }
    revenant_check(kinds == PERMUTATIONS, "the 24 orders of four samples all occur", @"some order never occurs");
    revenant_check(chi < 49.73, "the orders of four samples are uniform (chi-square, 23 degrees, p = 0.001)",
                   [NSString stringWithFormat:@"chi-square %.1f", chi]);
    revenant_ml_trainer_free(fair);

    double trained[3], expected_parameters[3], unshuffled[3];
    train(shuffled, 2, 1);
    read_parameters(shuffled, trained);
    reference(revenant_negative ? NULL : shuffled, 2, 1, expected_parameters);
    revenant_check(distance(trained, expected_parameters) < 1e-4, "shuffled training with one sample per step follows the order it reports",
                   [NSString stringWithFormat:@"%g apart", distance(trained, expected_parameters)]);

    train(plain, 2, 1);
    read_parameters(plain, unshuffled);
    reference(NULL, 2, 1, expected_parameters);
    revenant_check(distance(unshuffled, expected_parameters) < 1e-4, "unshuffled training with one sample per step follows the data",
                   [NSString stringWithFormat:@"%g apart", distance(unshuffled, expected_parameters)]);
    revenant_check(distance(trained, unshuffled) > 1e-3, "the order changes what one sample per step learns",
                   [NSString stringWithFormat:@"%g apart", distance(trained, unshuffled)]);

    revenant_ml_trainer *whole_plain = trainer_of(SAMPLES, 3, 0, 0, error, sizeof error);
    revenant_ml_trainer *whole_shuffled = trainer_of(SAMPLES, 3, 1, 99, error, sizeof error);
    double whole[2][3];
    train(whole_plain, 3, SAMPLES);
    train(whole_shuffled, 3, SAMPLES);
    read_parameters(whole_plain, whole[0]);
    read_parameters(whole_shuffled, whole[1]);
    revenant_check(distance(whole[0], whole[1]) < 1e-5, "a batch of the whole data learns the same in any order",
                   [NSString stringWithFormat:@"%g apart", distance(whole[0], whole[1])]);

    revenant_ml_trainer *partial = trainer_of(4, 2, 1, 5, error, sizeof error);
    train(partial, 2, 4);
    read_parameters(partial, trained);
    reference(partial, 2, 4, expected_parameters);
    revenant_check(distance(trained, expected_parameters) < 1e-4, "a last batch shorter than the rest is trained on what is left",
                   [NSString stringWithFormat:@"%g apart", distance(trained, expected_parameters)]);

    revenant_ml_trainer_free(plain);
    revenant_ml_trainer_free(shuffled);
    revenant_ml_trainer_free(whole_plain);
    revenant_ml_trainer_free(whole_shuffled);
    revenant_ml_trainer_free(partial);
    return revenant_finish();
}
