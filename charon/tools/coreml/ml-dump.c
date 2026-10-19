#include "CharonMLProto.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_double(double value)
{
    char buffer[64];
    int precision;
    if (value != value) {
        fputs("nan", stdout);
        return;
    }
    if (value > 1.7976931348623157e308 || value < -1.7976931348623157e308) {
        fputs("inf", stdout);
        return;
    }
    for (precision = 1; precision <= 17; precision++) {
        snprintf(buffer, sizeof buffer, "%.*g", precision, value);
        if (strtod(buffer, NULL) == value) {
            break;
        }
    }
    fputs(buffer, stdout);
    if (strpbrk(buffer, ".eEnN") == NULL) {
        fputs(".0", stdout);
    }
}

static void print_string(const char *bytes, size_t length)
{
    size_t index;
    putchar('\'');
    for (index = 0; index < length; index++) {
        unsigned char byte = (unsigned char)bytes[index];
        if (byte == '\'' || byte == '\\') {
            printf("\\%c", byte);
        } else if (byte == '\n') {
            fputs("\\n", stdout);
        } else if (byte == '\r') {
            fputs("\\r", stdout);
        } else if (byte == '\t') {
            fputs("\\t", stdout);
        } else if (byte < 32 || byte >= 127) {
            printf("\\x%02x", byte);
        } else {
            putchar(byte);
        }
    }
    putchar('\'');
}

static int is_number(const charon_ml_node *node)
{
    return node->field != NULL && node->field->kind != CHARON_ML_KIND_STRING &&
           node->field->kind != CHARON_ML_KIND_BYTES && node->field->kind != CHARON_ML_KIND_MESSAGE;
}

static void print_value(const charon_ml_node *node)
{
    if (node->field->kind == CHARON_ML_KIND_STRING) {
        print_string(node->value.text.bytes, node->value.text.length);
    } else if (node->field->kind == CHARON_ML_KIND_BYTES) {
        printf("<%lu bytes>", (unsigned long)node->value.text.length);
    } else if (is_number(node)) {
        switch (node->field->kind) {
        case CHARON_ML_KIND_DOUBLE:
        case CHARON_ML_KIND_FLOAT:
            print_double(node->value.number);
            break;
        case CHARON_ML_KIND_BOOL:
            fputs(node->value.unsigned_integer ? "True" : "False", stdout);
            break;
        case CHARON_ML_KIND_UINT64:
        case CHARON_ML_KIND_FIXED64:
        case CHARON_ML_KIND_UINT32:
        case CHARON_ML_KIND_FIXED32:
            printf("%llu", (unsigned long long)node->value.unsigned_integer);
            break;
        default:
            printf("%lld", (long long)node->value.integer);
            break;
        }
    } else {
        print_double(0.0);
    }
}

static void print_repeated(const charon_ml_node *node, const char *name, size_t total, int indent)
{
    size_t index;
    printf("%*s%s = [", indent * 2, "", name);
    for (index = 0; index < total; index++) {
        if (index > 0) {
            fputs(", ", stdout);
        }
        print_value(charon_ml_node_at_field(node, name, index));
    }
    fputs("]\n", stdout);
}

static void walk(const charon_ml_node *node, int indent)
{
    size_t total = charon_ml_count(node), index = 0;
    while (index < total) {
        const charon_ml_node *entry = charon_ml_at(node, index);
        const charon_ml_field *field = entry->field;
        const char *name = field->name;
        int repeated = (field->flags & CHARON_ML_REPEATED) != 0;
        size_t members = 0, scan = index;

        while (scan < total && charon_ml_at(node, scan)->field == field) {
            members++;
            scan++;
        }
        if (field->kind == CHARON_ML_KIND_MESSAGE) {
            size_t seen;
            for (seen = 0; seen < members; seen++) {
                printf("%*s%s", indent * 2, "", name);
                if (repeated) {
                    printf("[%lu] {\n", (unsigned long)seen);
                } else {
                    printf(" {\n");
                }
                walk(charon_ml_at(node, index + seen), indent + 1);
                printf("%*s}\n", indent * 2, "");
            }
        } else if (repeated) {
            print_repeated(node, name, members, indent);
        } else {
            printf("%*s%s = ", indent * 2, "", name);
            print_value(entry);
            putchar('\n');
        }
        index += members;
    }
}

