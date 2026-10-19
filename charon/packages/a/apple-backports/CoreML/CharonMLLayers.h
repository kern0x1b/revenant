/* The layers of a Core ML neural network, each one as the specification describes it.
 *
 * Every layer takes the values its input names, computes into the values its output names,
 * and either succeeds or writes a line naming itself and why it could not run. A layer the
 * port does not carry is refused by name rather than skipped: a network that silently loses
 * a layer is a network that answers something other than what the model says.
 */
#ifndef CHARON_ML_LAYERS_H
#define CHARON_ML_LAYERS_H

#include "CharonMLProto.h"
#include "CharonMLTensor.h"

/* The values by name a network's layers read and write. A layer adds its outputs and leaves
 * the rest, so the set grows and shrinks as the network is walked in order. */
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

/* Runs one layer. `layer` is the NeuralNetworkLayer message, whose one named case is the kind
 * of layer it is. Returns 0 and writes a line naming the layer and the reason when it cannot
 * be run, which is what the caller reports. */
int charon_ml_run_layer(const charon_ml_node *layer, charon_ml_bindings *bindings,
                        char *error, size_t error_size);

#endif /* CHARON_ML_LAYERS_H */
