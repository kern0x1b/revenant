// MLCGraph, and the arithmetic behind the layers, on ggml.
//
// The engine is ggml (packages/g/ggml, MIT, unmodified): its tensors are the port's, its graph is
// MLCGraph's node list, and each layer's descriptor is mapped onto one of its operators. Nothing here
// computes a convolution, a pooling, a matrix product or a normalization; this file says which operator
// each descriptor is, and for the few that ggml has no operator for it supplies the formula through
// ggml_map_custom1, which is that library's own elementwise operator.
//
// Every formula in here is the one the host's own MLCompute computes, measured by
// tests/backports/host/mlcompute and written down in facts/MLCompute/Engine.md. Where a formula is not
// simply the operator of the same name - the ReLUN, the clamp, the threshold, the two shrinks, the soft
// sign, the log sigmoid, the linear, the hard sigmoid, the soft plus and the GELU, all of which take
// parameters - it is the measured one, not the one the header's comment suggests, and the comments say so
// where they differ.
//
// The file is Objective-C++ because that is how a backport in this package reaches a static library
// (modules/apple/backports.lua, LIBRARIES' archives). The engine itself is C.

#import "CharonMLCompute.h"
#import "CharonMLCGraph.h"

#include <ggml/ggml.h>
#include <ggml/ggml-cpu.h>

#include <cstdlib>
#include <cstring>

#pragma clang diagnostic ignored "-Wnullability-completeness"

// ---------------------------------------------------------------------------------------------
// The engine's own vocabulary, in one place.

// The formula a callback carries, so that one ggml_map_custom1 serves all of the activations that have
// no operator of their own. It is declared before the engine because the engine owns the list of them: a
// callback is handed a bare void *, and the graph is computed before the engine is closed, so the
// formula has to outlive the call that built the node.
//
// A fixed array rather than a container, so that the engine needs of the C++ runtime nothing: the 4.3
// band would otherwise have to carry a stub of libc++ or libstdc++ for a list of four floats.
#define CHARON_MLC_MAX_FORMULAS 512

struct CharonMLCFormula {
    int activationType;
    float a;
    float b;
    float c;
};

// The context a graph is built and run in: ggml's memory, its graph and the tensors the program named.
// How much memory is enough is decided when the graph is built, so the context is grown and the graph
// rebuilt if a graph turns out bigger than the first guess - facts/MLCompute/Graphs.md.
typedef struct {
    struct ggml_context *context;
    struct ggml_cgraph *graph;
    struct CharonMLCFormula *formulas;
    int formulasUsed;
    size_t bytes;
    int nodes;
} CharonMLCEngine;

// A fresh engine with room for `nodes` operations, which is what a graph of a few hundred tensors needs
// on top of its data. Every tensor the graph allocates is counted against it.
static void CharonMLCEngineOpen(CharonMLCEngine *engine, int nodes)
{
    engine->nodes = nodes;
    engine->bytes = (size_t)(16 * 1024 * 1024) + (size_t)nodes * 4096;
    // no_alloc false, so ggml allocates the pool itself: with no_alloc true and no buffer supplied, the
    // tensors a graph builds have no data to point at and the compute cannot read them. The pool is
    // mem_size big, and ggml_graph_compute_with_ctx finds the compute buffer inside it.
    struct ggml_init_params params = {
        /*.mem_size =*/ engine->bytes,
        /*.mem_buffer =*/ NULL,
        /*.no_alloc =*/ false,
    };
    engine->context = ggml_init(params);
    engine->graph = engine->context ? ggml_new_graph_custom(engine->context, (size_t)nodes * 8, false) : NULL;
    engine->formulas = (CharonMLCFormula *)calloc(CHARON_MLC_MAX_FORMULAS, sizeof(CharonMLCFormula));
    engine->formulasUsed = 0;
}

static void CharonMLCEngineClose(CharonMLCEngine *engine)
{
    if (engine->context) {
        ggml_free(engine->context);
    }
    engine->context = NULL;
    engine->graph = NULL;
    free(engine->formulas);
    engine->formulas = NULL;
    engine->formulasUsed = 0;
}

// ---------------------------------------------------------------------------------------------
// The activations, and the formulas of the ones that take parameters.

