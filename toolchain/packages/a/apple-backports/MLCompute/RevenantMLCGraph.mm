#import "RevenantMLCompute.h"
#import "RevenantMLCGraph.h"

#include <ggml/ggml.h>
#include <ggml/ggml-cpu.h>

#include <cstdlib>
#include <cstring>

#pragma clang diagnostic ignored "-Wnullability-completeness"

#define REVENANT_MLC_MAX_FORMULAS 512

struct RevenantMLCFormula {
    int activationType;
    float a;
    float b;
    float c;
};

typedef struct {
    struct ggml_context *context;
    struct ggml_cgraph *graph;
    struct RevenantMLCFormula *formulas;
    int formulasUsed;
    size_t bytes;
    int nodes;
} RevenantMLCEngine;

static void RevenantMLCEngineOpen(RevenantMLCEngine *engine, int nodes)
{
    engine->nodes = nodes;
    engine->bytes = (size_t)(16 * 1024 * 1024) + (size_t)nodes * 4096;
    struct ggml_init_params params = {
         engine->bytes,
         NULL,
         false,
    };
    engine->context = ggml_init(params);
    engine->graph = engine->context ? ggml_new_graph_custom(engine->context, (size_t)nodes * 8, false) : NULL;
    engine->formulas = (RevenantMLCFormula *)calloc(REVENANT_MLC_MAX_FORMULAS, sizeof(RevenantMLCFormula));
    engine->formulasUsed = 0;
}

static void RevenantMLCEngineClose(RevenantMLCEngine *engine)
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

static float RevenantMLCActivate(const RevenantMLCFormula *formula, float x)
{
    float a = formula->a, b = formula->b;
    switch ((MLCActivationType)formula->activationType) {
        case MLCActivationTypeLinear:
            return a * x + b;
        case MLCActivationTypeHardSigmoid:
            return fminf(fmaxf(x * a + b, 0.0f), 1.0f);
        case MLCActivationTypeSoftPlus:
            return a * log1pf(expf(b * x));
        case MLCActivationTypeSoftSign:
            return x / (1.0f + fabsf(x));
        case MLCActivationTypeReLUN:
            return fminf(x >= 0.0f ? x : a * x, b);
        case MLCActivationTypeLogSigmoid:
            return -logf(1.0f + expf(-x));
        case MLCActivationTypeHardShrink:
            return (x > a || x < -a) ? x : 0.0f;
        case MLCActivationTypeSoftShrink:
            return x > a ? x - a : (x < -a ? x + a : 0.0f);
        case MLCActivationTypeThreshold:
            return x > a ? x : b;
        case MLCActivationTypeClamp:
            return fminf(fmaxf(x, a), b);
        case MLCActivationTypeGELU:
            (void)a;
            (void)b;
            return x * 0.5f * (1.0f + tanhf(0.7978845608f * (x + 0.044715f * x * x * x)));
        case MLCActivationTypeTanhShrink:
            return x - tanhf(x);
        case MLCActivationTypeCELU:
            return fmaxf(0.0f, x) + fminf(0.0f, a * (expf(x / a) - 1.0f));
        case MLCActivationTypeELU:
            return x >= 0.0f ? x : a * (expf(x) - 1.0f);
        case MLCActivationTypeReLU:
            return x >= 0.0f ? x : a * x;
        case MLCActivationTypeSELU:
            return 1.0507009873554804934f * (fmaxf(0.0f, x) + fminf(0.0f, 1.6732632423543772848f * (expf(x) - 1.0f)));
        case MLCActivationTypeHardSwish:
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

static void RevenantMLCActivationCallback(struct ggml_tensor *out, const struct ggml_tensor *in, int thread, int threads, void *userdata)
{
    const RevenantMLCFormula *formula = (const RevenantMLCFormula *)userdata;
    const float *from = (const float *)in->data;
    float *to = (float *)out->data;
    (void)thread;
    (void)threads;
    for (int64_t index = 0; index < (int64_t)ggml_nelements(in); index++) {
        to[index] = RevenantMLCActivate(formula, from[index]);
    }
}

static struct ggml_tensor *RevenantMLCActivationOn(RevenantMLCEngine *engine, struct ggml_tensor *input, MLCActivationDescriptor *descriptor)
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
    if (!engine->formulas || engine->formulasUsed >= REVENANT_MLC_MAX_FORMULAS) {
        return NULL;
    }
    RevenantMLCFormula *formula = &engine->formulas[engine->formulasUsed++];
    formula->activationType = (int)descriptor.activationType;
    formula->a = descriptor.a;
    formula->b = descriptor.b;
    formula->c = descriptor.c;
    return ggml_map_custom1(context, input, RevenantMLCActivationCallback, 1, formula);
}

static struct ggml_tensor *RevenantMLCImport(struct ggml_context *context, MLCTensor *tensor)
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

BOOL RevenantMLCElementwise(MLCLayer *layer, MLCTensor *input, MLCTensor *output)
{
    if (![layer isKindOfClass:[MLCActivationLayer class]] || !input || !output || !output.descriptor) {
        return NO;
    }
    RevenantMLCEngine engine;
    memset(&engine, 0, sizeof(engine));
    RevenantMLCEngineOpen(&engine, 64);
    BOOL done = NO;
    if (engine.context) {
        struct ggml_tensor *from = RevenantMLCImport(engine.context, input);
        struct ggml_tensor *result = from ? RevenantMLCActivationOn(&engine, from, ((MLCActivationLayer *)layer).descriptor) : NULL;
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
    RevenantMLCEngineClose(&engine);
    return done;
}
