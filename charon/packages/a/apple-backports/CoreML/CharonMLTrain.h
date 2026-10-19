#ifndef CHARON_ML_TRAIN_H
#define CHARON_ML_TRAIN_H

#include <stddef.h>

#include "CharonMLProto.h"

typedef struct charon_ml_trainer charon_ml_trainer;

charon_ml_trainer *charon_ml_trainer_new(const charon_ml_node *document, char *error, size_t error_size);
void charon_ml_trainer_free(charon_ml_trainer *trainer);

int charon_ml_trainer_step(charon_ml_trainer *trainer, const float *inputs, const float *targets, size_t samples,
                           char *error, size_t error_size);

size_t charon_ml_trainer_minibatch_size(const charon_ml_trainer *trainer);
long long charon_ml_trainer_epochs(const charon_ml_trainer *trainer);
size_t charon_ml_trainer_input_count(const charon_ml_trainer *trainer);
size_t charon_ml_trainer_output_count(const charon_ml_trainer *trainer);

size_t charon_ml_trainer_layer_count(const charon_ml_trainer *trainer);
const char *charon_ml_trainer_layer_name(const charon_ml_trainer *trainer, size_t which);
const char *charon_ml_trainer_layer_kind(const charon_ml_trainer *trainer, size_t which);
const float *charon_ml_trainer_tensor(const charon_ml_trainer *trainer, size_t which, int bias, size_t *count);

int charon_ml_trainer_store(const charon_ml_trainer *trainer, charon_ml_node *document);

#endif
