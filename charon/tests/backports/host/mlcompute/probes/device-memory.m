#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

static MLCTensor *tensorOf(NSUInteger elements)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:@[@(elements)]
                                                                         dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static MLCLayer *relu(void)
{
    return [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
}

static void show(const char *label, MLCInferenceGraph *graph, MLCDevice *device)
{
    printf("%-44s before=%lu ", label, (unsigned long)graph.deviceMemorySize);
    BOOL compiled = [graph compileWithOptions:0 device:device];
    printf("compiled=%s after=%lu\n", compiled ? "YES" : "NO", (unsigned long)graph.deviceMemorySize);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        MLCDevice *device = [MLCDevice cpuDevice];

        MLCGraph *six = [MLCGraph graph];
        MLCTensor *sixResult = [six nodeWithLayer:relu() source:tensorOf(6)];
        MLCGraph *one = [MLCGraph graph];
        MLCTensor *oneResult = [one nodeWithLayer:relu() source:tensorOf(1)];

        MLCInferenceGraph *g;

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        show("six graph, nothing bound", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(6)}];
        show("six graph, one input of 6", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addOutputs:@{@"y": sixResult}];
        show("six graph, one output of 6", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(1)}];
        show("six graph, one input of 1", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(1)}];
        [g addOutputs:@{@"y": tensorOf(6)}];
        show("input 1, output 6", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(6), @"b": tensorOf(6)}];
        show("two inputs of 6", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(6)}];
        [g addOutputs:@{@"y": tensorOf(6), @"z": tensorOf(6)}];
        show("one input of 6, two outputs of 6", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(1)}];
        [g addOutputs:@{@"y": tensorOf(6), @"z": tensorOf(1)}];
        show("input 1, outputs 6 and 1", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[one]];
        [g addInputs:@{@"a": tensorOf(1)}];
        [g addOutputs:@{@"y": tensorOf(1)}];
        show("one graph, input 1 and output 1", g, device);

        g = [MLCInferenceGraph graphWithGraphObjects:@[one]];
        show("one graph, nothing bound", g, device);
        g = [MLCInferenceGraph graphWithGraphObjects:@[one]];
        [g addInputs:@{@"a": tensorOf(6)}];
        show("one graph, one input of 6", g, device);
        g = [MLCInferenceGraph graphWithGraphObjects:@[one]];
        [g addInputs:@{@"a": tensorOf(6)}];
        [g addOutputs:@{@"y": tensorOf(1)}];
        show("one graph, input 6 and output 1", g, device);
        g = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [g addInputs:@{@"a": tensorOf(6)}];
        [g addOutputs:@{@"y": tensorOf(1)}];
        show("six graph, input 6 and output 1", g, device);

        MLCInferenceGraph *first = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [first addInputs:@{@"a": tensorOf(1)}];
        [first compileWithOptions:0 device:device];
        MLCInferenceGraph *second = [MLCInferenceGraph graphWithGraphObjects:@[six]];
        [second addInputs:@{@"a": tensorOf(6)}];
        [second compileWithOptions:0 device:device];
        printf("%-44s first=%lu second=%lu\n", "two graphs linked, input 1 and input 6",
               (unsigned long)first.deviceMemorySize, (unsigned long)second.deviceMemorySize);
        printf("%-44s linked=%s first=%lu\n", "linkWithGraphs:", [second linkWithGraphs:@[first]] ? "YES" : "NO",
               (unsigned long)second.deviceMemorySize);
    }
    return 0;
}
