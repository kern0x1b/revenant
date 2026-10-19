/* Running a model: the values in, the values out.
 *
 * A prediction is a set of feature values in and a set out, and what happens between them is
 * the kind of model: a pipeline runs each of its sub-models in turn, a neural network runs its
 * layers in order, a tree ensemble walks its trees, a GLM multiplies by its weights, and the
 * preprocessing models each do their one arithmetic. A classifier then turns its numbers into
 * a label and a set of probabilities, which is what an application reads.
 */
#ifndef CHARON_ML_PREDICT_H
#define CHARON_ML_PREDICT_H

#include "CharonMLModel.h"

/* Runs `model` over `inputs` and answers in `outputs`, which is emptied first. Returns 0 and
 * writes a line into `error` (of `error_size` bytes) when the model cannot be run: a feature
 * that is missing or the wrong shape, a layer of a kind the port does not carry, a model of a
 * kind it does not carry. Nothing partial is left in `outputs` when it fails. */
int charon_ml_predict(const charon_ml_model *model, charon_ml_features *inputs,
                      charon_ml_features *outputs, char *error, size_t error_size);

#endif /* CHARON_ML_PREDICT_H */
