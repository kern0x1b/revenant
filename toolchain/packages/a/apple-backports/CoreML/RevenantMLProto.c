#include "RevenantMLProto.h"

#include <stdlib.h>
#include <string.h>

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

static unsigned oneof_of(const revenant_ml_field *field)
{
    return field == NULL ? 0 : (field->flags & ~REVENANT_ML_REPEATED) >> 1;
}

static int read_value(wire *w, revenant_ml_node *out, const revenant_ml_field *field, const char *type)
{
    uint64_t bits = 0;
    const char *bytes;
    size_t length;

    out->message = NULL;

    if (field->wire == REVENANT_ML_WIRE_VARINT) {
        if (!varint(w, &bits)) {
            return 0;
        }
        switch (field->kind) {
        case REVENANT_ML_KIND_DOUBLE:
            out->value.number = bits_to_double(bits);
            break;
        case REVENANT_ML_KIND_FLOAT:
            out->value.number = (double)bits_to_float(low32(bits));
            break;
        case REVENANT_ML_KIND_UINT64:
        case REVENANT_ML_KIND_FIXED64:
            out->value.unsigned_integer = bits;
            break;
        case REVENANT_ML_KIND_BOOL:
            out->value.unsigned_integer = bits ? 1 : 0;
            break;
        case REVENANT_ML_KIND_SINT32:
            out->value.integer = (int32_t)zigzag(low32(bits));
            break;
        case REVENANT_ML_KIND_SINT64:
            out->value.integer = (int64_t)zigzag(bits);
            break;
        case REVENANT_ML_KIND_UINT32:
        case REVENANT_ML_KIND_FIXED32:
            out->value.unsigned_integer = low32(bits);
            break;
        case REVENANT_ML_KIND_INT32:
        case REVENANT_ML_KIND_SFIXED32:
        case REVENANT_ML_KIND_ENUM:
            out->value.integer = (int32_t)low32(bits);
            break;
        case REVENANT_ML_KIND_INT64:
        case REVENANT_ML_KIND_SFIXED64:
        default:
            out->value.integer = (int64_t)bits;
            break;
        }
        return 1;
    }
    if (field->wire == REVENANT_ML_WIRE_64 || field->wire == REVENANT_ML_WIRE_32) {
        size_t width = field->wire == REVENANT_ML_WIRE_64 ? 8 : 4;
        uint64_t raw;
        if (!take(w, width, &bytes)) {
            return 0;
        }
        memcpy(&raw, bytes, width);
        if (field->kind == REVENANT_ML_KIND_DOUBLE) {
            out->value.number = bits_to_double(raw);
        } else if (field->kind == REVENANT_ML_KIND_FLOAT) {
            out->value.number = (double)bits_to_float(low32(raw));
        } else if (width == 8) {
            out->value.integer = (int64_t)raw;
        } else {
            out->value.integer = (int32_t)low32(raw);
        }
        return 1;
    }
    if (!varint(w, &bits) || !take(w, (size_t)bits, &bytes)) {
        return 0;
    }
    length = (size_t)bits;
    if (field->kind == REVENANT_ML_KIND_STRING || field->kind == REVENANT_ML_KIND_BYTES) {
        out->value.text.bytes = bytes;
        out->value.text.length = length;
        return 1;
    }
    if (field->element != REVENANT_ML_FIELD_NONE) {
        revenant_ml_field element = *field;
        wire run;
        revenant_ml_node *nodes;
        size_t count = 0, capacity = 8, width;

        switch (field->element) {
        case REVENANT_ML_KIND_DOUBLE:
        case REVENANT_ML_KIND_FIXED64:
        case REVENANT_ML_KIND_SFIXED64:
            width = 8;
            break;
        case REVENANT_ML_KIND_FLOAT:
        case REVENANT_ML_KIND_FIXED32:
        case REVENANT_ML_KIND_SFIXED32:
            width = 4;
            break;
        default:
            width = 0;
            break;
        }
        element.element = REVENANT_ML_FIELD_NONE;
        element.flags &= ~(unsigned)REVENANT_ML_REPEATED;
        element.wire = width == 0 ? REVENANT_ML_WIRE_VARINT
                                  : (width == 8 ? REVENANT_ML_WIRE_64 : REVENANT_ML_WIRE_32);
        run.at = bytes;
        run.end = bytes + length;
        run.failed = 0;
        nodes = (revenant_ml_node *)calloc(capacity, sizeof *nodes);
        if (nodes == NULL) {
            return 0;
        }
        while (run.at < run.end) {
            if (count == capacity) {
                revenant_ml_node *grown = (revenant_ml_node *)realloc(nodes, capacity * 2 * sizeof *nodes);
                if (grown == NULL) {
                    free(nodes);
                    return 0;
                }
                memset(grown + capacity, 0, capacity * sizeof *grown);
                nodes = grown;
                capacity *= 2;
            }
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
        revenant_ml_node sub;
        if (revenant_ml_read(&sub, bytes, length, type) == 0) {
            w->failed = 1;
            return 0;
        }
        out->message = sub.message;
        out->value = sub.value;
    }
    return 1;
}

static int read_message(wire *w, revenant_ml_node *out, const revenant_ml_message *message, const char *type)
{
    revenant_ml_node *entries = (revenant_ml_node *)calloc(8, sizeof *entries);
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
        const revenant_ml_field *field;
        revenant_ml_node *entry;

        if (!varint(w, &key)) {
            break;
        }
        number = (int)(key >> 3);
        wire_type = (int)(key & 7);
        field = revenant_ml_field_named(message, number);
        if (field == NULL || field->wire != wire_type) {
            wire step = {w->at, w->end, 0};
            uint64_t skip = 0;
            const char *at;
            switch (wire_type) {
            case REVENANT_ML_WIRE_VARINT:
                varint(&step, &skip);
                break;
            case REVENANT_ML_WIRE_64:
                take(&step, 8, &at);
                break;
            case REVENANT_ML_WIRE_32:
                take(&step, 4, &at);
                break;
            case REVENANT_ML_WIRE_STRING:
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
            revenant_ml_node *grown = (revenant_ml_node *)realloc(entries, capacity * 2 * sizeof *entries);
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
        if ((field->flags & REVENANT_ML_REPEATED) == 0 || field->element == REVENANT_ML_FIELD_NONE) {
            count++;
            continue;
        }
        {
            revenant_ml_node *run = entry->value.list.nodes;
            size_t elements = entry->value.list.count, inner;
            while (count + elements > capacity) {
                revenant_ml_node *grown = (revenant_ml_node *)realloc(entries, capacity * 2 * sizeof *entries);
                if (grown == NULL) {
                    for (inner = 0; inner < elements; inner++) {
                        revenant_ml_free(&run[inner]);
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
            revenant_ml_free(&entries[index]);
        }
        free(entries);
        return 0;
    }
    out->value.list.nodes = entries;
    out->value.list.count = count;
    return 1;
}

static int holds_list(const revenant_ml_node *node)
{
    return node != NULL && (node->field == NULL || node->field->kind == REVENANT_ML_KIND_MESSAGE);
}

int revenant_ml_read(revenant_ml_node *out, const void *bytes, size_t length, const char *type)
{
    static const char package[] = "CoreML.Specification.";
    const revenant_ml_message *message = revenant_ml_message_named(type);
    wire w;

    memset(out, 0, sizeof *out);
    if (message == NULL && strncmp(type, package, sizeof package - 1) == 0) {
        message = revenant_ml_message_named(type + sizeof package - 1);
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

void revenant_ml_free(revenant_ml_node *node)
{
    size_t index;
    if (!holds_list(node) || node->value.list.nodes == NULL) {
        return;
    }
    for (index = 0; index < node->value.list.count; index++) {
        revenant_ml_free(&node->value.list.nodes[index]);
    }
    free(node->value.list.nodes);
    node->value.list.nodes = NULL;
    node->value.list.count = 0;
}

size_t revenant_ml_count(const revenant_ml_node *node)
{
    return holds_list(node) ? node->value.list.count : 0;
}

const revenant_ml_node *revenant_ml_at(const revenant_ml_node *node, size_t index)
{
    if (index >= revenant_ml_count(node)) {
        return NULL;
    }
    return &node->value.list.nodes[index];
}

int revenant_ml_int_at(const revenant_ml_node *node, const char *name, size_t index, int fallback)
{
    return revenant_ml_int(revenant_ml_node_at_field(node, name, index), fallback);
}

double revenant_ml_double_at(const revenant_ml_node *node, const char *name, size_t index, double fallback)
{
    return revenant_ml_double(revenant_ml_node_at_field(node, name, index), fallback);
}

size_t revenant_ml_count_field(const revenant_ml_node *node, const char *name)
{
    size_t index, found = 0;
    for (index = 0; index < revenant_ml_count(node); index++) {
        const revenant_ml_node *entry = &node->value.list.nodes[index];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            found++;
        }
    }
    return found;
}

const revenant_ml_node *revenant_ml_node_at_field(const revenant_ml_node *node, const char *name, size_t index)
{
    size_t at, found = 0;
    for (at = 0; at < revenant_ml_count(node); at++) {
        const revenant_ml_node *entry = &node->value.list.nodes[at];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            if (found == index) {
                return entry;
            }
            found++;
        }
    }
    return NULL;
}

const revenant_ml_node *revenant_ml_get(const revenant_ml_node *node, const char *name)
{
    const revenant_ml_node *found = NULL;
    size_t index;
    for (index = 0; index < revenant_ml_count(node); index++) {
        const revenant_ml_node *entry = &node->value.list.nodes[index];
        if (entry->field != NULL && strcmp(entry->field->name, name) == 0) {
            found = entry;
        }
    }
    return found;
}

const revenant_ml_node *revenant_ml_oneof(const revenant_ml_node *node, const char *name)
{
    const revenant_ml_node *want = revenant_ml_get(node, name);
    unsigned oneof;
    size_t index;

    if (want == NULL) {
        return NULL;
    }
    oneof = oneof_of(want->field);
    if (oneof == 0) {
        return want;
    }
    for (index = 0; index < revenant_ml_count(node); index++) {
        const revenant_ml_node *entry = &node->value.list.nodes[index];
        if (oneof_of(entry->field) == oneof && entry != want) {
            return NULL;
        }
    }
    return want;
}

int revenant_ml_int(const revenant_ml_node *node, int64_t fallback)
{
    if (node == NULL) {
        return (int)fallback;
    }
    switch (node->field != NULL ? node->field->kind : REVENANT_ML_FIELD_NONE) {
    case REVENANT_ML_KIND_DOUBLE:
    case REVENANT_ML_KIND_FLOAT:
        return (int)node->value.number;
    case REVENANT_ML_KIND_UINT64:
    case REVENANT_ML_KIND_FIXED64:
    case REVENANT_ML_KIND_UINT32:
    case REVENANT_ML_KIND_FIXED32:
    case REVENANT_ML_KIND_BOOL:
        return (int)node->value.unsigned_integer;
    case REVENANT_ML_FIELD_NONE:
        return (int)fallback;
    default:
        return (int)node->value.integer;
    }
}

double revenant_ml_double(const revenant_ml_node *node, double fallback)
{
    if (node == NULL) {
        return fallback;
    }
    switch (node->field != NULL ? node->field->kind : REVENANT_ML_FIELD_NONE) {
    case REVENANT_ML_KIND_DOUBLE:
    case REVENANT_ML_KIND_FLOAT:
        return node->value.number;
    case REVENANT_ML_KIND_UINT64:
    case REVENANT_ML_KIND_FIXED64:
    case REVENANT_ML_KIND_UINT32:
    case REVENANT_ML_KIND_FIXED32:
    case REVENANT_ML_KIND_BOOL:
        return (double)node->value.unsigned_integer;
    case REVENANT_ML_FIELD_NONE:
        return fallback;
    default:
        return (double)node->value.integer;
    }
}

const char *revenant_ml_text(const revenant_ml_node *node, char *out, size_t size)
{
    if (node == NULL || node->field == NULL ||
        (node->field->kind != REVENANT_ML_KIND_STRING && node->field->kind != REVENANT_ML_KIND_BYTES) ||
        node->value.text.length + 1 > size) {
        return NULL;
    }
    memcpy(out, node->value.text.bytes, node->value.text.length);
    out[node->value.text.length] = 0;
    return out;
}

const char *revenant_ml_type(const revenant_ml_node *node)
{
    if (node == NULL || node->field == NULL) {
        return NULL;
    }
    return node->field->type;
}
