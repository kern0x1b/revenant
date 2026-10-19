/* Run a model over a flat list of inputs and print its outputs. This is the harness the
 * interpreter is measured with: the numbers it prints are compared with what coremltools' own
 * runtime prints for the same model and the same input.
 *
 *   ml-predict --kind <model>
 *   ml-predict <model> --set <name> <count> <value> ...
 */
#include "CharonMLModel.h"
#include "CharonMLPredict.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    charon_ml_model model;
    charon_ml_features inputs, outputs;
    char error[512];
    const char *path = NULL;
    int index, want_kind = 0;

    error[0] = 0;
    charon_ml_features_init(&inputs);
    charon_ml_features_init(&outputs);
    for (index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--kind") == 0) {
            want_kind = 1;
        } else if (strcmp(argv[index], "--set") == 0 || strcmp(argv[index], "--setr") == 0) {
            /* --set gives a flat vector of n values; --setr gives a shape followed by the count
             * and the values, for the model whose input is a channels-first array. */
            int ranked = strcmp(argv[index], "--setr") == 0;
            const char *name;
            long count, at;
            float *data;
            int64_t shape[8];
            int rank = 0, dimension = 0;
            charon_ml_array array;
            if (index + 2 >= argc) {
                fprintf(stderr, "%s takes a name and a count\n", argv[index]);
                return 2;
            }
            name = argv[++index];
            if (ranked) {
                char *spec = argv[++index];
                char *part = strtok(spec, "x");
                while (part != NULL && dimension < 8) {
                    shape[dimension++] = (int64_t)strtoll(part, NULL, 10);
                    part = strtok(NULL, "x");
                }
                rank = dimension;
                if (rank < 1) {
                    fprintf(stderr, "--setr %s has no shape\n", name);
                    return 2;
                }
            } else {
                shape[0] = 0;
                rank = 1;
            }
            count = strtol(argv[++index], NULL, 10);
            if (count < 1 || index + count >= argc) {
                fprintf(stderr, "%s %s wants %ld values\n", argv[index - 1], name, count);
                return 2;
            }
            if (!ranked) {
                shape[0] = count;
            }
            data = (float *)malloc((size_t)count * sizeof *data);
            for (at = 0; at < count; at++) {
                data[at] = (float)strtod(argv[++index], NULL);
            }
            array = charon_ml_array_alloc(CHARON_ML_ARRAY_FLOAT32, shape, rank);
            for (at = 0; at < count; at++) {
                charon_ml_array_set(&array, at, data[at]);
            }
            if (!charon_ml_features_put(&inputs, name, charon_ml_value_array(array))) {
                fprintf(stderr, "no room for %s\n", name);
                return 1;
            }
            free(data);
        } else {
            path = argv[index];
        }
    }
    if (path == NULL) {
            fprintf(stderr,
                "usage: ml-predict [--kind] <model> [--set <name> <count> <value> ...]\n"
                "                  [--setr <name> <dxd..> <count> <value> ...]\n");
        return 2;
    }
    if (!charon_ml_model_read(&model, path, error, sizeof error)) {
        fprintf(stderr, "ml-predict: %s\n", error);
        return 1;
    }
    if (want_kind) {
        printf("%s\n", charon_ml_kind_name(model.kind));
        charon_ml_model_release(&model);
        return 0;
    }
    if (!charon_ml_predict(&model, &inputs, &outputs, error, sizeof error)) {
        fprintf(stderr, "ml-predict: %s\n", error);
        charon_ml_model_release(&model);
        return 1;
    }
    for (index = 0; index < (int)outputs.count; index++) {
        const charon_ml_value *value = &outputs.entries[index].value;
        size_t at;
        if (value->kind == CHARON_ML_VALUE_STRING) {
            printf("%s = '%.*s'\n", outputs.entries[index].name, (int)value->string.length,
                   value->string.bytes);
        } else if (value->kind == CHARON_ML_VALUE_ARRAY) {
            printf("%s = [", outputs.entries[index].name);
            for (at = 0; at < value->array.count; at++) {
                printf("%s%.9g", at ? ", " : "", charon_ml_array_get(&value->array, (int64_t)at));
            }
            printf("]\n");
        } else if (value->kind == CHARON_ML_VALUE_DICTIONARY) {
            printf("%s = {", outputs.entries[index].name);
            for (at = 0; at < value->dictionary.count; at++) {
                printf("%s'%s': %.9g", at ? ", " : "", value->dictionary.keys[at],
                       value->dictionary.values[at]);
            }
            printf("}\n");
        } else if (value->kind == CHARON_ML_VALUE_NUMBER) {
            printf("%s = %.9g\n", outputs.entries[index].name, value->number);
        } else {
            printf("%s = (%s)\n", outputs.entries[index].name, charon_ml_value_name(value->kind));
        }
    }
    charon_ml_features_release(&outputs);
    charon_ml_features_release(&inputs);
    charon_ml_model_release(&model);
    return 0;
}
