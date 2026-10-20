#ifndef REVENANT_ML_TRAIN_H
#define REVENANT_ML_TRAIN_H

#include <stddef.h>

#include "RevenantMLProto.h"

typedef struct revenant_ml_trainer revenant_ml_trainer;

revenant_ml_trainer *revenant_ml_trainer_new(const revenant_ml_node *document, char *error, size_t error_size);
void revenant_ml_trainer_free(revenant_ml_trainer *trainer);

int revenant_ml_trainer_step(revenant_ml_trainer *trainer, const float *inputs, const float *targets, size_t samples,
                           char *error, size_t error_size);

size_t revenant_ml_trainer_minibatch_size(const revenant_ml_trainer *trainer);
long long revenant_ml_trainer_epochs(const revenant_ml_trainer *trainer);
size_t revenant_ml_trainer_input_count(const revenant_ml_trainer *trainer);
size_t revenant_ml_trainer_output_count(const revenant_ml_trainer *trainer);

size_t revenant_ml_trainer_layer_count(const revenant_ml_trainer *trainer);
const char *revenant_ml_trainer_layer_name(const revenant_ml_trainer *trainer, size_t which);
const char *revenant_ml_trainer_layer_kind(const revenant_ml_trainer *trainer, size_t which);
const float *revenant_ml_trainer_tensor(const revenant_ml_trainer *trainer, size_t which, int bias, size_t *count);

int revenant_ml_trainer_store(const revenant_ml_trainer *trainer, revenant_ml_node *document);

#endif
