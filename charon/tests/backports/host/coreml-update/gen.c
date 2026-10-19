#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    unsigned char *p;
    size_t n, cap;
} buf;

static void b_put(buf *b, const void *data, size_t len)
{
    if (b->n + len > b->cap) {
        b->cap = (b->n + len) * 2 + 64;
        b->p = realloc(b->p, b->cap);
        if (!b->p) { perror("realloc"); exit(1); }
    }
    memcpy(b->p + b->n, data, len);
    b->n += len;
}

static void b_varint(buf *b, uint64_t v)
{
    do {
        unsigned char g = v & 0x7f;
        v >>= 7;
        if (v) g |= 0x80;
        b_put(b, &g, 1);
    } while (v);
}

static void b_tag(buf *b, int field, int wire) { b_varint(b, ((uint64_t)field << 3) | (uint64_t)wire); }

static void f_varint(buf *b, int field, uint64_t v) { b_tag(b, field, 0); b_varint(b, v); }

static void f_bytes(buf *b, int field, const buf *msg)
{
    b_tag(b, field, 2);
    b_varint(b, msg->n);
    b_put(b, msg->p, msg->n);
}

static void f_string(buf *b, int field, const char *s)
{
    b_tag(b, field, 2);
    b_varint(b, strlen(s));
    b_put(b, s, strlen(s));
}

static void f_double(buf *b, int field, double v)
{
    uint64_t bits;
    memcpy(&bits, &v, 8);
    b_tag(b, field, 1);
    for (int i = 0; i < 8; i++) {
        unsigned char c = (unsigned char)(bits >> (8 * i));
        b_put(b, &c, 1);
    }
}

static void f_floats_packed(buf *b, int field, const float *v, size_t count)
{
    buf inner = {0, 0, 0};
    for (size_t i = 0; i < count; i++) {
        uint32_t bits;
        memcpy(&bits, &v[i], 4);
        for (int k = 0; k < 4; k++) {
            unsigned char c = (unsigned char)(bits >> (8 * k));
            b_put(&inner, &c, 1);
        }
    }
    f_bytes(b, field, &inner);
    free(inner.p);
}

static void f_varints_packed(buf *b, int field, const uint64_t *v, size_t count)
{
    buf inner = {0, 0, 0};
    for (size_t i = 0; i < count; i++) b_varint(&inner, v[i]);
    f_bytes(b, field, &inner);
    free(inner.p);
}

static void double_parameter(buf *out, int field, double v)
{
    buf p = {0, 0, 0};
    f_double(&p, 1, v);
    f_bytes(out, field, &p);
    free(p.p);
}

static void int_parameter(buf *out, int field, uint64_t v)
{
    buf p = {0, 0, 0};
    f_varint(&p, 1, v);
    f_bytes(out, field, &p);
    free(p.p);
}

static void weights(buf *out, int field, const float *v, size_t count)
{
    buf w = {0, 0, 0};
    f_floats_packed(&w, 1, v, count);
    f_varint(&w, 50, 1);
    f_bytes(out, field, &w);
    free(w.p);
}

static void feature(buf *out, int field, const char *name, const uint64_t *shape, size_t rank)
{
    buf array = {0, 0, 0}, type = {0, 0, 0}, feat = {0, 0, 0};
    f_varints_packed(&array, 1, shape, rank);
    f_varint(&array, 2, 65568);
    f_bytes(&type, 5, &array);
    f_string(&feat, 1, name);
    f_bytes(&feat, 3, &type);
    f_bytes(out, field, &feat);
    free(array.p);
    free(type.p);
    free(feat.p);
}

static uint64_t rng_state;

static float next_unit(void)
{
    rng_state = rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    uint32_t top = (uint32_t)(rng_state >> 40);
    return (float)top / 16777216.0f - 0.5f;
}

static void write_file(const char *path, const void *data, size_t len)
{
    FILE *f = fopen(path, "wb");
    if (!f || fwrite(data, 1, len, f) != len) { perror(path); exit(1); }
    fclose(f);
}

