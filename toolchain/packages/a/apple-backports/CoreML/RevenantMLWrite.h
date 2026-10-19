#ifndef CHARON_ML_WRITE_H
#define CHARON_ML_WRITE_H

#include <stddef.h>

#include "CharonMLProto.h"

int charon_ml_write(const charon_ml_node *document, unsigned char **bytes, size_t *length);

#endif
