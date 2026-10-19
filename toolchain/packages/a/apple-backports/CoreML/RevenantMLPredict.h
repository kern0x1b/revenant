#ifndef CHARON_ML_PREDICT_H
#define CHARON_ML_PREDICT_H

#include "CharonMLModel.h"

int charon_ml_predict(const charon_ml_model *model, charon_ml_features *inputs,
                      charon_ml_features *outputs, char *error, size_t error_size);

#endif
