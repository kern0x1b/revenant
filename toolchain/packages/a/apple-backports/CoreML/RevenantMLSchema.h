#ifndef CHARON_ML_SCHEMA_H
#define CHARON_ML_SCHEMA_H

enum {
    CHARON_ML_FIELD_NONE = 0,
    CHARON_ML_KIND_DOUBLE,
    CHARON_ML_KIND_FLOAT,
    CHARON_ML_KIND_INT64,
    CHARON_ML_KIND_UINT64,
    CHARON_ML_KIND_INT32,
    CHARON_ML_KIND_FIXED64,
    CHARON_ML_KIND_FIXED32,
    CHARON_ML_KIND_BOOL,
    CHARON_ML_KIND_STRING,
    CHARON_ML_KIND_BYTES,
    CHARON_ML_KIND_MESSAGE,
    CHARON_ML_KIND_UINT32,
    CHARON_ML_KIND_ENUM,
    CHARON_ML_KIND_SFIXED32,
    CHARON_ML_KIND_SFIXED64,
    CHARON_ML_KIND_SINT32,
    CHARON_ML_KIND_SINT64
};

enum { CHARON_ML_WIRE_VARINT = 0, CHARON_ML_WIRE_64 = 1, CHARON_ML_WIRE_STRING = 2, CHARON_ML_WIRE_32 = 5 };

#define CHARON_ML_REPEATED 0x1u
#define CHARON_ML_ONEOF(index) (0x2u * (unsigned)(index) + 2u)

typedef struct {
    const char *name;
    int number;
    int wire;
    int kind;
    int element;
    const char *type;
    unsigned flags;
} charon_ml_field;

typedef struct {
    const char *name;
    int first;
    int count;
} charon_ml_message;

extern const charon_ml_field charon_ml_fields[];
extern const charon_ml_message charon_ml_messages[];
extern const unsigned charon_ml_message_count;
extern const unsigned charon_ml_field_count;

const charon_ml_message *charon_ml_message_named(const char *name);

const charon_ml_field *charon_ml_field_named(const charon_ml_message *message, int number);

const charon_ml_field *charon_ml_field_named_str(const charon_ml_message *message, const char *name);

#endif
