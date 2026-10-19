/* A reader for the protobuf wire format, and the document it builds for a CoreML container.
 * CharonMLProto.h says what it is for; this is the reading of it.
 *
 * Nothing here trusts the container: a length that runs past the end of the buffer, a varint
 * of more than ten bytes, a nested message naming a type the specification does not hold, and
 * a field written with a wire type the specification does not give it are all refused, because
 * a malformed model has to fail the load with a message an application can read and not be run.
 */
#include "CharonMLProto.h"

#include <stdlib.h>
#include <string.h>

/* Ten bytes is the most a 64-bit varint can be: nine groups of seven bits and a last of one. */
#define MAX_VARINT_BYTES 10

typedef struct {
    const char *at;
    const char *end;
    int failed;
} wire;

static int take(wire *w, size_t count, const char **out)
{
    if (w->failed || (size_t)(w->end - w->at) < count) {
        w->failed = 1;
        return 0;
    }
    *out = w->at;
    w->at += count;
    return 1;
}

static int varint(wire *w, uint64_t *out)
{
    uint64_t value = 0;
    int shift = 0, index;
    for (index = 0; index < MAX_VARINT_BYTES; index++) {
        const char *at;
        unsigned char byte;
        if (!take(w, 1, &at)) {
            return 0;
        }
        byte = (unsigned char)*at;
        if (shift < 64) {
            value |= (uint64_t)(byte & 0x7f) << shift;
        }
        shift += 7;
        if ((byte & 0x80) == 0) {
            *out = value;
            return 1;
        }
    }
    w->failed = 1;
    return 0;
}

static uint64_t zigzag(uint64_t value)
{
    return (value >> 1) ^ (uint64_t)(-(int64_t)(value & 1));
}

static uint32_t low32(uint64_t value) { return (uint32_t)(value & 0xffffffffu); }

