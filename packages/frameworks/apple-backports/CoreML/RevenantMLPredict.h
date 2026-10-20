#ifndef REVENANT_ML_PREDICT_H
#define REVENANT_ML_PREDICT_H

#include "RevenantMLModel.h"

int revenant_ml_predict(const revenant_ml_model *model, revenant_ml_features *inputs,
                      revenant_ml_features *outputs, char *error, size_t error_size);

#endif