static float CharonMLCActivate(const CharonMLCFormula *formula, float x)
{
    float a = formula->a, b = formula->b;
    switch ((MLCActivationType)formula->activationType) {
        case MLCActivationTypeLinear:
            return a * x + b;
        case MLCActivationTypeHardSigmoid:
            // clamp(x * a + b, 0, 1), measured: over 1, 2, 3, 4 with a of 0.2 and b of 0.5 the framework
            // answers 0.7, 0.9, 1, 1.
            return fminf(fmaxf(x * a + b, 0.0f), 1.0f);
        case MLCActivationTypeSoftPlus:
            // a * log(1 + e^(b x)), measured: 1.313262, 2.126928, 3.048587, 4.01815 for a and b of 1.
            return a * log1pf(expf(b * x));
        case MLCActivationTypeSoftSign:
            // x / (1 + |x|), measured: 0.5, 0.6666667, 0.75, 0.8.
            return x / (1.0f + fabsf(x));
        case MLCActivationTypeReLUN:
            // min(x >= 0 ? x : a x, b), measured with a of 0 and b of 6 as the identity over 1, 2, 3, 4
            // and with the default a and b of 1 as 1, 1, 1, 1.
            return fminf(x >= 0.0f ? x : a * x, b);
        case MLCActivationTypeLogSigmoid:
            // log(1 / (1 + e^(-x))), measured: -0.3132617, -0.126928, -0.04858733, -0.01815. Written as
            // logf of 1 + expf in float, not as log1pf: the framework's last value rounds to -0.01815 and
            // log1pf's does not, and the float form is what the host answers to.
            return -logf(1.0f + expf(-x));
        case MLCActivationTypeHardShrink:
            // x where x > a or x < -a and 0 otherwise, measured with a of 0.5 as the identity over
            // 1, 2, 3, 4 and with a of 0.3 as the identity too.
            return (x > a || x < -a) ? x : 0.0f;
        case MLCActivationTypeSoftShrink:
            // x - a above a, x + a below -a and 0 between, measured with a of 0.5 as 0.5, 1.5, 2.5, 3.5.
            return x > a ? x - a : (x < -a ? x + a : 0.0f);
        case MLCActivationTypeThreshold:
            // x where x > a and b otherwise, measured with a of 1 and b of 1 as 1, 2, 3, 4 and with a of
            // 0.6 and b of -1 as 1, 2, 3, 4 - the value at the threshold itself is b.
            return x > a ? x : b;
        case MLCActivationTypeClamp:
            // min(max(x, a), b), measured with a and b of 1 as 1, 1, 1, 1 and with -1 and 2 as 1, 2, 2, 2.
            return fminf(fmaxf(x, a), b);
        case MLCActivationTypeGELU:
            // The tanh approximation and not the erf one - measured, and the difference is a third decimal:
            // the erf form gives 0.841345 at 1 and the framework gives 0.841192.
            //
            //   x/2 * (1 + tanh(c * (x + d x^3)))   with c the square root of 2/pi and d = 0.044715
            //
            // The descriptor's a and b do not reach this: the framework answers 0.841192, 1.9546, 2.99636
            // and 3.99993 for 1, 2, 3 and 4 with a descriptor whose parameters are 1 and 1, which are
            // these two constants and not what the caller gave (measured - the differential's own case
            // builds the descriptor with +descriptorWithType: and no parameters, and the formula with
            // a = b = 1 answers 0.982014, 2, 3 and 4 instead). So the two constants are the framework's
            // own, written here, and the descriptor's parameters for this one are read by nothing.
            (void)a;
            (void)b;
            return x * 0.5f * (1.0f + tanhf(0.7978845608f * (x + 0.044715f * x * x * x)));
        case MLCActivationTypeTanhShrink:
            // x - tanh(x), measured with the default a of 1 as 0.2384059, 1.035972, 2.004945, 3.000671
            // and with the layer's own a of 0 as the same, since the layer's a is not read here.
            return x - tanhf(x);
        case MLCActivationTypeCELU:
            return fmaxf(0.0f, x) + fminf(0.0f, a * (expf(x / a) - 1.0f));
        case MLCActivationTypeELU:
            return x >= 0.0f ? x : a * (expf(x) - 1.0f);
        case MLCActivationTypeReLU:
            return x >= 0.0f ? x : a * x;
        case MLCActivationTypeSELU:
            // scale * (max(0, x) + min(0, alpha (e^x - 1))) with the framework's own two constants,
            // measured as 1.050701, 2.101402, 3.152103, 4.202804 - a scale of 1.0507009873554804934.
            return 1.0507009873554804934f * (fmaxf(0.0f, x) + fminf(0.0f, 1.6732632423543772848f * (expf(x) - 1.0f)));
        case MLCActivationTypeHardSwish:
            // 0 below -3, x from 3, and x (x + 3) / 6 between - measured: 0.6666667, 1.6666667, 3, 4.
            // The multiply is by the reciprocal and not a divide, and the differential compares the bits
            // rather than six digits: at 2 the two differ by one ulp, 3fd55555 against the framework's
            // 3fd55556, and the reciprocal is the framework's. Six digits could not see that.
            return x <= -3.0f ? 0.0f : (x >= 3.0f ? x : x * (x + 3.0f) * (1.0f / 6.0f));
        case MLCActivationTypeTanh:
            return a * tanhf(b * x);
        case MLCActivationTypeSigmoid:
            return 1.0f / (1.0f + expf(-x));
        case MLCActivationTypeAbsolute:
            return fabsf(x);
        case MLCActivationTypeNone:
        default:
            return x;
    }
}

