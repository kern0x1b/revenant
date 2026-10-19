#import <Foundation/Foundation.h>
// What the host's own MLCompute answers for the layer factories whose parameters have to be of a
// particular shape: the three normalizations, the long short-term memory and the multihead attention.
// Together with engine.m, which asks the framework what it computes, this is the whole measurement the
// layers family is written against (facts/MLCompute/Engine.md and facts/MLCompute/Layers.md).
#import <MLCompute/MLCompute.h>
static NSString *nums(NSArray *a){ if(!a) return @"(nil)"; NSMutableString *t=[NSMutableString string]; for(NSNumber *n in a){ if(t.length) [t appendString:@","]; [t appendString:n.stringValue];} return t; }
static void row(NSString *k, id v){ printf("%s\t%s\n", k.UTF8String, v?[[v description] UTF8String]:"(nil)"); }
static MLCTensor *perChannel(NSUInteger channels, float value) {
  return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor convolutionBiasesDescriptorWithFeatureChannelCount:channels dataType:MLCDataTypeFloat32] fillWithData:@(value)];
}
static NSString *num(NSUInteger value)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)value];
}

static NSString *flt(double value)
{
    return [NSString stringWithFormat:@"%g", value];
}

static NSString *enm(long value)
{
    return [NSString stringWithFormat:@"%ld", value];
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
  MLCTensor *mean = perChannel(4, 0), *variance = perChannel(4, 1), *beta = perChannel(4, 2), *gamma = perChannel(4, 3);
        row(@"shape of one", nums(mean.descriptor.shape));
  MLCBatchNormalizationLayer *batch = [MLCBatchNormalizationLayer layerWithFeatureChannelCount:4 mean:mean variance:variance beta:beta gamma:gamma varianceEpsilon:1e-5];
        row(@"batch channels", num(batch.featureChannelCount));
        row(@"batch mean", batch.mean==mean?@"kept":@"no");
        row(@"batch variance", batch.variance==variance?@"kept":@"no");
        row(@"batch beta", batch.beta==beta?@"kept":@"no");
        row(@"batch gamma", batch.gamma==gamma?@"kept":@"no");
        row(@"batch betaParameter", batch.betaParameter?@"kept":@"no");
        row(@"batch gammaParameter", batch.gammaParameter?@"kept":@"no");
        row(@"batch epsilon", flt(batch.varianceEpsilon));
        row(@"batch momentum", flt(batch.momentum));
        row(@"batch label", batch.label);
  MLCBatchNormalizationLayer *bare = [MLCBatchNormalizationLayer layerWithFeatureChannelCount:4 mean:mean variance:variance beta:nil gamma:nil varianceEpsilon:2e-5 momentum:0.8];
        row(@"bare beta", bare.beta?@"kept":@"no");
        row(@"bare gamma", bare.gamma?@"kept":@"no");
        row(@"bare momentum", flt(bare.momentum));
        row(@"bare epsilon", flt(bare.varianceEpsilon));
  MLCInstanceNormalizationLayer *instance = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:4 mean:mean variance:variance beta:beta gamma:gamma varianceEpsilon:1e-5 momentum:0.9];
        row(@"instance channels", num(instance.featureChannelCount));
        row(@"instance mean", instance.mean==mean?@"kept":@"no");
        row(@"instance variance", instance.variance==variance?@"kept":@"no");
        row(@"instance momentum", flt(instance.momentum));
        row(@"instance label", instance.label);
  MLCInstanceNormalizationLayer *three = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:4 beta:beta gamma:gamma varianceEpsilon:1e-5];
        row(@"instance three beta", three.beta==beta?@"kept":@"no");
        row(@"instance three gamma", three.gamma==gamma?@"kept":@"no");
        row(@"instance three mean", three.mean?@"kept":@"no");
        row(@"instance three momentum", flt(three.momentum));
  MLCInstanceNormalizationLayer *five = [MLCInstanceNormalizationLayer layerWithFeatureChannelCount:4 beta:beta gamma:gamma varianceEpsilon:1e-5];
        row(@"instance five label", five.label);
  MLCGroupNormalizationLayer *group = [MLCGroupNormalizationLayer layerWithFeatureChannelCount:4 groupCount:2 beta:beta gamma:gamma varianceEpsilon:1e-5];
        row(@"group channels", num(group.featureChannelCount));
        row(@"group groups", num(group.groupCount));
        row(@"group beta", group.beta==beta?@"kept":@"no");
        row(@"group gamma", group.gamma==gamma?@"kept":@"no");
        row(@"group epsilon", flt(group.varianceEpsilon));
        row(@"group label", group.label);
  MLCLayerNormalizationLayer *ln = [MLCLayerNormalizationLayer layerWithNormalizedShape:@[@4] beta:beta gamma:gamma varianceEpsilon:1e-5];
        row(@"layer norm shape", nums(ln.normalizedShape));
        row(@"layer norm beta", ln.beta==beta?@"kept":@"no");
        row(@"layer norm epsilon", flt(ln.varianceEpsilon));
        row(@"layer norm label", ln.label);
  MLCTensor *lstmW = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@5, @4] dataType:MLCDataTypeFloat32] fillWithData:@(1)];
  MLCTensor *lstmU = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@5, @5] dataType:MLCDataTypeFloat32] fillWithData:@(1)];
  MLCTensor *lstmB = [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@5] dataType:MLCDataTypeFloat32] fillWithData:@(1)];
  MLCLSTMLayer *lstm = [MLCLSTMLayer layerWithDescriptor:[MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:1 usesBiases:YES isBidirectional:NO dropout:0]
                          inputWeights:@[lstmW,lstmW,lstmW,lstmW] hiddenWeights:@[lstmU,lstmU,lstmU,lstmU] biases:@[lstmB,lstmB,lstmB,lstmB]];
        row(@"lstm label", lstm.label);
        row(@"lstm inputWeights", num(lstm.inputWeights.count));
        row(@"lstm biases", num(lstm.biases.count));
        row(@"lstm peephole", lstm.peepholeWeights?@"kept":@"no");
        row(@"lstm gateActivations", lstm.gateActivations?@"kept":@"no");
        row(@"lstm outputResultActivation", lstm.outputResultActivation?@"kept":@"no");
        row(@"lstm inputWeightsParameters", num(lstm.inputWeightsParameters.count));
        row(@"lstm hiddenWeightsParameters", num(lstm.hiddenWeightsParameters.count));
        row(@"lstm biasesParameters", num(lstm.biasesParameters.count));
        row(@"lstm peepholeWeightsParameters", lstm.peepholeWeightsParameters?@"kept":@"no");
  MLCLSTMLayer *gated = [MLCLSTMLayer layerWithDescriptor:[MLCLSTMDescriptor descriptorWithInputSize:4 hiddenSize:5 layerCount:1 usesBiases:YES isBidirectional:NO dropout:0]
                             inputWeights:@[lstmW,lstmW,lstmW,lstmW] hiddenWeights:@[lstmU,lstmU,lstmU,lstmU] peepholeWeights:@[lstmB,lstmB,lstmB,lstmB] biases:@[lstmB,lstmB,lstmB,lstmB]
                            gateActivations:@[[MLCActivationDescriptor descriptorWithType:MLCActivationTypeSigmoid]] outputResultActivation:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeNone]];
        row(@"lstm gated label", gated.label);
        row(@"lstm gated gateActivations", gated.gateActivations?@"kept":@"no");
        row(@"lstm gated outputResultActivation type", gated.outputResultActivation ? enm(gated.outputResultActivation.activationType) : @"(nil)");
  MLCMultiheadAttentionLayer *att = [MLCMultiheadAttentionLayer layerWithDescriptor:[MLCMultiheadAttentionDescriptor descriptorWithModelDimension:4 headCount:2] weights:@[lstmW] biases:@[lstmB] attentionBiases:@[]];
        row(@"attention label", att.label);
        row(@"attention descriptor", att.descriptor?@"kept":@"no");
        row(@"attention weights", num(att.weights.count));
        row(@"attention weightsParameters", num(att.weightsParameters.count));
  return 0; } }
