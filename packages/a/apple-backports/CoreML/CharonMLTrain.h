/* The training of an updatable neural network: the mean squared error loss, its gradient through the layers
 * the port carries for training (a convolution, a flatten and an inner product), and the optimiser the
 * specification names (stochastic gradient descent with a momentum, or Adam).
 *
 * A trainer is made from the document of a model whose network is updatable. It holds its own copies of the
 * weights, so the model the application holds is not changed until charon_ml_trainer_store writes the trained
 * values back into a document, which the writer then encodes.
 *
 * The update is the one the host runs, and it is checked against the host's own weights step by step
 * (tests/backports/host/coreml-update): after each mini-batch the weights are the ones the host's
 * MLUpdateTask reports for that step. The host's reported loss is not the squared error and is not
 * computed here. */
#ifndef CHARON_ML_TRAIN_H
#define CHARON_ML_TRAIN_H

#include <stddef.h>

#include "CharonMLProto.h"

typedef struct charon_ml_trainer charon_ml_trainer;

/* Makes a trainer from a model document (a CoreML.Specification.Model node). Returns NULL, and writes a line
 * naming what it cannot train, when the model has no updatable network, a layer the port does not train, a
 * loss other than the mean squared error, or an optimiser other than the two above. */
charon_ml_trainer *charon_ml_trainer_new(const charon_ml_node *document, char *error, size_t error_size);
void charon_ml_trainer_free(charon_ml_trainer *trainer);

/* One mini-batch: the forward pass of each sample, the gradient of the mean of the squared errors over the
 * samples and the outputs, and one update of every weight by the optimiser. `inputs` holds `samples` images
 * of the input shape, and `targets` holds `samples` vectors of the output size. Returns 0 and writes a line
 * when the samples cannot be run. */
int charon_ml_trainer_step(charon_ml_trainer *trainer, const float *inputs, const float *targets, size_t samples,
                           char *error, size_t error_size);

/* The mini-batch size and the epoch count the specification gives, and the number of values one sample holds. */
size_t charon_ml_trainer_minibatch_size(const charon_ml_trainer *trainer);
long long charon_ml_trainer_epochs(const charon_ml_trainer *trainer);
size_t charon_ml_trainer_input_count(const charon_ml_trainer *trainer);
size_t charon_ml_trainer_output_count(const charon_ml_trainer *trainer);

/* The layers that hold weights, in network order, and their values as they are now. `which` is the layer
 * index among the trainable layers, and `weights` selects the weight tensor or the bias tensor. */
size_t charon_ml_trainer_layer_count(const charon_ml_trainer *trainer);
const char *charon_ml_trainer_layer_name(const charon_ml_trainer *trainer, size_t which);
const char *charon_ml_trainer_layer_kind(const charon_ml_trainer *trainer, size_t which);
const float *charon_ml_trainer_tensor(const charon_ml_trainer *trainer, size_t which, int bias, size_t *count);

/* Writes the trained weights into `document`, which must be the document the trainer was made from, so that
 * the writer encodes the trained values in the place of the old ones. Returns 0 on a mismatch. */
int charon_ml_trainer_store(const charon_ml_trainer *trainer, charon_ml_node *document);

#endif /* CHARON_ML_TRAIN_H */