static double bits_to_double(uint64_t bits)
{
    double value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

static float bits_to_float(uint32_t bits)
{
    float value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

/* The oneof a field belongs to, or 0 for a field of none. The field's flags carry it as
 * CHARON_ML_ONEOF(index), which is 0x2 * (index + 1), so the low bit is the repeated mark. */
static unsigned oneof_of(const charon_ml_field *field)
{
    return field == NULL ? 0 : (field->flags & ~CHARON_ML_REPEATED) >> 1;
}

/* One value of `field`, already positioned at its bytes: a number, a string's bytes, a packed
 * run flattened into a list, or a submessage read against the type the specification names. */
static int read_value(wire *w, charon_ml_node *out, const charon_ml_field *field, const char *type)
{
    uint64_t bits = 0;
    const char *bytes;
    size_t length;

    out->message = NULL;

    if (field->wire == CHARON_ML_WIRE_VARINT) {
        if (!varint(w, &bits)) {
            return 0;
        }
        switch (field->kind) {
        case CHARON_ML_KIND_DOUBLE:
            out->value.number = bits_to_double(bits);
            break;
        case CHARON_ML_KIND_FLOAT:
            out->value.number = (double)bits_to_float(low32(bits));
            break;
        case CHARON_ML_KIND_UINT64:
        case CHARON_ML_KIND_FIXED64:
            out->value.unsigned_integer = bits;
            break;
        case CHARON_ML_KIND_BOOL:
            out->value.unsigned_integer = bits ? 1 : 0;
            break;
        case CHARON_ML_KIND_SINT32:
            out->value.integer = (int32_t)zigzag(low32(bits));
            break;
        case CHARON_ML_KIND_SINT64:
            out->value.integer = (int64_t)zigzag(bits);
            break;
        case CHARON_ML_KIND_UINT32:
        case CHARON_ML_KIND_FIXED32:
            out->value.unsigned_integer = low32(bits);
            break;
        case CHARON_ML_KIND_INT32:
        case CHARON_ML_KIND_SFIXED32:
        case CHARON_ML_KIND_ENUM:
            /* A 32-bit signed value is written as a varint of its two's complement bits, so
             * it is the low 32 that carry the sign; a 64-bit one is the whole varint. An enum
             * is a varint of its case's number, which is likewise 32 bits wide. */
            out->value.integer = (int32_t)low32(bits);
            break;
        case CHARON_ML_KIND_INT64:
        case CHARON_ML_KIND_SFIXED64:
        default:
            out->value.integer = (int64_t)bits;
            break;
        }
        return 1;
    }
    if (field->wire == CHARON_ML_WIRE_64 || field->wire == CHARON_ML_WIRE_32) {
        size_t width = field->wire == CHARON_ML_WIRE_64 ? 8 : 4;
        uint64_t raw;
        if (!take(w, width, &bytes)) {
            return 0;
        }
        memcpy(&raw, bytes, width);
        if (field->kind == CHARON_ML_KIND_DOUBLE) {
            out->value.number = bits_to_double(raw);
        } else if (field->kind == CHARON_ML_KIND_FLOAT) {
            out->value.number = (double)bits_to_float(low32(raw));
        } else if (width == 8) {
            out->value.integer = (int64_t)raw;
        } else {
            out->value.integer = (int32_t)low32(raw);
        }
        return 1;
    }
    /* The wire's only other shape is a length and then that many bytes. A packed repeated
     * field is one of those holding the element's own values back to back. */
    if (!varint(w, &bits) || !take(w, (size_t)bits, &bytes)) {
        return 0;
    }
    length = (size_t)bits;
    if (field->kind == CHARON_ML_KIND_STRING || field->kind == CHARON_ML_KIND_BYTES) {
        out->value.text.bytes = bytes;
        out->value.text.length = length;
        return 1;
    }
    if (field->element != CHARON_ML_FIELD_NONE) {
        charon_ml_field element = *field;
        wire run;
        charon_ml_node *nodes;
        size_t count = 0, capacity = 8, width;

        switch (field->element) {
        case CHARON_ML_KIND_DOUBLE:
        case CHARON_ML_KIND_FIXED64:
        case CHARON_ML_KIND_SFIXED64:
            width = 8;
            break;
        case CHARON_ML_KIND_FLOAT:
        case CHARON_ML_KIND_FIXED32:
        case CHARON_ML_KIND_SFIXED32:
            width = 4;
            break;
        default:
            width = 0;
            break;
        }
        /* The element of a run is read at its own width, which is not the run's: the run
         * arrives length-delimited and each element inside it is a bare value. */
        element.element = CHARON_ML_FIELD_NONE;
        element.flags &= ~(unsigned)CHARON_ML_REPEATED;
        element.wire = width == 0 ? CHARON_ML_WIRE_VARINT
                                  : (width == 8 ? CHARON_ML_WIRE_64 : CHARON_ML_WIRE_32);
        run.at = bytes;
        run.end = bytes + length;
        run.failed = 0;
        nodes = (charon_ml_node *)calloc(capacity, sizeof *nodes);
        if (nodes == NULL) {
            return 0;
        }
        /* The run is read whole before it is kept, so a truncated one is refused rather than
         * half-read: a model whose weights are short is a model that must not run. */
        while (run.at < run.end) {
            if (count == capacity) {
                charon_ml_node *grown = (charon_ml_node *)realloc(nodes, capacity * 2 * sizeof *nodes);
                if (grown == NULL) {
                    free(nodes);
                    return 0;
                }
                memset(grown + capacity, 0, capacity * sizeof *grown);
                nodes = grown;
                capacity *= 2;
            }
            /* Every element names the field of the run itself, which is a static descriptor
             * that outlives this call: the local copy above differs from it only in the width
             * each element is read at, which is what this loop is for and not what a caller
             * asking about the value wants to see. */
            nodes[count].type = type;
            nodes[count].field = field;
            if (!read_value(&run, &nodes[count], &element, type) || run.failed) {
                free(nodes);
                w->failed = 1;
                return 0;
            }
            count++;
        }
        out->value.list.nodes = nodes;
        out->value.list.count = count;
        return 1;
    }
    {
        charon_ml_node sub;
        if (charon_ml_read(&sub, bytes, length, type) == 0) {
            w->failed = 1;
            return 0;
        }
        out->message = sub.message;
        out->value = sub.value;
    }
    return 1;
}

/* Reads one message of `message`, growing `entries` for its fields. Every field the
 * specification declares is read; a field it does not is stepped over, so a container written
 * by a later version still reads, and what that version adds is simply not there to read. */
static int read_message(wire *w, charon_ml_node *out, const charon_ml_message *message, const char *type)
{
    charon_ml_node *entries = (charon_ml_node *)calloc(8, sizeof *entries);
    size_t capacity = 8, count = 0;

    out->message = message;
    out->type = type;
    if (entries == NULL) {
        out->value.list.nodes = NULL;
        out->value.list.count = 0;
        return 0;
    }
    while (w->at < w->end) {
        uint64_t key = 0;
        int number, wire_type;
        const charon_ml_field *field;
        charon_ml_node *entry;

        if (!varint(w, &key)) {
            break;
        }
        number = (int)(key >> 3);
        wire_type = (int)(key & 7);
        field = charon_ml_field_named(message, number);
        if (field == NULL || field->wire != wire_type) {
            /* A field this specification does not name, or one whose bytes are written with
             * another wire type than its own: it cannot be read as what it claims, and the
             * wire type the bytes really have is what decides how to step over them. */
            wire step = {w->at, w->end, 0};
            uint64_t skip = 0;
            const char *at;
            switch (wire_type) {
            case CHARON_ML_WIRE_VARINT:
                varint(&step, &skip);
                break;
            case CHARON_ML_WIRE_64:
                take(&step, 8, &at);
                break;
            case CHARON_ML_WIRE_32:
                take(&step, 4, &at);
                break;
            case CHARON_ML_WIRE_STRING:
                if (varint(&step, &skip)) {
                    take(&step, (size_t)skip, &at);
                }
                break;
            default:
                step.failed = 1;
                break;
            }
            if (step.failed) {
                w->failed = 1;
                break;
            }
            w->at = step.at;
            continue;
        }
        if (count == capacity) {
            charon_ml_node *grown = (charon_ml_node *)realloc(entries, capacity * 2 * sizeof *entries);
            if (grown == NULL) {
                w->failed = 1;
                break;
            }
            memset(grown + capacity, 0, capacity * sizeof *grown);
            entries = grown;
            capacity *= 2;
        }
        entry = &entries[count];
        entry->type = type;
        entry->field = field;
        if (!read_value(w, entry, field, field->type)) {
            w->failed = 1;
            break;
        }
        if ((field->flags & CHARON_ML_REPEATED) == 0 || field->element == CHARON_ML_FIELD_NONE) {
            count++;
            continue;
        }
        {
            /* A packed run arrived as one node holding a list, and its elements become entries
             * of this message: a caller then walks one shape for every repeated field, packed
             * or not. A weight matrix of a few thousand elements is a single run, so the room
             * for all of them is made at once rather than one doubling at a time. */
            charon_ml_node *run = entry->value.list.nodes;
            size_t elements = entry->value.list.count, inner;
            while (count + elements > capacity) {
                charon_ml_node *grown = (charon_ml_node *)realloc(entries, capacity * 2 * sizeof *entries);
                if (grown == NULL) {
                    for (inner = 0; inner < elements; inner++) {
                        charon_ml_free(&run[inner]);
                    }
                    free(run);
                    w->failed = 1;
                    break;
                }
                memset(grown + capacity, 0, capacity * sizeof *grown);
                entries = grown;
                capacity *= 2;
            }
            if (w->failed) {
                break;
            }
            for (inner = 0; inner < elements; inner++) {
                entries[count++] = run[inner];
            }
            free(run);
        }
    }
    if (w->failed) {
        size_t index;
        for (index = 0; index < count; index++) {
            charon_ml_free(&entries[index]);
        }
        free(entries);
        return 0;
    }
    out->value.list.nodes = entries;
    out->value.list.count = count;
    return 1;
}

/* Whether a node's value is a list of others, which is what decides both how many fields a
 * message has and what there is to free. A node read as a field of a message holds a list
 * only when it is a submessage; a number, a string and a packed run all hold their value in
 * the union, and reading the union as a pointer would be reading a number as an address. */
static int holds_list(const charon_ml_node *node)
{
    return node != NULL && (node->field == NULL || node->field->kind == CHARON_ML_KIND_MESSAGE);
}

int charon_ml_read(charon_ml_node *out, const void *bytes, size_t length, const char *type)
{
    static const char package[] = "CoreML.Specification.";
    const charon_ml_message *message = charon_ml_message_named(type);
    wire w;

    memset(out, 0, sizeof *out);
    if (message == NULL && strncmp(type, package, sizeof package - 1) == 0) {
        message = charon_ml_message_named(type + sizeof package - 1);
    }
    if (message == NULL) {
        return 0;
    }
    w.at = (const char *)bytes;
    w.end = w.at + length;
    w.failed = 0;
    if (read_message(&w, out, message, type) == 0) {
        memset(out, 0, sizeof *out);
        return 0;
    }
    return 1;
}

void charon_ml_free(charon_ml_node *node)
{
    size_t index;
    if (!holds_list(node) || node->value.list.nodes == NULL) {
        return;
    }
    for (index = 0; index < node->value.list.count; index++) {
        charon_ml_free(&node->value.list.nodes[index]);
    }
    free(node->value.list.nodes);
    node->value.list.nodes = NULL;
    node->value.list.count = 0;
}

size_t charon_ml_count(const charon_ml_node *node)
{
    return holds_list(node) ? node->value.list.count : 0;
}

const charon_ml_node *charon_ml_at(const charon_ml_node *node, size_t index)
{
    if (index >= charon_ml_count(node)) {
        return NULL;
    }
    return &node->value.list.nodes[index];
}

int charon_ml_int_at(const charon_ml_node *node, const char *name, size_t index, int fallback)
{
    return charon_ml_int(charon_ml_node_at_field(node, name, index), fallback);
}

double charon_ml_double_at(const charon_ml_node *node, const char *name, size_t index, double fallback)
{
    return charon_ml_double(charon_ml_node_at_field(node, name, index), fallback);
}

size_t charon_ml_count_field(const charon_ml_node *node, const char *name)
{
    size_t index, found = 0;
    for (index = 0; index < charon_ml_count(node); index++) {
        const charon_ml_node *entry = &node->value.list.nodes[index];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            found++;
        }
    }
    return found;
}

const charon_ml_node *charon_ml_node_at_field(const charon_ml_node *node, const char *name, size_t index)
{
    size_t at, found = 0;
    for (at = 0; at < charon_ml_count(node); at++) {
        const charon_ml_node *entry = &node->value.list.nodes[at];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            if (found == index) {
                return entry;
            }
            found++;
        }
    }
    return NULL;
}