// ggml's own callbacks are plain C functions, so one entry point serves every formula and the formula
// travels in the user data rather than in the function pointer.
static void CharonMLCActivationCallback(struct ggml_tensor *out, const struct ggml_tensor *in, int thread, int threads, void *userdata)
{
    const CharonMLCFormula *formula = (const CharonMLCFormula *)userdata;
    const float *from = (const float *)in->data;
    float *to = (float *)out->data;
    (void)thread;
    (void)threads;
    for (int64_t index = 0; index < (int64_t)ggml_nelements(in); index++) {
        to[index] = CharonMLCActivate(formula, from[index]);
    }
}

// The operator an activation descriptor is, given the engine's context and its input. The ones with an
// operator of their own are that operator; the rest are ggml_map_custom1 with the formula above.
//
// The GELU is in the second group and not the first, which the differential found: ggml's GELU is the erf
// form and takes no parameters, and this framework's is the tanh form with two of them - at 1 the erf form
// gives 0.841345 and the host gives 0.841192 (measured). An operator of the same name is not the same
// function whenever the descriptor carries parameters the operator does not read.
static struct ggml_tensor *CharonMLCActivationOn(CharonMLCEngine *engine, struct ggml_tensor *input, MLCActivationDescriptor *descriptor)
{
    struct ggml_context *context = engine->context;
    switch (descriptor.activationType) {
        case MLCActivationTypeReLU:
            return ggml_relu(context, input);
        case MLCActivationTypeSigmoid:
            return ggml_sigmoid(context, input);
        case MLCActivationTypeTanh:
            return ggml_tanh(context, input);
        case MLCActivationTypeAbsolute:
            return ggml_abs(context, input);
        case MLCActivationTypeELU:
            return ggml_elu(context, input);
        case MLCActivationTypeSoftPlus:
            return ggml_softplus(context, input);
        default:
            break;
    }
    // The formula lives in the engine's list, which outlives the node and is freed with it. A graph with
    // more activations than the list holds is refused here rather than quietly writing past it.
    if (!engine->formulas || engine->formulasUsed >= CHARON_MLC_MAX_FORMULAS) {
        return NULL;
    }
    CharonMLCFormula *formula = &engine->formulas[engine->formulasUsed++];
    formula->activationType = (int)descriptor.activationType;
    formula->a = descriptor.a;
    formula->b = descriptor.b;
    formula->c = descriptor.c;
    return ggml_map_custom1(context, input, CharonMLCActivationCallback, 1, formula);
}

// ---------------------------------------------------------------------------------------------
// One node computed, which is what the differential asks for and what a graph of one layer is.

// A tensor of the engine holding the elements of an MLCTensor, and the elements of the result back into
// an MLCTensor. Both are the port's own and are what the rest of MLCompute reads.
static struct ggml_tensor *CharonMLCImport(struct ggml_context *context, MLCTensor *tensor)
{
    if (!tensor || !tensor.descriptor || !tensor.data) {
        return NULL;
    }
    NSArray<NSNumber *> *shape = tensor.descriptor.shape;
    struct ggml_tensor *imported = ggml_new_tensor_4d(context, GGML_TYPE_F32,
                                                      (int64_t)(shape.count > 0 ? shape[0].unsignedIntegerValue : 1),
                                                      (int64_t)(shape.count > 1 ? shape[1].unsignedIntegerValue : 1),
                                                      (int64_t)(shape.count > 2 ? shape[2].unsignedIntegerValue : 1),
                                                      (int64_t)(shape.count > 3 ? shape[3].unsignedIntegerValue : 1));
    if (imported) {
        const float *from = (const float *)tensor.data.bytes;
        float *to = (float *)imported->data;
        for (int64_t index = 0; index < (int64_t)ggml_nelements(imported); index++) {
            to[index] = from[index];
        }
    }
    return imported;
}

BOOL CharonMLCElementwise(MLCLayer *layer, MLCTensor *input, MLCTensor *output)
{
    if (![layer isKindOfClass:[MLCActivationLayer class]] || !input || !output || !output.descriptor) {
        return NO;
    }
    CharonMLCEngine engine;
    memset(&engine, 0, sizeof(engine));
    CharonMLCEngineOpen(&engine, 64);
    BOOL done = NO;
    if (engine.context) {
        struct ggml_tensor *from = CharonMLCImport(engine.context, input);
        struct ggml_tensor *result = from ? CharonMLCActivationOn(&engine, from, ((MLCActivationLayer *)layer).descriptor) : NULL;
        if (result) {
            ggml_build_forward_expand(engine.graph, result);
            if (ggml_graph_compute_with_ctx(engine.context, engine.graph, 1) == GGML_STATUS_SUCCESS) {
                const float *values = (const float *)result->data;
                float *into = (float *)output.data.bytes;
                for (int64_t index = 0; index < (int64_t)ggml_nelements(result); index++) {
                    into[index] = values[index];
                }
                done = YES;
            }
        }
    }
    CharonMLCEngineClose(&engine);
    return done;
}
