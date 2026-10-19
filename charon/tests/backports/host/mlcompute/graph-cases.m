// Every case of MLCGraph this port carries: a node's result, the shapes a split, a concatenation, a
// reshape and a transpose produce, which tensors a layer reads and which it writes, the graph's own three
// properties, and what bindAndWriteData:forInputs: answers.
//
// Written once and run twice, beside the host's own MLCompute and beside the port's, and every line is a
// case. The values are the ones .agent-work/runs/probe/mlc-graph.m measured on this host; the run here is
// what holds the port to them, and a case the two sides answer alike is a case that is being checked.

#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

#import "mlcompute-16.h"

void charon_mlcompute_graph_cases(void);

static MLCDevice *device;

static MLCTensor *tensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static void key(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static void shape(NSString *name, MLCTensor *t)
{
    if (!t) { key(name, @"(nil)"); return; }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *n in t.descriptor.shape) {
        if (text.length) [text appendString:@","];
        [text appendFormat:@"%@", n];
    }
    key(name, ([NSString stringWithFormat:@"[%@] type=%ld", text, (long)t.descriptor.dataType]));
}

static void shapes(NSString *name, NSArray<MLCTensor *> *list)
{
    NSMutableString *text = [NSMutableString string];
    for (MLCTensor *t in list) {
        if (text.length) [text appendString:@" "];
        for (NSNumber *n in t.descriptor.shape) {
            if (![text hasSuffix:@"["] && ![text hasSuffix:@" "]) [text appendString:@","];
            [text appendFormat:@"%@", n];
        }
        [text appendString:@"]"];
    }
    key(name, ([NSString stringWithFormat:@"%lu %@", (unsigned long)list.count, text]));
}

void charon_mlcompute_graph_cases(void);

