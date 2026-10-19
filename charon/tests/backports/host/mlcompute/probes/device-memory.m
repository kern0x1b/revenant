// device-memory.m - what this host's own MLCompute answers for -[MLCInferenceGraph deviceMemorySize], over
// graphs built so that the three hypotheses - the input's bytes, the output's bytes, a sum over both - are
// three different numbers.
//
// The questions, and which hypothesis each one answers:
//
//   one input, no output        the input's bytes, and the sum, and the output's = 0
//   one output, no input        the output's bytes, and the sum, and the input's = 0
//   input 1 element, output 6   the input's is 4, the output's is 24, the sum is 28
//   two outputs of 6            one output is 24, the sum over both with an input is 52
//   neither                     zero under every hypothesis but the constant one
//   nothing compiled            zero
//
// Every operand is a tensor this file makes, never one a node made: a graph's own result asked for as an
// output raised inside the host on the previous sweep (-[__PlaceholderDictionary
// initWithObjects:forKeys:count:]), and a probe that raises stops.
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

        // A graph with one node over a 6-element tensor, so its result is a 6-element tensor. Every input
        // and output below is a tensor this file makes.
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

        // The pair that separates "before a compile is the largest tensor BOUND" from "before a compile is
        // the graph's own node result": a graph whose node is one element, bound to a six-element input, and
        // the same graph bound to nothing.
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

        // Two graphs linked: the memory of the pair is the question, and a link of a graph with itself is
        // what the previous sweep measured as YES.
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