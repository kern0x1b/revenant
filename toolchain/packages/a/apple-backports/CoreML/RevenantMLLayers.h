#ifndef REVENANT_ML_LAYERS_H
#define REVENANT_ML_LAYERS_H

#include "RevenantMLProto.h"
#include "RevenantMLTensor.h"

typedef struct {
    revenant_ml_tensor *tensors;
    char **names;
    size_t count;
    size_t room;
} revenant_ml_bindings;

void revenant_ml_bindings_init(revenant_ml_bindings *bindings, size_t room);
void revenant_ml_bindings_release(revenant_ml_bindings *bindings);
revenant_ml_tensor *revenant_ml_bindings_find(revenant_ml_bindings *bindings, const char *name);
int revenant_ml_bindings_put(revenant_ml_bindings *bindings, const char *name, revenant_ml_tensor tensor);

int revenant_ml_run_layer(const revenant_ml_node *layer, revenant_ml_bindings *bindings,
                        char *error, size_t error_size);

#endif
