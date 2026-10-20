#ifndef REVENANT_ML_PROTO_H
#define REVENANT_ML_PROTO_H

#include <stddef.h>
#include <stdint.h>

#include "RevenantMLSchema.h"

typedef struct revenant_ml_node revenant_ml_node;

struct revenant_ml_node {
    const revenant_ml_message *message;
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
            revenant_ml_node *nodes;
            size_t count;
        } list;
    } value;
    const revenant_ml_field *field;
};

typedef struct {
    const void *start;
    const void *end;
} revenant_ml_reader;

int revenant_ml_read(revenant_ml_node *out, const void *bytes, size_t length, const char *type);

void revenant_ml_free(revenant_ml_node *node);

const revenant_ml_node *revenant_ml_at(const revenant_ml_node *node, size_t index);
size_t revenant_ml_count(const revenant_ml_node *node);

size_t revenant_ml_count_field(const revenant_ml_node *node, const char *name);
const revenant_ml_node *revenant_ml_node_at_field(const revenant_ml_node *node, const char *name, size_t index);

int revenant_ml_int_at(const revenant_ml_node *node, const char *name, size_t index, int fallback);
double revenant_ml_double_at(const revenant_ml_node *node, const char *name, size_t index, double fallback);

const revenant_ml_node *revenant_ml_get(const revenant_ml_node *node, const char *name);

const revenant_ml_node *revenant_ml_oneof(const revenant_ml_node *node, const char *name);

int revenant_ml_int(const revenant_ml_node *node, int64_t fallback);
double revenant_ml_double(const revenant_ml_node *node, double fallback);
const char *revenant_ml_text(const revenant_ml_node *node, char *out, size_t size);
const char *revenant_ml_type(const revenant_ml_node *node);

#endif
