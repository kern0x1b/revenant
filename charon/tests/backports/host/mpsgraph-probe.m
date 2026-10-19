// mpsgraph-probe.m — is the host's MPSGraph usable as an oracle at all?
//
// It builds the smallest graph there is: two 2x2 float placeholders and one addition, compiles it with
// the one call the header documents as blocking and returning the target's value, and runs it.
//
//   xcrun clang -fobjc-arc -Wno-unguarded-availability-new mpsgraph-probe.m \
//       -framework Foundation -framework Metal -framework MetalPerformanceShadersGraph -o mpsgraph-probe
//   ./mpsgraph-probe
//
// It answers twice: once through -[MPSGraph runWithFeeds:targetTensors:targetOperations:], which takes
// the tensor data directly and needs no compilation, and once through the compiling route, whose feeds
// are MPSGraphShapedType objects - that class is NSCopying, which is the whole of what the first version
// of this probe got wrong: it handed compileWithDevice:feeds: tensor data, the release copied the
// dictionary, and MPSGraphTensorData has no -copyWithZone:, so that crash said nothing about MPSGraph
// at all. The graph work was held up for a round on the strength of it.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
int main(void){ @autoreleasepool {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    P("device %s\n", d ? [[d name] UTF8String] : "(nil)");
    MPSGraphDevice *gd = [MPSGraphDevice deviceWithMTLDevice:d];
    P("graph device %p type %d metalDevice %p\n", gd, (int)gd.type, gd.metalDevice);
    MPSGraph *g = [MPSGraph new];
    MPSGraphTensor *x = [g placeholderWithShape:@[@2, @2] dataType:MPSDataTypeFloat32 name:@"x"];
    MPSGraphTensor *y = [g placeholderWithShape:@[@2, @2] dataType:MPSDataTypeFloat32 name:@"y"];
    P("placeholder %p shape %s dataType %d\n", x, [[x shape] description].UTF8String, (int)x.dataType);
    MPSGraphTensor *sum = [g additionWithPrimaryTensor:x secondaryTensor:y name:@"sum"];
    P("addition %p\n", sum);
    float left[4] = {1,2,3,4}, right[4] = {10,20,30,40};
    id<MTLBuffer> lb = [d newBufferWithBytes:left length:sizeof(left) options:MTLResourceStorageModeShared];
    id<MTLBuffer> rb = [d newBufferWithBytes:right length:sizeof(right) options:MTLResourceStorageModeShared];
    id<MTLBuffer> ob = [d newBufferWithLength:sizeof(left) options:MTLResourceStorageModeShared];
    MPSGraphTensorData *ld = [[MPSGraphTensorData alloc] initWithMTLBuffer:lb shape:@[@2,@2] dataType:MPSDataTypeFloat32];
    MPSGraphTensorData *rd = [[MPSGraphTensorData alloc] initWithMTLBuffer:rb shape:@[@2,@2] dataType:MPSDataTypeFloat32];
    MPSGraphTensorData *od = [[MPSGraphTensorData alloc] initWithMTLBuffer:ob shape:@[@2,@2] dataType:MPSDataTypeFloat32];
    P("tensor data %p %p %p\n", ld, rd, od);
    float values[4] = {0,0,0,0};
    // -[MPSGraph runWithFeeds:targetTensors:targetOperations:] takes the tensor data directly and needs
    // no compilation step, so it is the shortest oracle there is. Its answers come back as
    // MPSGraphTensorData, which the header gives no accessor for the bytes of, so this probe reads the
    // result through a buffer it owns instead - which is the shape the differential will use.
    NSDictionary *results = [g runWithFeeds:@{x: ld, y: rd} targetTensors:@[sum] targetOperations:@[]];
    P("runWithFeeds results %p count %lu\n", results, (unsigned long)results.count);
    P("result class %s\n", NSStringFromClass([results[sum] class]));

    // The compiling route, whose feeds are shaped types and not tensor data: a shaped type is
    // NSCopying, which is the whole of what the first version of this probe got wrong - it handed
    // compileWithDevice:feeds: tensor data, the release copied the dictionary, and MPSGraphTensorData
    // has no -copyWithZone:, so that crash said nothing about MPSGraph.
    MPSGraphShapedType *st = [[MPSGraphShapedType alloc] initWithShape:@[@2, @2] dataType:MPSDataTypeFloat32];
    P("shaped type %p class %s\n", st, NSStringFromClass([MPSGraphShapedType class]));
    MPSGraphExecutable *e = [g compileWithDevice:gd feeds:@{x: st, y: st}
                                targetTensors:@[sum] targetOperations:@[] compilationDescriptor:nil];
    P("executable %p targets %lu\n", e, (unsigned long)e.targetTensors.count);
    id<MTLCommandQueue> q = [d newCommandQueue];
    NSArray *ran = [e runWithMTLCommandQueue:q inputsArray:@[ld, rd] resultsArray:@[od] executionDescriptor:nil];
    P("ran %p count %lu\n", ran, (unsigned long)ran.count);
    memcpy(values, ob.contents, sizeof(values));
    P("sum through the executable = [%g %g %g %g]\n", values[0], values[1], values[2], values[3]);
} return 0; }
