/* The writer of a CoreML model: a document read by charon_ml_read, encoded back to the protocol buffer
 * wire format, which is the .mlmodel container. The reader keeps the document of a model it opened
 * (CharonMLModel.c), so a model written here is the one it was read from.
 *
 * What is written: every field the document holds. The reader steps over a field the specification
 * does not declare and keeps no trace of it, so such a field is not written either. A packed run is
 * written one element at a time, which every protobuf reader accepts. */
#ifndef CHARON_ML_WRITE_H
#define CHARON_ML_WRITE_H

#include <stddef.h>

#include "CharonMLProto.h"

/* Encodes `document`, a message node, to the bytes of its container. On success returns 1 and
 * *bytes is a malloc'd buffer of *length bytes, which the caller frees; on failure returns 0 and
 * leaves *bytes untouched. */
int charon_ml_write(const charon_ml_node *document, unsigned char **bytes, size_t *length);

#endif /* CHARON_ML_WRITE_H */
