// The 14.5 form of the compile, on both graph classes: -compileWithOptions:device:inputTensors:inputTensorsData:,
// which takes the tensors the graph may treat as constants.
//
// Its own object, because an object carries the API of one release: the two forms arrived in iOS 14.5 and
// everything else in these two classes arrived in 14.0, so the same file would define API from two releases
// and tools/release-split.lua would refuse it. It is a category on each class, which is what
// MLCompute/MLCAdamAMSGrad15.m does for the one factory the SDK annotates "ios(15)" - a category method is
// added by the library's own attach.c only where the class does not answer the selector, and neither class
// answers this one.
//
// The member itself is the 14.0 compile with the constants bound first: measured on this host, over a graph
// that has compiled, the form answers YES for nil dictionaries, for two empty dictionaries, for tensors with
// no data, for data with no tensors, and for both - which is the plain compile's own answer in each of those
// bindings. What is NOT asked is the same call on a graph with no layer at all: there it raises an
// NSRangeException inside the host ("index 0 beyond bounds for empty array"), which facts/MLCompute/Graph.md
// records and no case asks, because a probe that raises is a probe that stops.

#import "CharonMLCompute.h"

@implementation MLCInferenceGraph (CharonConstants)

- (BOOL)compileWithOptions:(MLCGraphCompilationOptions)options
                    device:(MLCDevice *)device
          inputTensors:(NSDictionary<NSString *, MLCTensor *> *)inputTensors
      inputTensorsData:(NSDictionary<NSString *, MLCTensorData *> *)inputTensorsData
{
    // The constant tensors become inputs of the graph under the names they are given, so that an execute
    // after this compile finds their data where a program's would be, and their data is written into them
    // where it is given.
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
    // As on the inference graph, and then the training graph's own compile, which answers NO for the reason
    // MLCompute/MLCTrainingGraph14.m gives (measured: NO for this form too, over the binding the cases ask).
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