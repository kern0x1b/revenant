#ifndef CHARON_ML_PROTO_H
#define CHARON_ML_PROTO_H

#include <stddef.h>
#include <stdint.h>

#include "CharonMLSchema.h"

typedef struct charon_ml_node charon_ml_node;

struct charon_ml_node {
    const charon_ml_message *message;
    const char *type;
    union {
        double number;
        int64_t integer;
        uint64_t unsigned_integer;
        struct {
            const char *bytes;
            size_t length;
        } text;
        struct {
            charon_ml_node *nodes;
            size_t count;
        } list;
    } value;
    const charon_ml_field *field;
};

typedef struct {
    const void *start;
    const void *end;
} charon_ml_reader;

int charon_ml_read(charon_ml_node *out, const void *bytes, size_t length, const char *type);

void charon_ml_free(charon_ml_node *node);

const charon_ml_node *charon_ml_at(const charon_ml_node *node, size_t index);
size_t charon_ml_count(const charon_ml_node *node);

size_t charon_ml_count_field(const charon_ml_node *node, const char *name);
const charon_ml_node *charon_ml_node_at_field(const charon_ml_node *node, const char *name, size_t index);

int charon_ml_int_at(const charon_ml_node *node, const char *name, size_t index, int fallback);
double charon_ml_double_at(const charon_ml_node *node, const char *name, size_t index, double fallback);

const charon_ml_node *charon_ml_get(const charon_ml_node *node, const char *name);

const charon_ml_node *charon_ml_oneof(const charon_ml_node *node, const char *name);

int charon_ml_int(const charon_ml_node *node, int64_t fallback);
double charon_ml_double(const charon_ml_node *node, double fallback);
const char *charon_ml_text(const charon_ml_node *node, char *out, size_t size);
const char *charon_ml_type(const charon_ml_node *node);

#endif
