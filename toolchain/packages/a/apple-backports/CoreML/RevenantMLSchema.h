#ifndef REVENANT_ML_SCHEMA_H
#define REVENANT_ML_SCHEMA_H

enum {
    REVENANT_ML_FIELD_NONE = 0,
    REVENANT_ML_KIND_DOUBLE,
    REVENANT_ML_KIND_FLOAT,
    REVENANT_ML_KIND_INT64,
    REVENANT_ML_KIND_UINT64,
    REVENANT_ML_KIND_INT32,
    REVENANT_ML_KIND_FIXED64,
    REVENANT_ML_KIND_FIXED32,
    REVENANT_ML_KIND_BOOL,
    REVENANT_ML_KIND_STRING,
    REVENANT_ML_KIND_BYTES,
    REVENANT_ML_KIND_MESSAGE,
    REVENANT_ML_KIND_UINT32,
    REVENANT_ML_KIND_ENUM,
    REVENANT_ML_KIND_SFIXED32,
    REVENANT_ML_KIND_SFIXED64,
    REVENANT_ML_KIND_SINT32,
    REVENANT_ML_KIND_SINT64
};

enum { REVENANT_ML_WIRE_VARINT = 0, REVENANT_ML_WIRE_64 = 1, REVENANT_ML_WIRE_STRING = 2, REVENANT_ML_WIRE_32 = 5 };

#define REVENANT_ML_REPEATED 0x1u
#define REVENANT_ML_ONEOF(index) (0x2u * (unsigned)(index) + 2u)

typedef struct {
    const char *name;
    int number;
    int wire;
    int kind;
    int element;
    const char *type;
    unsigned flags;
} revenant_ml_field;

typedef struct {
    const char *name;
    int first;
    int count;
} revenant_ml_message;

extern const revenant_ml_field revenant_ml_fields[];
extern const revenant_ml_message revenant_ml_messages[];
extern const unsigned revenant_ml_message_count;
extern const unsigned revenant_ml_field_count;

const revenant_ml_message *revenant_ml_message_named(const char *name);

const revenant_ml_field *revenant_ml_field_named(const revenant_ml_message *message, int number);

const revenant_ml_field *revenant_ml_field_named_str(const revenant_ml_message *message, const char *name);

#endif