const charon_ml_node *charon_ml_get(const charon_ml_node *node, const char *name)
{
    const charon_ml_node *found = NULL;
    size_t index;
    for (index = 0; index < charon_ml_count(node); index++) {
        const charon_ml_node *entry = &node->value.list.nodes[index];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            found = entry;
        }
    }
    /* A singular field written more than once takes the last, which is what protobuf's own
     * parser keeps and what a converter that emitted the field twice means. */
    return found;
}

const charon_ml_node *charon_ml_oneof(const charon_ml_node *node, const char *name)
{
    const charon_ml_node *want = charon_ml_get(node, name);
    unsigned oneof;
    size_t index;

    if (want == NULL) {
        return NULL;
    }
    oneof = oneof_of(want->field);
    if (oneof == 0) {
        return want; /* not of a oneof: the name alone decides */
    }
    for (index = 0; index < charon_ml_count(node); index++) {
        const charon_ml_node *entry = &node->value.list.nodes[index];
        if (oneof_of(entry->field) == oneof && entry != want) {
            /* Another case of the same oneof is in the document, so this one is not: a
             * oneof holds exactly one of its fields, and reading the others would read a
             * value the writer did not set. */
            return NULL;
        }
    }
    return want;
}

int charon_ml_int(const charon_ml_node *node, int64_t fallback)
{
    if (node == NULL) {
        return (int)fallback;
    }
    switch (node->field != NULL ? node->field->kind : CHARON_ML_FIELD_NONE) {
    case CHARON_ML_KIND_DOUBLE:
    case CHARON_ML_KIND_FLOAT:
        return (int)node->value.number;
    case CHARON_ML_KIND_UINT64:
    case CHARON_ML_KIND_FIXED64:
    case CHARON_ML_KIND_UINT32:
    case CHARON_ML_KIND_FIXED32:
    case CHARON_ML_KIND_BOOL:
        return (int)node->value.unsigned_integer;
    case CHARON_ML_FIELD_NONE:
        return (int)fallback; /* a submessage is not a number: the caller asked wrongly */
    default:
        return (int)node->value.integer;
    }
}

