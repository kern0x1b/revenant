/* The CoreML model specification, as data: what protoc was given, read with CharonMLProto.
 *
 * The table is generated (tools/coreml/gen-schema.lua) from the protobuf specification Apple
 * ships in coremltools, so the field numbers and the types of every message of the .mlmodel
 * container come from the specification itself and not from a transcription of it.
 */
#ifndef CHARON_ML_SCHEMA_H
#define CHARON_ML_SCHEMA_H

/* What a field's value is. The numbers are the generator's, not protobuf's: this is the
 * decoder's own switch, and the wire type a kind is written with is in the table beside it.
 * The names are prefixed FIELD rather than KIND so that this and the model kind of
 * CharonMLModel.h -- both "kinds", both zero meaning none -- cannot collide. */
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

/* The wire types a value is written with. */
enum { CHARON_ML_WIRE_VARINT = 0, CHARON_ML_WIRE_64 = 1, CHARON_ML_WIRE_STRING = 2, CHARON_ML_WIRE_32 = 5 };

#define CHARON_ML_REPEATED 0x1u
/* A field of a oneof carries the index of the oneof it belongs to, + 1, so that 0 stays
 * "of no oneof" and does not read as the first one. The low bit is the repeated mark. */
#define CHARON_ML_ONEOF(index) (0x2u * (unsigned)(index) + 2u)

typedef struct {
    const char *name;
    int number;
    int wire;
    int kind;
    /* A packed repeated field arrives as one run of the element's wire type, and this is the
     * element's kind; a repeated field protobuf does not pack (strings, bytes, submessages)
     * arrives as one entry per element and this is 0, its own kind already being the
     * element's. */
    int element;
    const char *type; /* the message or enum this field names, "" for a number or a string */
    unsigned flags;
} charon_ml_field;

typedef struct {
    const char *name; /* relative to CoreML.Specification, which every type of the format is in */
    int first;
    int count;
} charon_ml_message;

extern const charon_ml_field charon_ml_fields[];
extern const charon_ml_message charon_ml_messages[];
extern const unsigned charon_ml_message_count;
extern const unsigned charon_ml_field_count;

/* The message of this name, or NULL: the reader refuses a container naming one it does not
 * hold, rather than reading a submessage's bytes as if they were its own. */
const charon_ml_message *charon_ml_message_named(const char *name);

/* The field of that message with that number, or NULL. A field the specification does not
 * declare is kept by the reader as an unknown field and never dropped silently. */
const charon_ml_field *charon_ml_field_named(const charon_ml_message *message, int number);

/* The field of that message with that name, or NULL. */
const charon_ml_field *charon_ml_field_named_str(const charon_ml_message *message, const char *name);

#endif /* CHARON_ML_SCHEMA_H */
