#import "CharonMLCompute.h"

@implementation MLCInferenceGraph (CharonConstants)

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options
                    device:(MLCDevice *)device
          inputTensors:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
      inputTensorsData:(NSDictionary<NSString *, MLCTensorData *> *)inputTensorsData
{
    for (NSString *name in inputTensors) {
        MLCTensor *tensor = inputTensors[name];
        MLCTensorData *data = inputTensorsData[name];
        if (name && tensor && data)
            [tensor bindAndWriteData:data toDevice:device];
    }
    if (inputTensors.count) {
        [self addInputs:inputTensors];
    }
    return [self compileWithOptions:options device:device];
}

@end

@implementation MLCTrainingGraph (CharonConstants)

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options
                    device:(MLCDevice *)device
          inputTensors:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
      inputTensorsData:(NSDictionary<NSString *, MLCTensorData *> *)inputTensorsData
{
    for (NSString *name in inputTensors) {
        MLCTensor *tensor = inputTensors[name];
        MLCTensorData *data = inputTensorsData[name];
        if (name && tensor && data)
            [tensor bindAndWriteData:data toDevice:device];
    }
    if (inputTensors.count) {
        [self addInputs:inputTensors lossLabels:nil lossLabelWeights:nil];
    }
    return [self compileWithOptions:options device:device];
}

@end