int main(int argc, char **argv)
{
    if (argc != 11 && argc != 12) {
        fprintf(stderr, "usage: gen OUTDIR sgd|adam LEARNING_RATE MOMENTUM_OR_BETA1 BETA2 EPS MINIBATCH EPOCHS SAMPLES SEED [CONV_OUTPUT_CHANNELS]\n");
        return 2;
    }
    uint64_t conv_out = argc == 12 ? (uint64_t)atoll(argv[11]) : 2;
    const char *outdir = argv[1];
    int adam = strcmp(argv[2], "adam") == 0;
    double learning_rate = atof(argv[3]);
    double momentum_or_beta1 = atof(argv[4]);
    double beta2 = atof(argv[5]);
    double eps = atof(argv[6]);
    uint64_t minibatch = (uint64_t)atoll(argv[7]);
    uint64_t epochs = (uint64_t)atoll(argv[8]);
    size_t samples = (size_t)atoll(argv[9]);
    rng_state = (uint64_t)atoll(argv[10]) * 2654435761ULL + 1;

    float conv_w[2 * 1 * 3 * 3], conv_b[2], ip_w[3 * 32], ip_b[3];
    for (size_t i = 0; i < sizeof conv_w / sizeof conv_w[0]; i++) conv_w[i] = 0.5f * next_unit();
    for (size_t i = 0; i < 2; i++) conv_b[i] = 0.2f * next_unit();
    for (size_t i = 0; i < sizeof ip_w / sizeof ip_w[0]; i++) ip_w[i] = 0.4f * next_unit();
    for (size_t i = 0; i < 3; i++) ip_b[i] = 0.2f * next_unit();

    buf conv = {0, 0, 0};
    f_varint(&conv, 1, conv_out);
    f_varint(&conv, 2, 1);
    { uint64_t k[2] = {3, 3}; f_varints_packed(&conv, 20, k, 2); }
    { uint64_t s[2] = {1, 1}; f_varints_packed(&conv, 30, s, 2); }
    { uint64_t d[2] = {1, 1}; f_varints_packed(&conv, 40, d, 2); }
    { buf valid = {0, 0, 0}; f_bytes(&conv, 50, &valid); free(valid.p); }
    f_varint(&conv, 70, 1);
    weights(&conv, 90, conv_w, sizeof conv_w / sizeof conv_w[0]);
    weights(&conv, 91, conv_b, 2);
    buf layer_conv = {0, 0, 0};
    f_string(&layer_conv, 1, "conv");
    f_string(&layer_conv, 2, "x");
    f_string(&layer_conv, 3, "c");
    f_varint(&layer_conv, 10, 1);
    f_bytes(&layer_conv, 100, &conv);

    buf flat = {0, 0, 0};
    f_varint(&flat, 1, 0);
    buf layer_flat = {0, 0, 0};
    f_string(&layer_flat, 1, "flat");
    f_string(&layer_flat, 2, "c");
    f_string(&layer_flat, 3, "f");
    f_bytes(&layer_flat, 301, &flat);

    buf ip = {0, 0, 0};
    f_varint(&ip, 1, 32);
    f_varint(&ip, 2, 3);
    f_varint(&ip, 10, 1);
    weights(&ip, 20, ip_w, sizeof ip_w / sizeof ip_w[0]);
    weights(&ip, 21, ip_b, 3);
    buf layer_ip = {0, 0, 0};
    f_string(&layer_ip, 1, "ip");
    f_string(&layer_ip, 2, "f");
    f_string(&layer_ip, 3, "y");
    f_varint(&layer_ip, 10, 1);
    f_bytes(&layer_ip, 140, &ip);

    buf mse = {0, 0, 0};
    f_string(&mse, 1, "y");
    f_string(&mse, 2, "t");
    buf loss = {0, 0, 0};
    f_string(&loss, 1, "mse");
    f_bytes(&loss, 11, &mse);

    buf optimiser = {0, 0, 0};
    buf opt = {0, 0, 0};
    double_parameter(&opt, 1, learning_rate);
    int_parameter(&opt, 2, minibatch);
    if (adam) {
        double_parameter(&opt, 3, momentum_or_beta1);
        double_parameter(&opt, 4, beta2);
        double_parameter(&opt, 5, eps);
        f_bytes(&optimiser, 11, &opt);
    } else {
        double_parameter(&opt, 3, momentum_or_beta1);
        f_bytes(&optimiser, 10, &opt);
    }
    free(opt.p);

    buf update = {0, 0, 0};
    f_bytes(&update, 1, &loss);
    f_bytes(&update, 2, &optimiser);
    int_parameter(&update, 3, epochs);
    { buf shuffle = {0, 0, 0}; f_varint(&shuffle, 1, 0); f_bytes(&update, 10, &shuffle); free(shuffle.p); }
    int_parameter(&update, 20, 7);

    buf network = {0, 0, 0};
    f_bytes(&network, 1, &layer_conv);
    f_bytes(&network, 1, &layer_flat);
    f_bytes(&network, 1, &layer_ip);
    f_bytes(&network, 10, &update);

    uint64_t in_shape[3] = {1, 6, 6}, out_shape[1] = {3};
    buf description = {0, 0, 0};
    feature(&description, 1, "x", in_shape, 3);
    feature(&description, 10, "y", out_shape, 1);
    feature(&description, 50, "x", in_shape, 3);
    feature(&description, 50, "t", out_shape, 1);

    buf model = {0, 0, 0};
    f_varint(&model, 1, 4);
    f_bytes(&model, 2, &description);
    f_varint(&model, 10, 1);
    f_bytes(&model, 500, &network);

    char path[4096];
    snprintf(path, sizeof path, "%s/model.mlmodel", outdir);
    write_file(path, model.p, model.n);

    float *input = malloc(samples * 36 * sizeof(float));
    float *target = malloc(samples * 3 * sizeof(float));
    for (size_t i = 0; i < samples * 36; i++) input[i] = next_unit();
    for (size_t i = 0; i < samples * 3; i++) target[i] = 0.5f * next_unit();
    snprintf(path, sizeof path, "%s/input.f32", outdir);
    write_file(path, input, samples * 36 * sizeof(float));
    snprintf(path, sizeof path, "%s/target.f32", outdir);
    write_file(path, target, samples * 3 * sizeof(float));
    free(input);
    free(target);
    free(model.p);
    free(description.p);
    free(network.p);
    free(update.p);
    free(optimiser.p);
    free(loss.p);
    free(mse.p);
    free(layer_conv.p);
    free(conv.p);
    free(layer_flat.p);
    free(flat.p);
    free(layer_ip.p);
    free(ip.p);
    return 0;
}
