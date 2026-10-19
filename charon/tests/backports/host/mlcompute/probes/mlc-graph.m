#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <MLCompute/MLCompute.h>

static MLCDevice *device;

static MLCTensor *tensor(NSArray<NSNumber *> *shape)
{
    return [MLCTensor tensorWithDescriptor:[MLCTensorDescriptor descriptorWithShape:shape dataType:MLCDataTypeFloat32]
                                   fillWithData:@0];
}

static void shape(NSString *name, MLCTensor *t)
{
    if (!t) { printf("%-42s (nil)\n", name.UTF8String); return; }
    NSMutableString *text = [NSMutableString string];
    for (NSNumber *n in t.descriptor.shape) {
        if (text.length) [text appendString:@","];
        [text appendFormat:@"%@", n];
    }
    printf("%-42s [%s] type=%ld\n", name.UTF8String, text.UTF8String, (long)t.descriptor.dataType);
}

static void shapes(NSString *name, NSArray<MLCTensor *> *list)
{
    NSMutableString *text = [NSMutableString string];
    for (MLCTensor *t in list) {
        [text appendString:@"["];
        for (NSNumber *n in t.descriptor.shape) {
            if (text.length && ![text hasSuffix:@"["]) [text appendString:@","];
            [text appendFormat:@"%@", n];
        }
        [text appendString:@"]"];
    }
    printf("%-42s %lu %s\n", name.UTF8String, (unsigned long)list.count, text.UTF8String);
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        device = [MLCDevice cpuDevice];
        MLCGraph *graph = [MLCGraph graph];
        printf("%-42s %s\n", "graph device", graph.device ? class_getName([graph.device class]) : "(nil)");
        printf("%-42s %lu\n", "graph layers", (unsigned long)graph.layers.count);
        printf("%-42s %ld characters\n", "graph dot", (long)graph.summarizedDOTDescription.length);
        printf("---8<--- dot\n%s\n---8<---\n", graph.summarizedDOTDescription.UTF8String);

        MLCTensor *a = tensor(@[@2, @3]);
        MLCTensor *b = tensor(@[@2, @3]);
        MLCTensor *c = tensor(@[@2, @3]);

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
        printf("%-42s %lu\n", "graph layers after five nodes", (unsigned long)graph.layers.count);

        for (NSUInteger index = 0; index < graph.layers.count; index++) {
            MLCLayer *layer = graph.layers[index];
            shapes(@"source tensors", [graph sourceTensorsForLayer:layer]);
            shapes(@"result tensors", [graph resultTensorsForLayer:layer]);
        }

        MLCTensor *concat = [graph concatenateWithSources:@[a, b] dimension:1];
        shape(@"concat dimension 1", concat);
        MLCTensor *concat0 = [graph concatenateWithSources:@[a, b] dimension:0];
        shape(@"concat dimension 0", concat0);
        shape(@"reshape 6", [graph reshapeWithShape:@[@6] source:a]);
        shape(@"reshape 3x2", [graph reshapeWithShape:@[@3, @2] source:a]);
        shape(@"reshape wrong count", [graph reshapeWithShape:@[@7] source:a]);
        shape(@"transpose 0 1", [graph transposeWithDimensions:@[@0, @1] source:a]);
        shape(@"transpose 1 0", [graph transposeWithDimensions:@[@1, @0] source:a]);
        shape(@"transpose of one dimension", [graph transposeWithDimensions:@[@0] source:a]);
        shapes(@"split count 2 dimension 1", [graph splitWithSource:a splitCount:2 dimension:1]);
        shapes(@"split count 3 dimension 0", [graph splitWithSource:a splitCount:3 dimension:0]);
        shapes(@"split lengths 1 5", [graph splitWithSource:a splitSectionLengths:@[@1, @5] dimension:1]);

        MLCTensor *t3 = tensor(@[@2, @3, @4]);
        shape(@"concat 3d dimension 1", [graph concatenateWithSources:@[t3, t3] dimension:1]);
        shapes(@"split 3d count 2 dimension 1", [graph splitWithSource:t3 splitCount:2 dimension:1]);
        shape(@"transpose 3d 0 2", [graph transposeWithDimensions:@[@0, @2, @1] source:t3]);

        float fill[6] = {0};
        MLCTensorData *data = [MLCTensorData dataWithBytesNoCopy:fill length:sizeof(fill)];
        printf("%-42s %d\n", "bind unknown name",
               (int)[graph bindAndWriteData:@{@"nope": data} forInputs:@{@"nope": a} toDevice:device synchronous:YES]);
        printf("%-42s %d\n", "bind empty",
               (int)[graph bindAndWriteData:@{} forInputs:@{} toDevice:device synchronous:YES]);
        printf("%-42s %d\n", "bind nil inputs",
               (int)[graph bindAndWriteData:@{@"x": data} forInputs:nil toDevice:device synchronous:YES]);

        MLCInferenceGraph *inference = [MLCInferenceGraph graphWithGraphObjects:@[graph]];
        printf("%-42s %lu\n", "inference deviceMemorySize", (unsigned long)inference.deviceMemorySize);
    }
    return 0;
}
