/* The schema table of CharonMLSchema.h, and the lookup over it. */
#include "CharonMLSchema.h"
#include <string.h>

#include "CharonMLSchema.inc"

/* The messages are sorted by name, so a lookup is a binary search. */
const charon_ml_message *charon_ml_message_named(const char *name)
{
    unsigned low = 0, high = charon_ml_message_count;
    while (low < high) {
        unsigned middle = (low + high) / 2;
        int order = strcmp(charon_ml_messages[middle].name, name);
        if (order == 0) {
            return &charon_ml_messages[middle];
        }
        if (order < 0) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return NULL;
}

const charon_ml_field *charon_ml_field_named(const charon_ml_message *message, int number)
{
    int index;
    for (index = 0; index < message->count; index++) {
        const charon_ml_field *field = &charon_ml_fields[message->first + index];
        if (field->number == number) {
            return field;
        }
    }
    return NULL;
}

const charon_ml_field *charon_ml_field_named_str(const charon_ml_message *message, const char *name)
{
    int index;
    for (index = 0; index < message->count; index++) {
        const charon_ml_field *field = &charon_ml_fields[message->first + index];
        if (strcmp(field->name, name) == 0) {
            return field;
        }
    }
    return NULL;
}
