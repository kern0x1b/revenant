// The twenty-one activation types, in the framework's own order, with the names the cases print. Shared
// by the two sides so that one line of one run answers to one line of the other.
#pragma once

static const char *const charon_case_names[] = {
    "none", "relu", "linear", "sigmoid", "hardSigmoid", "tanh", "absolute", "softPlus", "softSign", "elu",
    "reluN", "logSigmoid", "selu", "celu", "hardShrink", "softShrink", "tanhShrink", "threshold", "gelu",
    "hardSwish", "clamp"
};

#define CHARON_CASES 21