double charon_ml_double(const charon_ml_node *node, double fallback)
{
    if (node == NULL) {
        return fallback;
    }
    switch (node->field != NULL ? node->field->kind : CHARON_ML_FIELD_NONE) {
    case CHARON_ML_KIND_DOUBLE:
    case CHARON_ML_KIND_FLOAT:
        return node->value.number;
    case CHARON_ML_KIND_UINT64:
    case CHARON_ML_KIND_FIXED64:
    case CHARON_ML_KIND_UINT32:
    case CHARON_ML_KIND_FIXED32:
    case CHARON_ML_KIND_BOOL:
        return (double)node->value.unsigned_integer;
    case CHARON_ML_FIELD_NONE:
        return fallback;
    default:
        return (double)node->value.integer;
    }
}

const char *charon_ml_text(const charon_ml_node *node, char *out, size_t size)
{
    if (node == NULL || node->field == NULL ||
        (node->field->kind != CHARON_ML_KIND_STRING && node->field->kind != CHARON_ML_KIND_BYTES) ||
        node->value.text.length + 1 > size) {
        return NULL;
    }
    memcpy(out, node->value.text.bytes, node->value.text.length);
    out[node->value.text.length] = 0;
    return out;
}

const char *charon_ml_type(const charon_ml_node *node)
{
    if (node == NULL || node->field == NULL) {
        return NULL;
    }
    return node->field->type;
}
