#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "RevenantMLProto.h"

static unsigned char *slurp(const char *path, size_t *length)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    *length = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *bytes = malloc(*length);
    if (bytes && fread(bytes, 1, *length, f) != *length) { free(bytes); bytes = NULL; }
    fclose(f);
    return bytes;
}

static void print_tensor(const char *label, const revenant_ml_node *params)
{
    size_t count = params ? revenant_ml_count_field(params, "floatValue") : 0;
    printf("%s %zu", label, count);
    for (size_t i = 0; i < count; i++) printf(" %.9g", revenant_ml_double_at(params, "floatValue", i, 0));
    printf("\n");
}

int main(int argc, char **argv)
{
    if (argc != 2) { fprintf(stderr, "usage: dump MODEL.mlmodel\n"); return 2; }
    size_t length = 0;
    unsigned char *bytes = slurp(argv[1], &length);
    revenant_ml_node doc;
    if (!bytes || !revenant_ml_read(&doc, bytes, length, "CoreML.Specification.Model")) {
        printf("read failed\n");
        return 1;
    }
    const revenant_ml_node *network = revenant_ml_oneof(&doc, "neuralNetwork");
    if (!network) { printf("no neural network\n"); return 1; }
    size_t layers = revenant_ml_count_field(network, "layers");
    for (size_t i = 0; i < layers; i++) {
        const revenant_ml_node *layer = revenant_ml_node_at_field(network, "layers", i);
        char name[256];
        const revenant_ml_node *name_node = revenant_ml_get(layer, "name");
        revenant_ml_text(name_node, name, sizeof name);
        const char *kind = "other";
        const revenant_ml_node *conv = revenant_ml_oneof(layer, "convolution");
        const revenant_ml_node *ip = revenant_ml_oneof(layer, "innerProduct");
        const revenant_ml_node *flat = revenant_ml_oneof(layer, "flatten");
        if (conv) kind = "convolution";
        if (ip) kind = "innerProduct";
        if (flat) kind = "flatten";
        printf("layer %s %s\n", name, kind);
        if (conv) {
            print_tensor("weights", revenant_ml_get(conv, "weights"));
            print_tensor("bias", revenant_ml_get(conv, "bias"));
        }
        if (ip) {
            print_tensor("weights", revenant_ml_get(ip, "weights"));
            print_tensor("bias", revenant_ml_get(ip, "bias"));
        }
    }
    revenant_ml_free(&doc);
    free(bytes);
    return 0;
}
