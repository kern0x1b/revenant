/* train-check.c - trains a model with the port's trainer and writes the weights at the same events the host's
 * update reports, in the format dump.c and host-train.m write, so the two can be compared line by line.
 *
 * usage: train-check MODEL.mlmodel INPUT.f32 TARGET.f32 OUTDIR SAMPLES
 *
 * The events are the host's: a training-begin dump (the weights as the model holds them), then for each
 * mini-batch a mini-batch-end dump, and after the last mini-batch of an epoch an epoch-end dump. The mini-batch
 * size and the epoch count come from the model, as they do for the host, and the samples are used in file order.
 * The files are step-NNN.dump, numbered as host-train numbers its steps, and final.dump. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "CharonMLProto.h"
#include "CharonMLTrain.h"

static unsigned char *slurp(const char *path, size_t *length)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    *length = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *bytes = malloc(*length ? *length : 1);
    if (bytes && fread(bytes, 1, *length, f) != *length) {
        free(bytes);
        bytes = NULL;
    }
    fclose(f);
    return bytes;
}

static int write_dump(const charon_ml_trainer *trainer, const char *path)
{
    FILE *f = fopen(path, "w");
    if (!f) return 0;
    for (size_t which = 0; which < charon_ml_trainer_layer_count(trainer); which++) {
        fprintf(f, "layer %s %s\n", charon_ml_trainer_layer_name(trainer, which), charon_ml_trainer_layer_kind(trainer, which));
        for (int bias = 0; bias <= 1; bias++) {
            size_t count = 0;
            const float *values = charon_ml_trainer_tensor(trainer, which, bias, &count);
            fprintf(f, "%s %zu", bias ? "bias" : "weights", count);
            for (size_t i = 0; i < count; i++) fprintf(f, " %.9g", (double)values[i]);
            fprintf(f, "\n");
        }
    }
    fclose(f);
    return 1;
}

static char path[4096];

static const char *step_path(const char *dir, int step)
{
    snprintf(path, sizeof path, "%s/step-%03d.dump", dir, step);
    return path;
}

int main(int argc, char **argv)
{
    if (argc != 6) {
        fprintf(stderr, "usage: train-check MODEL.mlmodel INPUT.f32 TARGET.f32 OUTDIR SAMPLES\n");
        return 2;
    }
    size_t length = 0;
    unsigned char *bytes = slurp(argv[1], &length);
    charon_ml_node document;
    if (!bytes || !charon_ml_read(&document, bytes, length, "CoreML.Specification.Model")) {
        fprintf(stderr, "read: %s\n", argv[1]);
        return 1;
    }
    char error[512] = "";
    charon_ml_trainer *trainer = charon_ml_trainer_new(&document, error, sizeof error);
    if (!trainer) {
        fprintf(stderr, "trainer: %s\n", error);
        return 1;
    }
    size_t samples = (size_t)atol(argv[5]);
    size_t inputs = charon_ml_trainer_input_count(trainer), outputs = charon_ml_trainer_output_count(trainer);
    size_t n_in = 0, n_out = 0;
    unsigned char *xb = slurp(argv[2], &n_in), *tb = slurp(argv[3], &n_out);
    if (!xb || !tb || n_in != samples * inputs * sizeof(float) || n_out != samples * outputs * sizeof(float)) {
        fprintf(stderr, "the data files do not hold %zu samples\n", samples);
        return 1;
    }
    const float *x = (const float *)xb, *t = (const float *)tb;
    size_t minibatch = charon_ml_trainer_minibatch_size(trainer);
    long long epochs = charon_ml_trainer_epochs(trainer);

    int step = 0;
    if (!write_dump(trainer, step_path(argv[4], step))) return 1;
    step++;
    for (long long epoch = 0; epoch < epochs; epoch++) {
        for (size_t first = 0; first < samples; first += minibatch) {
            size_t count = samples - first < minibatch ? samples - first : minibatch;
            if (!charon_ml_trainer_step(trainer, x + first * inputs, t + first * outputs, count, error, sizeof error)) {
                fprintf(stderr, "step: %s\n", error);
                return 1;
            }
            if (!write_dump(trainer, step_path(argv[4], step))) return 1;
            step++;
        }
        if (!write_dump(trainer, step_path(argv[4], step))) return 1;
        step++;
    }
    snprintf(path, sizeof path, "%s/final.dump", argv[4]);
    if (!write_dump(trainer, path)) return 1;
    printf("steps %d epochs %lld minibatch %zu\n", step, epochs, minibatch);

    charon_ml_trainer_free(trainer);
    charon_ml_free(&document);
    free(xb);
    free(tb);
    free(bytes);
    return 0;
}