static const char *MODEL_KINDS[] = {
    "pipelineClassifier", "pipelineRegressor", "pipeline", "glmRegressor", "supportVectorRegressor",
    "treeEnsembleRegressor", "neuralNetworkRegressor", "bayesianProbitRegressor", "glmClassifier",
    "supportVectorClassifier", "treeEnsembleClassifier", "neuralNetworkClassifier",
    "kNearestNeighborsClassifier", "neuralNetwork", "itemSimilarityRecommender", "mlProgram",
    "customModel", "linkedModel", "classConfidenceThresholding", "oneHotEncoder", "imputer",
    "featureVectorizer", "dictVectorizer", "scaler", "categoricalMapping", "normalizer",
    "arrayFeatureExtractor", "nonMaximumSuppression", "identity", "textClassifier", "wordTagger",
    "visionFeaturePrint", "soundAnalysisPreprocessing", "gazetteer", "wordEmbedding",
    "audioFeaturePrint", "serializedModel", NULL};

static void print_model_kind(const charon_ml_node *model)
{
    int index;
    for (index = 0; MODEL_KINDS[index] != NULL; index++) {
        if (charon_ml_get(model, MODEL_KINDS[index]) != NULL) {
            puts(MODEL_KINDS[index]);
            return;
        }
    }
    puts("(none)");
}

static void print_feature(const charon_ml_node *model, const char *which, const char *wanted)
{
    const charon_ml_node *description = charon_ml_get(model, "description");
    const charon_ml_node *list;
    char text[512];
    size_t index, total;
    if (description == NULL) {
        printf("(no description)\n");
        return;
    }
    list = charon_ml_get(description, which);
    total = charon_ml_count(list);
    for (index = 0; index < total; index++) {
        const charon_ml_node *feature = charon_ml_node_at_field(description, which, index);
        const char *name = charon_ml_text(charon_ml_get(feature, "name"), text, sizeof text);
        if (name != NULL && strcmp(name, wanted) == 0) {
            char line[4096];
            size_t length = 0;
            const charon_ml_node *type = charon_ml_get(feature, "type");
            const charon_ml_node *array = charon_ml_get(type, "multiArrayType");
            if (array != NULL) {
                const charon_ml_node *shape = charon_ml_get(array, "shape");
                size_t at;
                length += (size_t)snprintf(line + length, sizeof line - length, "%s shape =", name);
                for (at = 0; at < charon_ml_count(shape); at++) {
                    length += (size_t)snprintf(line + length, sizeof line - length, "%s%d",
                                               at > 0 ? "," : "", charon_ml_int(charon_ml_at(shape, at), 0));
                }
                length += (size_t)snprintf(line + length, sizeof line - length, " dataType = %d",
                                           charon_ml_int(charon_ml_get(array, "dataType"), 0));
            } else {
                const charon_ml_node *oneof = NULL;
                size_t at;
                for (at = 0; at < charon_ml_count(type); at++) {
                    oneof = charon_ml_at(type, at);
                    break;
                }
                length += (size_t)snprintf(line + length, sizeof line - length, "%s type = %s", name,
                                           oneof != NULL ? oneof->field->name : "none");
            }
            printf("%s\n", line);
            return;
        }
    }
    printf("(no feature named %s)\n", wanted);
}

static char *slurp(const char *path, size_t *length)
{
    FILE *file = fopen(path, "rb");
    char *bytes;
    long size;
    if (file == NULL) {
        fprintf(stderr, "ml-dump: cannot open %s\n", path);
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0 || (size = ftell(file)) < 0) {
        fclose(file);
        return NULL;
    }
    rewind(file);
    bytes = (char *)malloc((size_t)size + 1);
    if (bytes == NULL || fread(bytes, 1, (size_t)size, file) != (size_t)size) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    bytes[size] = 0;
    *length = (size_t)size;
    return bytes;
}

int main(int argc, char **argv)
{
    char *bytes;
    size_t length = 0;
    charon_ml_node model;
    const char *path = NULL;
    const char *mode = "tree";
    const char *which = NULL;
    const char *wanted = NULL;
    int index;

    for (index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--model-kind") == 0) {
            mode = "kind";
        } else if (strcmp(argv[index], "--feature") == 0) {
            mode = "feature";
            if (index + 2 >= argc) {
                fprintf(stderr, "ml-dump: --feature takes which list and which name\n");
                return 2;
            }
            which = argv[++index];
            wanted = argv[++index];
        } else {
            path = argv[index];
        }
    }
    if (path == NULL) {
        fprintf(stderr, "usage: ml-dump [--model-kind | --feature <list> <name>] <model.mlmodel>\n");
        return 2;
    }
    bytes = slurp(path, &length);
    if (bytes == NULL) {
        return 1;
    }
    if (!charon_ml_read(&model, bytes, length, "CoreML.Specification.Model")) {
        fprintf(stderr, "ml-dump: %s is not a Core ML model this specification describes\n", path);
        free(bytes);
        return 1;
    }
    if (strcmp(mode, "kind") == 0) {
        print_model_kind(&model);
    } else if (strcmp(mode, "feature") == 0) {
        print_feature(&model, which, wanted);
    } else {
        walk(&model, 0);
    }
    charon_ml_free(&model);
    free(bytes);
    return 0;
}
