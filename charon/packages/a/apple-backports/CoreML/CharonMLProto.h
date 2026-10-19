/* A reader for the protobuf wire format, and the document it builds for a CoreML container.
 *
 * A .mlmodel file is one length-delimited protocol buffer message of type
 * CoreML.Specification.Model; a .mlmodelc bundle holds the same model in model.mil, a weight
 * blob beside it, and metadata in JSON. Both are read here against the specification
 * (CharonMLSchema.h), so what the port runs is the model the file describes rather than a
 * guess at its shape.
 */
#ifndef CHARON_ML_PROTO_H
#define CHARON_ML_PROTO_H

#include <stddef.h>
#include <stdint.h>

#include "CharonMLSchema.h"

/* One value read out of a message. A submessage keeps its own node, so a value is never copied
 * out of the buffer the model was read into: the whole document is one allocation and a node
 * is a window into it. */
typedef struct charon_ml_node charon_ml_node;

struct charon_ml_node {
    const charon_ml_message *message; /* the message of the specification this node holds */
    const char *type;                 /* its own name in the specification */
    union {
        double number;
        int64_t integer;
        uint64_t unsigned_integer;
        struct {
            const char *bytes;
            size_t length;
        } text; /* a string, and bytes alike: neither is NUL terminated in the wire */
        struct {
            charon_ml_node *nodes;
            size_t count;
        } list; /* a repeated field, or a submessage's fields */
    } value;
    const charon_ml_field *field; /* the field of the parent this value was read for, or NULL */
};

typedef struct {
    const void *start;
    const void *end;
} charon_ml_reader;

/* Reads a message of the given specification type out of a buffer, into a node the caller owns
 * (it is one struct, the list it points at is malloc'd). Returns 0 and leaves *out untouched
 * when the buffer does not hold a message of that type: a container that names a message the
 * specification does not have, a truncated varint, a length that runs past the end. */
int charon_ml_read(charon_ml_node *out, const void *bytes, size_t length, const char *type);

void charon_ml_free(charon_ml_node *node);

/* The children of a message, and a submessage reached by one of its fields.
 *
 * These two are for messages only. A repeated field of a message is not a message and has no
 * children: its entries are siblings in the parent's list, which is what count_field and
 * at_field below reach. Reading a repeated field as though it were a message counts the whole
 * parent, and the mistake is silent, so the two are kept apart on purpose. */
const charon_ml_node *charon_ml_at(const charon_ml_node *node, size_t index);
size_t charon_ml_count(const charon_ml_node *node);

/* The values of a repeated field by name: how many there are, and the `index`th of them. A
 * packed run and a repeated field written one entry at a time are the same shape here, because
 * the reader flattens the run as it reads it. */
size_t charon_ml_count_field(const charon_ml_node *node, const char *name);
const charon_ml_node *charon_ml_node_at_field(const charon_ml_node *node, const char *name, size_t index);

/* The `index`th value of a repeated field as a number, which is what a shape, a stride, a
 * threshold or a weight vector is read through. `fallback` is what an absent field gives. */
int charon_ml_int_at(const charon_ml_node *node, const char *name, size_t index, int fallback);
double charon_ml_double_at(const charon_ml_node *node, const char *name, size_t index, double fallback);

/* The one value of a singular field of `name` in `node`, or NULL when it is not there. A
 * singular field that appears more than once in the wire takes the last one, which is what
 * protobuf's own parser does. */
const charon_ml_node *charon_ml_get(const charon_ml_node *node, const char *name);

/* A field of a oneof, by the name the specification gives it; NULL when the oneof holds another
 * field, which is what makes a oneof readable without walking all of its cases. */
const charon_ml_node *charon_ml_oneof(const charon_ml_node *node, const char *name);

int charon_ml_int(const charon_ml_node *node, int64_t fallback);
double charon_ml_double(const charon_ml_node *node, double fallback);
/* The bytes of a string or bytes field, NUL terminated in `out` of `size`, or NULL when the
 * field is not there or is longer than `size` (a truncation would read as a value). */
const char *charon_ml_text(const charon_ml_node *node, char *out, size_t size);
/* The specification name of `node`, e.g. "CoreML.Specification.WeightParams" for a weight's
 * alpha, so a caller can tell which case of a oneof it holds. */
const char *charon_ml_type(const charon_ml_node *node);

#endif /* CHARON_ML_PROTO_H */