void charon_mlcompute_graph_cases(void)
{
    @autoreleasepool {
        device = [MLCDevice cpuDevice];
        MLCGraph *graph = [MLCGraph graph];
        key(@"graph device", [NSString stringWithUTF8String:graph.device ? class_getName([graph.device class]) : "(nil)"]);
        key(@"graph layers", [NSString stringWithFormat:@"%lu", (unsigned long)graph.layers.count]);
        key(@"graph dot", graph.summarizedDOTDescription);
        key(@"graph dot length", [NSString stringWithFormat:@"%lu", (unsigned long)graph.summarizedDOTDescription.length]);

        MLCTensor *a = tensor(@[@2, @3]);
        MLCTensor *b = tensor(@[@2, @3]);
        MLCTensor *c = tensor(@[@2, @3]);

        // The four ways a node is made. An activation is the layer the port's own engine computes, so it
        // is the one whose result is a real number here.
        MLCLayer *relu = [MLCActivationLayer layerWithDescriptor:[MLCActivationDescriptor descriptorWithType:MLCActivationTypeReLU]];
        MLCTensor *one = [graph nodeWithLayer:relu source:a];
        shape(@"one source", one);
        MLCTensor *two = [graph nodeWithLayer:relu sources:@[a, b]];
        shape(@"two sources", two);
        MLCTensor *three = [graph nodeWithLayer:relu sources:@[a, b, c]];
        shape(@"three sources", three);
        MLCTensor *four = [graph nodeWithLayer:relu sources:@[a, b] disableUpdate:YES];
        shape(@"two sources no update", four);
        MLCTensor *five = [graph nodeWithLayer:relu sources:@[a, b] lossLabels:@[c]];
        shape(@"two sources loss labels", five);
        key(@"graph layers after five nodes", [NSString stringWithFormat:@"%lu", (unsigned long)graph.layers.count]);

        // Which tensors a layer reads and which it writes, over the five nodes above.
        for (NSUInteger index = 0; index < graph.layers.count; index++) {
            MLCLayer *layer = graph.layers[index];
            shapes(@"source tensors", [graph sourceTensorsForLayer:layer]);
            shapes(@"result tensors", [graph resultTensorsForLayer:layer]);
        }

        // The shape operations, over the sources and the results above.
        MLCTensor *concat = [graph concatenateWithSources:@[a, b] dimension:1];
        shape(@"concat dimension 1", concat);
        MLCTensor *concat0 = [graph concatenateWithSources:@[a, b] dimension:0];
        shape(@"concat dimension 0", concat0);
        shape(@"reshape 6", [graph reshapeWithShape:@[@6] source:a]);
        shape(@"reshape 3x2", [graph reshapeWithShape:@[@3, @2] source:a]);
        shape(@"reshape wrong count", [graph reshapeWithShape:@[@7] source:a]);
        // A nil shape is an NSRangeException on this host - measured, and left off for that reason: an
        // empty array reaches -[__NSArray0 objectAtIndex:] inside +[MLCTensorDescriptor
        // descriptorWithShape:stride:dataType:] (MLCTensorDescriptor.mm, via MLCReshapeLayer's
        // -resultTensorFromSources:). Recorded rather than asked, because a probe that raises is a probe that
        // stops.
        shape(@"transpose 0 1", [graph transposeWithDimensions:@[@0, @1] source:a]);
        shape(@"transpose 1 0", [graph transposeWithDimensions:@[@1, @0] source:a]);
        shape(@"transpose of one dimension", [graph transposeWithDimensions:@[@0] source:a]);
        shapes(@"split count 2 dimension 1", [graph splitWithSource:a splitCount:2 dimension:1]);
        shapes(@"split count 3 dimension 0", [graph splitWithSource:a splitCount:3 dimension:0]);
        shapes(@"split lengths 1 5", [graph splitWithSource:a splitSectionLengths:@[@1, @5] dimension:1]);
        // A split count of 0 and one past the extent are not asked here: the first is refused by the
        // framework's own check and the second divides an extent that does not divide, and neither has an
        // answer to compare. facts/MLCompute/Graph.md records what each does.

        // The three-dimension operand, so the rules are not read off a rank-2 case alone.
        MLCTensor *t3 = tensor(@[@2, @3, @4]);
        shape(@"concat 3d dimension 1", [graph concatenateWithSources:@[t3, t3] dimension:1]);
        shapes(@"split 3d count 2 dimension 1", [graph splitWithSource:t3 splitCount:2 dimension:1]);
        shape(@"transpose 3d 0 2", [graph transposeWithDimensions:@[@0, @2, @1] source:t3]);

        // What bindAndWriteData:forInputs: answers with nothing bound, and with a name it does not know.
        // The data of a feed, made the way the framework's own header makes one: six bytes and no shape,
        // because bindAndWriteData: is asked here with a name it does not know and with nothing at all, and
        // the shape of the data is not what those two answers are about.
        float fill[6] = {0};
        MLCTensorData *data = [MLCTensorData dataWithBytesNoCopy:fill length:sizeof(fill)];
        key(@"bind unknown name", [graph bindAndWriteData:@{@"nope": data} forInputs:@{@"nope": a} toDevice:device synchronous:YES] ? @"YES" : @"NO");
        key(@"bind empty", [graph bindAndWriteData:@{} forInputs:@{} toDevice:device synchronous:YES] ? @"YES" : @"NO");
        key(@"bind nil inputs", [graph bindAndWriteData:@{@"x": data} forInputs:nil toDevice:device synchronous:YES] ? @"YES" : @"NO");
        key(@"graph device after bind", [NSString stringWithUTF8String:graph.device ? class_getName([graph.device class]) : "(nil)"]);

        // The device memory size an inference or a training graph answers, and what an empty one answers.
        // An inference graph is asked for on the host's side only: the port does not carry MLCInferenceGraph
        // yet (its fifteen members are the next family), so the case would answer nil there and be a
        // difference where there is nothing to compare. It is left out rather than allowed to fail, and
        // facts/MLCompute/Graph.md says so.
    }
}
