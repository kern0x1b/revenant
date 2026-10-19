/* dump.c - prints the updatable weights of a model file, read with the port's own reader.
 *
 * usage: dump MODEL.mlmodel
 *
 * For each layer of the network, in order: "layer NAME KIND", then one "weights" and one "bias" line when the
 * layer has them, each as its count followed by the values at %.9g. The reader is the port's (CharonMLProto.c),
 * so the dump is the port's reading of the file, which the host's own reading is compared with elsewhere. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "CharonMLProto.h"

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

/* A weight tensor's values, or "0" for a layer that has none (a missing bias). */
static void print_tensor(const char *label, const charon_ml_node *params)
{
    size_t count = params ? charon_ml_count_field(params, "floatValue") : 0;
    printf("%s %zu", label, count);
    for (size_t i = 0; i < count; i++) printf(" %.9g", charon_ml_double_at(params, "floatValue", i, 0));
    printf("\n");
}

int main(int argc, char **argv)
{
    if (argc != 2) { fprintf(stderr, "usage: dump MODEL.mlmodel\n"); return 2; }
    size_t length = 0;
    unsigned char *bytes = slurp(argv[1], &length);
    charon_ml_node doc;
    if (!bytes || !charon_ml_read(&doc, bytes, length, "CoreML.Specification.Model")) {
        printf("read failed\n");
        return 1;
    }
    const charon_ml_node *network = charon_ml_oneof(&doc, "neuralNetwork");
    if (!network) { printf("no neural network\n"); return 1; }
    size_t layers = charon_ml_count_field(network, "layers");
    for (size_t i = 0; i < layers; i++) {
        const charon_ml_node *layer = charon_ml_node_at_field(network, "layers", i);
        char name[256];
        const charon_ml_node *name_node = charon_ml_get(layer, "name");
        charon_ml_text(name_node, name, sizeof name);
        const char *kind = "other";
        const charon_ml_node *conv = charon_ml_oneof(layer, "convolution");
        const charon_ml_node *ip = charon_ml_oneof(layer, "innerProduct");
        const charon_ml_node *flat = charon_ml_oneof(layer, "flatten");
        if (conv) kind = "convolution";
        if (ip) kind = "innerProduct";
        if (flat) kind = "flatten";
        printf("layer %s %s\n", name, kind);
        if (conv) {
            print_tensor("weights", charon_ml_get(conv, "weights"));
            print_tensor("bias", charon_ml_get(conv, "bias"));
        }
        if (ip) {
            print_tensor("weights", charon_ml_get(ip, "weights"));
            print_tensor("bias", charon_ml_get(ip, "bias"));
        }
    }
    charon_ml_free(&doc);
    free(bytes);
    return 0;
}
