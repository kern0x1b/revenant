#include "RevenantMLSchema.h"
#include <string.h>

#include "RevenantMLSchema.inc"

const revenant_ml_message *revenant_ml_message_named(const char *name)
{
    unsigned low = 0, high = revenant_ml_message_count;
    while (low < high) {
        unsigned middle = (low + high) / 2;
        int order = strcmp(revenant_ml_messages[middle].name, name);
        if (order == 0) {
            return &revenant_ml_messages[middle];
        }
        if (order < 0) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return NULL;
}

const revenant_ml_field *revenant_ml_field_named(const revenant_ml_message *message, int number)
{
    int index;
    for (index = 0; index < message->count; index++) {
        const revenant_ml_field *field = &revenant_ml_fields[message->first + index];
        if (field->number == number) {
            return field;
        }
    }
    return NULL;
}

const revenant_ml_field *revenant_ml_field_named_str(const revenant_ml_message *message, const char *name)
{
    int index;
    for (index = 0; index < message->count; index++) {
        const revenant_ml_field *field = &revenant_ml_fields[message->first + index];
        if (strcmp(field->name, name) == 0) {
            return field;
        }
    }
    return NULL;
}
