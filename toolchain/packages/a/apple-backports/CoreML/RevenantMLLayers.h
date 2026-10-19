#ifndef CHARON_ML_LAYERS_H
#define CHARON_ML_LAYERS_H

#include "CharonMLProto.h"
#include "CharonMLTensor.h"

typedef struct {
    charon_ml_tensor *tensors;
    char **names;
    size_t count;
    size_t room;
} charon_ml_bindings;

void charon_ml_bindings_init(charon_ml_bindings *bindings, size_t room);
void charon_ml_bindings_release(charon_ml_bindings *bindings);
charon_ml_tensor *charon_ml_bindings_find(charon_ml_bindings *bindings, const char *name);
int charon_ml_bindings_put(charon_ml_bindings *bindings, const char *name, charon_ml_tensor tensor);

int charon_ml_run_layer(const charon_ml_node *layer, charon_ml_bindings *bindings,
                        char *error, size_t error_size);

#endif
