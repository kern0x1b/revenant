#include "RevenantMLWrite.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "RevenantMLSchema.h"

#define WRITE_WIRE_VARINT REVENANT_ML_WIRE_VARINT
#define WRITE_WIRE_64 REVENANT_ML_WIRE_64
#define WRITE_WIRE_STRING REVENANT_ML_WIRE_STRING
#define WRITE_WIRE_32 REVENANT_ML_WIRE_32

typedef struct {
    unsigned char *bytes;
    size_t length;
    size_t capacity;
    int failed;
} out_buffer;

static void reserve(out_buffer *out, size_t extra)
{
    if (out->failed || out->length + extra <= out->capacity) {
        return;
    }
    size_t capacity = out->capacity == 0 ? 64 : out->capacity;
    while (out->length + extra > capacity) {
        capacity *= 2;
    }
    unsigned char *grown = (unsigned char *)realloc(out->bytes, capacity);
    if (grown == NULL) {
        out->failed = 1;
        return;
    }
    out->bytes = grown;
    out->capacity = capacity;
}

static void put_bytes(out_buffer *out, const void *bytes, size_t length)
{
    if (length == 0) {
        return;
    }
    reserve(out, length);
    if (!out->failed) {
        memcpy(out->bytes + out->length, bytes, length);
        out->length += length;
    }
}

static void put_varint(out_buffer *out, uint64_t value)
{
    unsigned char group;
    do {
        group = (unsigned char)(value & 0x7f);
        value >>= 7;
        if (value != 0) {
            group |= 0x80;
        }
        put_bytes(out, &group, 1);
    } while (value != 0);
}

static void put_fixed(out_buffer *out, uint64_t value, size_t width)
{
    unsigned char bytes[8];
    size_t index;
    for (index = 0; index < width; index++) {
        bytes[index] = (unsigned char)(value >> (8 * index));
    }
    put_bytes(out, bytes, width);
}

static void put_tag(out_buffer *out, int number, int wire)
{
    put_varint(out, ((uint64_t)number << 3) | (uint64_t)wire);
}

static uint64_t zigzag(int64_t value)
{
    return ((uint64_t)value << 1) ^ (uint64_t)(value >> 63);
}

static void put_scalar(out_buffer *out, const revenant_ml_node *node, int kind)
{
    uint64_t bits;
    double number;
    float single;
    uint32_t single_bits;

    switch (kind) {
    case REVENANT_ML_KIND_DOUBLE:
        number = node->value.number;
        memcpy(&bits, &number, sizeof bits);
        put_fixed(out, bits, 8);
        break;
    case REVENANT_ML_KIND_FLOAT:
        single = (float)node->value.number;
        memcpy(&single_bits, &single, sizeof single_bits);
        put_fixed(out, single_bits, 4);
        break;
    case REVENANT_ML_KIND_FIXED64:
    case REVENANT_ML_KIND_SFIXED64:
        put_fixed(out, (uint64_t)node->value.integer, 8);
        break;
    case REVENANT_ML_KIND_FIXED32:
    case REVENANT_ML_KIND_SFIXED32:
        put_fixed(out, (uint32_t)node->value.integer, 4);
        break;
    case REVENANT_ML_KIND_INT32:
    case REVENANT_ML_KIND_ENUM:
    case REVENANT_ML_KIND_INT64:
        put_varint(out, (uint64_t)node->value.integer);
        break;
    case REVENANT_ML_KIND_UINT32:
    case REVENANT_ML_KIND_UINT64:
        put_varint(out, node->value.unsigned_integer);
        break;
    case REVENANT_ML_KIND_BOOL:
        put_varint(out, node->value.unsigned_integer ? 1 : 0);
        break;
    case REVENANT_ML_KIND_SINT32:
    case REVENANT_ML_KIND_SINT64:
        put_varint(out, zigzag(node->value.integer));
        break;
    default:
        out->failed = 1;
        break;
    }
}

static void put_entries(out_buffer *out, const revenant_ml_node *message);

static void put_entry(out_buffer *out, const revenant_ml_node *entry)
{
    const revenant_ml_field *field = entry->field;

    if (field == NULL) {
        return;
    }
    if (field->kind == REVENANT_ML_KIND_MESSAGE) {
        out_buffer sub = {NULL, 0, 0, 0};
        put_entries(&sub, entry);
        put_tag(out, field->number, WRITE_WIRE_STRING);
        put_varint(out, (uint64_t)sub.length);
        put_bytes(out, sub.bytes, sub.length);
        out->failed = out->failed || sub.failed;
        free(sub.bytes);
    } else if (field->kind == REVENANT_ML_KIND_STRING || field->kind == REVENANT_ML_KIND_BYTES) {
        put_tag(out, field->number, WRITE_WIRE_STRING);
        put_varint(out, (uint64_t)entry->value.text.length);
        put_bytes(out, entry->value.text.bytes, entry->value.text.length);
    } else {
        put_tag(out, field->number, field->wire);
        put_scalar(out, entry, field->kind);
    }
}

static void put_entries(out_buffer *out, const revenant_ml_node *message)
{
    size_t index = 0;
    while (index < message->value.list.count && !out->failed) {
        const revenant_ml_node *entry = &message->value.list.nodes[index];
        const revenant_ml_field *field = entry->field;

        if (field != NULL && field->element != REVENANT_ML_FIELD_NONE) {
            out_buffer run = {NULL, 0, 0, 0};
            while (index < message->value.list.count && message->value.list.nodes[index].field == field) {
                put_scalar(&run, &message->value.list.nodes[index], field->kind);
                index++;
            }
            put_tag(out, field->number, WRITE_WIRE_STRING);
            put_varint(out, (uint64_t)run.length);
            put_bytes(out, run.bytes, run.length);
            out->failed = out->failed || run.failed;
            free(run.bytes);
            continue;
        }
        put_entry(out, entry);
        index++;
    }
}

int revenant_ml_write(const revenant_ml_node *document, unsigned char **bytes, size_t *length)
{
    out_buffer out = {NULL, 0, 0, 0};

    if (document == NULL || document->field != NULL) {
        return 0;
    }
    put_entries(&out, document);
    if (out.failed) {
        free(out.bytes);
        return 0;
    }
    if (out.bytes == NULL) {
        out.bytes = (unsigned char *)malloc(1);
        if (out.bytes == NULL) {
            return 0;
        }
    }
    *bytes = out.bytes;
    *length = out.length;
    return 1;
}
