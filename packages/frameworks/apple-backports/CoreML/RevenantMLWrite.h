#ifndef REVENANT_ML_WRITE_H
#define REVENANT_ML_WRITE_H

#include <stddef.h>

#include "RevenantMLProto.h"

int revenant_ml_write(const revenant_ml_node *document, unsigned char **bytes, size_t *length);

#endif
